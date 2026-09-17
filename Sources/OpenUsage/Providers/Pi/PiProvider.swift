import Foundation

/// Typed failures for the pi provider, so telemetry groups them by a stable category
/// (see `ErrorCategory.swift`).
enum PiUsageError: Error, LocalizedError, Equatable {
    /// No pi session logs on this machine — pi isn't installed, or has never completed a session.
    case notDetected

    var errorDescription: String? {
        switch self {
        case .notDetected:
            return "Pi not detected. Run `pi` once so it writes session logs."
        }
    }
}

/// Tracks what the pi coding agent spends, scanned from its own session logs.
///
/// Pi is BYO-key: it drives whatever model you point it at, so its bill is spread across whichever
/// providers you use with it — including ones OpenUsage has no card for (DeepSeek, an OpenAI-compatible
/// endpoint). This card answers "what is pi costing me", counting every request pi made, and is the only
/// place usage on an untracked provider can show up at all. Because it counts everything, pi usage is
/// not also folded into the underlying provider's card — see `PiProviderMapping.foldsIntoProviderCards`.
///
/// Local-only: there is no pi account or API, so there are no quota meters, just the spend tiles and
/// usage trend every log-scanned provider shares.
@MainActor
final class PiProvider: ProviderRuntime {
    // No quick links: pi has no account page or status page to send anyone to — it is a local CLI.
    let provider = Provider(id: "pi", displayName: "Pi", icon: .providerMark("pi"))

    private let scanner: PiUsageScanner
    private let paths: PiSessionPaths
    private let pricing: @Sendable () async -> ModelPricing
    private let now: @Sendable () -> Date

    /// Names the local source on hover. "(estimated)" because pi computes each request's cost itself
    /// from published model rates — it is pi's arithmetic, not a provider invoice — and because
    /// subscription requests pi logs at $0 are priced here through the shared engine.
    private let sourceNote = "From your pi logs (estimated)"

    init(
        scanner: PiUsageScanner = .shared,
        paths: PiSessionPaths = PiSessionPaths(),
        pricing: @escaping @Sendable () async -> ModelPricing = { await ModelPricingStore.shared.current() },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.scanner = scanner
        self.paths = paths
        self.pricing = pricing
        self.now = now
    }

    var widgetDescriptors: [WidgetDescriptor] {
        // No account API to meter against, so the trend leads and the spend tiles follow — the same
        // tail every log-scanned provider shows.
        [
            .usageTrend(provider: provider)
                .exportingHistory(scope: .machineLocal, estimatedCost: true, sourceNote: sourceNote)
        ] + WidgetDescriptor.spendTiles(provider: provider)
    }

    func hasLocalCredentials() async -> Bool {
        // Pi has no credential of its own to find — a session log is the footprint. Local-only, and off
        // the main actor because it walks the sessions directory.
        await loadOffMainActor { [paths] in paths.hasSessionLogs() }
    }

    func refresh() async -> ProviderSnapshot {
        // One clock for the whole refresh, so the scan cutoff, tiles, trend, and snapshot timestamp
        // can't straddle a midnight boundary.
        let refreshedAt = now()
        let pricing = await pricing()

        // cardID nil: every request pi made, whatever provider billed it.
        guard let scan = await scanner.scan(cardID: nil, now: refreshedAt, pricing: pricing) else {
            return ProviderSnapshot.error(provider: provider, error: PiUsageError.notDetected)
        }

        var lines: [MetricLine] = []
        SpendTileMapper.appendTokenUsage(
            scan.series, to: &lines, now: refreshedAt,
            unknownModelsByDay: scan.unknownModelsByDay,
            modelUsage: scan.modelUsage,
            modelSourceNote: sourceNote
        )
        SpendTileMapper.appendUsageTrend(scan.series, to: &lines, now: refreshedAt, note: sourceNote)
        MetricLine.appendNoDataIfNeeded(&lines)

        return ProviderSnapshot.make(
            provider: provider,
            plan: nil,
            lines: lines,
            refreshedAt: refreshedAt,
            usageHistory: ProviderUsageHistory(
                series: scan.series,
                modelUsage: scan.modelUsage,
                unknownModelsByDay: scan.unknownModelsByDay
            )
        )
    }
}

/// The local-only "credential" probe for pi: whether its sessions directory holds any log to scan.
/// Split out so `hasLocalCredentials()` and `refresh()` resolve the directory the same way.
struct PiSessionPaths: Sendable {
    private let environment: EnvironmentReading
    private let homeDirectory: @Sendable () -> URL

    init(
        environment: EnvironmentReading = ProcessEnvironmentReader(),
        homeDirectory: @escaping @Sendable () -> URL = { FileManager.default.homeDirectoryForCurrentUser }
    ) {
        self.environment = environment
        self.homeDirectory = homeDirectory
    }

    func hasSessionLogs() -> Bool {
        let directory = PiPaths.sessionsDirectory(environment: environment, homeDirectory: homeDirectory())
        return !JSONLScanning.jsonlFiles(under: directory).isEmpty
    }
}
