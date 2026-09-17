import Foundation

/// Builds a per-day token/cost series from pi's session logs, either for pi's own card (every request
/// pi made, whatever model it drove) or for one underlying provider's card (the slice of pi usage that
/// belongs to that provider's subscription).
///
/// Pi records an authoritative per-message `usage.cost.total` (like OpenCode), so that carried cost is
/// used when present; when pi logs a `$0` cost (subscription usage it doesn't impute), the tokens are
/// priced through the shared engine instead — the same `carried cost, else price` rule the Claude and
/// Codex log scanners use. Pi's usage shape differs from Claude Code's (`usage.input`/`output`,
/// nested `usage.cost.total`), so it has its own parser rather than routing through those scanners.
///
/// An actor holding the versioned incremental parse cache (keyed path + size + mtime) in memory and
/// Application Support, so refreshes and relaunches parse only changed session files. A single shared
/// instance is used by every consuming provider, so pi's logs are parsed once rather than once per card.
actor PiUsageScanner {
    /// How a card prices a pi request that carries no cost of its own. Providers with their own
    /// request rules (Codex's long-context and priority tiers) supply their estimator; the rest use
    /// the shared pricing engine.
    typealias CostEstimator = @Sendable (String, TokenBreakdown) -> Double?

    static let shared = PiUsageScanner()

    private let environment: EnvironmentReading
    private let homeDirectory: @Sendable () -> URL
    private let scanner: IncrementalJSONLScanner<Entry>

    private static let sharedScanner = IncrementalJSONLScanner<Entry>(
        logTag: LogTag.plugin("pi"),
        // Schema 2: entries keep every pi provider (not just the mapped ones) and carry the raw pi
        // provider id, so a schema-1 cache would be missing the rows the pi card needs.
        persistence: JSONLScanCachePersistence(namespace: "pi", schemaVersion: 2)
    )

    static func flushPersistentCacheWrites() async {
        await sharedScanner.flushPendingWrites()
    }

    init(
        environment: EnvironmentReading = ProcessEnvironmentReader(),
        homeDirectory: @escaping @Sendable () -> URL = { FileManager.default.homeDirectoryForCurrentUser },
        incrementalScanner: IncrementalJSONLScanner<Entry>? = nil
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
        self.scanner = incrementalScanner ?? Self.sharedScanner
    }

    /// One parsed assistant-message usage line. Raw timestamp is kept so a cached parse stays valid as
    /// the window slides; `cardID` is resolved at parse time so aggregation is a cheap filter.
    struct Entry: Codable, Sendable, Equatable {
        var id: String?
        var timestamp: Date
        /// The underlying provider's OpenUsage card, or nil when pi drove a provider OpenUsage has no
        /// card for (DeepSeek, an OpenAI-compatible endpoint, …). Every line is kept either way: the pi
        /// card counts them all, and a provider card filters to its own.
        var cardID: String?
        /// pi's own `provider` value, kept so the pi card can report usage per underlying provider.
        var piProvider: String
        var model: String
        /// pi's own `usage.cost.total`, used directly when > 0; nil/0 falls through to engine pricing.
        var carriedCost: Double?
        /// The token buckets, for pricing the fall-through case.
        var tokens: TokenBreakdown
        /// pi's reported `usage.totalTokens`, shown as the row's token count (matches pi's own footer).
        var reportedTotalTokens: Int
    }

    /// Scan the last `daysBack` days of pi logs. Pass a `cardID` to get only the slice belonging to that
    /// provider's card; pass nil (what the pi card does) to get every request pi made. Returns nil when
    /// pi's sessions directory has no log files at all, so a caller with no pi usage folds in nothing.
    func scan(
        cardID: String?, daysBack: Int = 30, now: Date = Date(), pricing: ModelPricing,
        estimateCost: CostEstimator? = nil
    ) async -> LogUsageScan? {
        let directory = PiPaths.sessionsDirectory(environment: environment, homeDirectory: homeDirectory())
        let since = JSONLScanning.sinceDate(daysBack: daysBack, now: now)
        let cacheIdentity = directory.resolvingSymlinksInPath().path
        let files = JSONLScanning.jsonlFiles(under: directory)
        guard !files.isEmpty else {
            _ = await scanner.items(
                from: [], since: since, cacheIdentity: cacheIdentity, parse: Self.parseFile
            )
            return nil
        }

        guard let entries = await scanner.items(
            from: files,
            since: since,
            cacheIdentity: cacheIdentity,
            parse: Self.parseFile
        ), !Task.isCancelled else { return nil }
        return Self.aggregate(
            entries: Self.dedup(entries), cardID: cardID, since: since, pricing: pricing,
            estimateCost: estimateCost
        )
    }

    // MARK: - Parsing

    /// Parse every assistant usage line of one session file, including lines for pi providers that have
    /// no OpenUsage card of their own — those are what the pi card is for. Filtering happens in
    /// `aggregate`, not here.
    static func parseFile(_ data: Data) -> [Entry] {
        let marker = Data(#""usage":{"#.utf8)
        var entries: [Entry] = []
        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard line.range(of: marker) != nil, let entry = parseLine(Data(line)) else { continue }
            entries.append(entry)
        }
        return entries
    }

    static func parseLine(_ data: Data) -> Entry? {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              object["type"] as? String == "message",
              let timestampRaw = object["timestamp"] as? String,
              let timestamp = OpenUsageISO8601.date(from: timestampRaw),
              let message = object["message"] as? [String: Any],
              message["role"] as? String == "assistant",
              let providerID = message["provider"] as? String,
              let usage = message["usage"] as? [String: Any]
        else { return nil }

        let cacheWrite = Int(ProviderParse.number(usage["cacheWrite"]) ?? 0)
        let cacheWrite1h = Int(ProviderParse.number(usage["cacheWrite1h"]) ?? 0)
        let tokens = TokenBreakdown(
            input: Int(ProviderParse.number(usage["input"]) ?? 0),
            cacheWrite5m: max(cacheWrite - cacheWrite1h, 0),
            cacheWrite1h: cacheWrite1h,
            cacheRead: Int(ProviderParse.number(usage["cacheRead"]) ?? 0),
            output: Int(ProviderParse.number(usage["output"]) ?? 0)
        )

        let carriedCost = (usage["cost"] as? [String: Any]).flatMap { ProviderParse.number($0["total"]) }
        return Entry(
            id: object["id"] as? String,
            timestamp: timestamp,
            cardID: PiProviderMapping.cardID(forPiProvider: providerID),
            piProvider: providerID,
            model: (message["model"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            carriedCost: carriedCost,
            tokens: tokens,
            reportedTotalTokens: Int(ProviderParse.number(usage["totalTokens"]) ?? 0)
        )
    }

    // MARK: - Dedup and aggregation

    /// Drop replayed lines that a forked/cloned session can duplicate under the same message id, keeping
    /// the first occurrence. Lines without an id are always kept.
    static func dedup(_ entries: [Entry]) -> [Entry] {
        var seen: Set<String> = []
        var out: [Entry] = []
        out.reserveCapacity(entries.count)
        for entry in entries {
            if let id = entry.id, !seen.insert(id).inserted { continue }
            out.append(entry)
        }
        return out
    }

    /// Bucket entries into local calendar days — the ones matching `cardID`, or all of them when it is
    /// nil (the pi card). Cost is pi's carried total when it recorded one, else the tokens priced
    /// through `pricing`; a model that can't be priced and carries no cost is excluded from the totals
    /// and surfaced as the tile's unknown-model warning, matching the log scanners.
    static func aggregate(
        entries: [Entry], cardID: String?, since: Date, pricing: ModelPricing,
        estimateCost: CostEstimator? = nil
    ) -> LogUsageScan {
        let estimate = estimateCost ?? { pricing.estimatedCostDollars(model: $0, tokens: $1) }
        // Only the pi card mixes providers in one breakdown, so only it needs the provider label; a
        // provider card's rows are that provider's by definition.
        let labelsProvider = cardID == nil
        var accumulator = DailyUsageAccumulator()
        for entry in entries where (cardID == nil || entry.cardID == cardID) && entry.timestamp >= since {
            let day = DailyUsageAccumulator.dayKey(from: entry.timestamp)
            let trimmedModel = entry.model.nilIfEmpty
            // Display name only — pricing always looks up pi's raw model id below.
            let displayModel = trimmedModel.map {
                labelsProvider ? PiProviderMapping.modelLabel(model: $0, piProvider: entry.piProvider) : $0
            }
            let modelName = displayModel ?? ModelUsageEntry.unattributedModelName

            let cost: Double
            if let carried = entry.carriedCost, carried > 0 {
                cost = carried
            } else if let model = trimmedModel, let estimated = estimate(model, entry.tokens) {
                cost = estimated
            } else {
                if let model = displayModel, entry.reportedTotalTokens > 0 {
                    accumulator.addUnknownModel(day: day, model: model)
                }
                continue
            }
            accumulator.add(day: day, tokens: entry.reportedTotalTokens, cost: cost, model: modelName)
        }
        return accumulator.build()
    }
}
