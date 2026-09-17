import XCTest
@testable import OpenUsage

/// The pi log fold-in: parse pi's assistant usage lines, attribute them to the mapped OpenUsage card,
/// and price by pi's carried cost (else the engine). Also covers the shared scan-merge that folds the
/// pi slice into a provider's native scan.
final class PiUsageScannerTests: XCTestCase {
    private func d(_ iso: String) -> Date { OpenUsageISO8601.date(from: iso)! }

    /// Fixture pricing so the carried-$0 fall-through can be exercised: composer priced at $10/M input.
    private let pricing = ModelPricing(
        supplement: PricingSupplement(),
        primary: PricingCatalog(entries: [
            "composer-2.5": ModelRates(
                inputPerMillion: 10, outputPerMillion: 20,
                cacheWritePerMillion: 10, cacheReadPerMillion: 1
            )
        ]),
        secondary: PricingCatalog(entries: [:])
    )

    private let codexPricing = ModelPricing(
        supplement: PricingSupplement(pricing: [
            "gpt-5.6-sol": ModelRates(
                inputPerMillion: 5,
                outputPerMillion: 30,
                cacheWritePerMillion: 6.25,
                cacheReadPerMillion: 0.5
            )
        ]),
        primary: PricingCatalog(entries: [:]),
        secondary: PricingCatalog(entries: [:])
    )

    private func line(
        id: String = "m1", ts: String = "2026-07-12T10:00:00.000Z", provider: String = "anthropic",
        model: String = "claude-opus-4-8", input: Int = 100, output: Int = 50,
        cacheRead: Int = 0, cacheWrite: Int = 0, cacheWrite1h: Int = 0, total: Int = 150,
        cost: String? = "0.5"
    ) -> Data {
        let costJSON = cost.map { ",\"cost\":{\"total\":\($0)}" } ?? ""
        let json = """
        {"type":"message","id":"\(id)","timestamp":"\(ts)","message":{"role":"assistant","provider":"\(provider)","model":"\(model)","usage":{"input":\(input),"output":\(output),"cacheRead":\(cacheRead),"cacheWrite":\(cacheWrite),"cacheWrite1h":\(cacheWrite1h),"totalTokens":\(total)\(costJSON)}}}
        """
        return Data(json.utf8)
    }

    // MARK: - Parsing

    func testParsesMappedAnthropicLine() {
        let entry = PiUsageScanner.parseLine(line())
        XCTAssertEqual(entry?.cardID, "claude")
        XCTAssertEqual(entry?.model, "claude-opus-4-8")
        XCTAssertEqual(entry?.carriedCost, 0.5)
        XCTAssertEqual(entry?.reportedTotalTokens, 150)
        XCTAssertEqual(entry?.tokens.input, 100)
        XCTAssertEqual(entry?.tokens.output, 50)
    }

    func testSplitsCacheWriteBucketsBy1hPortion() {
        let entry = PiUsageScanner.parseLine(line(cacheWrite: 1000, cacheWrite1h: 400))
        XCTAssertEqual(entry?.tokens.cacheWrite1h, 400)
        XCTAssertEqual(entry?.tokens.cacheWrite5m, 600)
    }

    func testMapsCodexAndKeepsUnmappedButSkipsNonAssistant() {
        XCTAssertEqual(PiUsageScanner.parseLine(line(provider: "openai-codex"))?.cardID, "codex")
        // A provider with no card of its own is still parsed — the pi card is where it shows up.
        let unmapped = PiUsageScanner.parseLine(line(provider: "deepseek"))
        XCTAssertNil(unmapped?.cardID)
        XCTAssertEqual(unmapped?.piProvider, "deepseek")
        let userLine = Data(#"{"type":"message","timestamp":"2026-07-12T10:00:00.000Z","message":{"role":"user","provider":"anthropic","usage":{}}}"#.utf8)
        XCTAssertNil(PiUsageScanner.parseLine(userLine))
    }

    // MARK: - Aggregation

    func testCarriedCostUsedWhenPresent() {
        let scan = PiUsageScanner.aggregate(
            entries: [PiUsageScanner.parseLine(line(cost: "0.5"))!],
            cardID: "claude", since: .distantPast, pricing: .empty
        )
        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 0.5, accuracy: 0.0001)
        XCTAssertEqual(scan.series.daily.first?.totalTokens, 150)
    }

    func testZeroCarriedCostFallsThroughToPricing() {
        // Cursor logs $0; the engine prices composer's 100 input @ $10/M + 50 output @ $20/M = $0.002.
        let entry = PiUsageScanner.parseLine(line(provider: "cursor", model: "composer-2.5", cost: "0"))!
        let scan = PiUsageScanner.aggregate(entries: [entry], cardID: "cursor", since: .distantPast, pricing: pricing)
        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 0.002, accuracy: 0.00001)
    }

    func testZeroCostCodexFallbackUsesCodexLongContextRates() throws {
        let pricing = codexPricing
        let entry = try XCTUnwrap(PiUsageScanner.parseLine(line(
            provider: "openai-codex", model: "gpt-5.6-sol",
            input: 200_000, output: 10_000, cacheRead: 100_000, total: 310_000, cost: "0"
        )))
        let scan = PiUsageScanner.aggregate(
            entries: [entry], cardID: "codex", since: .distantPast, pricing: pricing,
            estimateCost: { CodexUsagePricing.estimatedCost(pricing: pricing, model: $0, tokens: $1) }
        )

        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 2.55, accuracy: 0.000_001)
    }

    func testPositiveCarriedCodexCostWinsOverSharedEstimator() throws {
        let entry = try XCTUnwrap(PiUsageScanner.parseLine(line(
            provider: "openai-codex", model: "gpt-5.6-sol",
            input: 200_000, output: 10_000, cacheRead: 100_000, total: 310_000, cost: "0.25"
        )))
        let scan = PiUsageScanner.aggregate(
            entries: [entry], cardID: "codex", since: .distantPast, pricing: codexPricing
        )

        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 0.25, accuracy: 0.000_001)
    }

    func testUnpriceableZeroCostBecomesUnknownModel() {
        let entry = PiUsageScanner.parseLine(line(provider: "cursor", model: "mystery-model", cost: "0"))!
        let scan = PiUsageScanner.aggregate(entries: [entry], cardID: "cursor", since: .distantPast, pricing: .empty)
        XCTAssertTrue(scan.series.daily.isEmpty)
        XCTAssertEqual(scan.unknownModelsByDay["2026-07-12"], ["mystery-model"])
    }

    func testDedupDropsRepeatedIDs() {
        let entries = [PiUsageScanner.parseLine(line(id: "dup"))!, PiUsageScanner.parseLine(line(id: "dup"))!]
        let scan = PiUsageScanner.aggregate(entries: PiUsageScanner.dedup(entries), cardID: "claude", since: .distantPast, pricing: .empty)
        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 0.5, accuracy: 0.0001)
    }

    func testFiltersToRequestedCard() {
        let scan = PiUsageScanner.aggregate(
            entries: [PiUsageScanner.parseLine(line(provider: "openai-codex"))!],
            cardID: "claude", since: .distantPast, pricing: .empty
        )
        XCTAssertTrue(scan.series.daily.isEmpty)
    }

    /// The pi card's own aggregation: a nil card counts every request pi made, including providers
    /// with no OpenUsage card of their own.
    func testNilCardAggregatesEveryProvider() {
        let entries = [
            PiUsageScanner.parseLine(line(id: "a", provider: "anthropic", cost: "0.5"))!,
            PiUsageScanner.parseLine(line(id: "b", provider: "openai-codex", cost: "0.25"))!,
            PiUsageScanner.parseLine(line(id: "c", provider: "deepseek", model: "deepseek-flash", cost: "0.125"))!
        ]
        let scan = PiUsageScanner.aggregate(entries: entries, cardID: nil, since: .distantPast, pricing: .empty)
        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 0.875, accuracy: 0.0001)
        XCTAssertEqual(scan.series.daily.first?.totalTokens, 450)
    }

    /// The unmapped provider carries pi's own cost, so the pi card prices it without any pricing data.
    func testUnmappedProviderUsesCarriedCost() {
        let entry = PiUsageScanner.parseLine(line(provider: "deepseek", model: "deepseek-flash", cost: "0.0125"))!
        let scan = PiUsageScanner.aggregate(entries: [entry], cardID: nil, since: .distantPast, pricing: .empty)
        XCTAssertEqual(scan.series.daily.first?.costUSD ?? 0, 0.0125, accuracy: 0.000_001)
        XCTAssertEqual(scan.modelUsage?.daily.first?.models.first?.model, "deepseek-flash · DeepSeek")
    }

    // MARK: - Model labels

    /// The pi card mixes providers, so each model says which one billed it. The same model name
    /// arriving over two providers stays two rows rather than silently merging.
    func testPiCardLabelsModelsWithTheirProvider() throws {
        let entries = [
            PiUsageScanner.parseLine(line(id: "a", provider: "deepseek", model: "glm-5", cost: "0.2"))!,
            PiUsageScanner.parseLine(line(id: "b", provider: "openrouter", model: "glm-5", cost: "0.1"))!
        ]
        let scan = PiUsageScanner.aggregate(entries: entries, cardID: nil, since: .distantPast, pricing: .empty)
        let models = try XCTUnwrap(scan.modelUsage?.daily.first?.models)
        XCTAssertEqual(Set(models.map(\.model)), ["glm-5 · DeepSeek", "glm-5 · OpenRouter"])
    }

    /// A provider card's rows are that provider's by definition, so they keep the bare model name.
    func testProviderCardKeepsTheBareModelName() {
        let scan = PiUsageScanner.aggregate(
            entries: [PiUsageScanner.parseLine(line(provider: "anthropic", model: "claude-opus-4-8"))!],
            cardID: "claude", since: .distantPast, pricing: .empty
        )
        XCTAssertEqual(scan.modelUsage?.daily.first?.models.first?.model, "claude-opus-4-8")
    }

    /// An unknown provider keeps pi's own id rather than a guessed brand name.
    func testUnknownProviderKeepsPiRawID() {
        XCTAssertEqual(PiProviderMapping.displayName(forPiProvider: "some-local-gateway"), "some-local-gateway")
        XCTAssertEqual(PiProviderMapping.displayName(forPiProvider: "zhipu"), "Z.ai")
    }

    /// Unpriceable models are named in the tile's warning, so they carry the label too.
    func testUnknownModelWarningCarriesTheProviderLabel() {
        let entry = PiUsageScanner.parseLine(line(provider: "deepseek", model: "mystery-model", cost: "0"))!
        let scan = PiUsageScanner.aggregate(entries: [entry], cardID: nil, since: .distantPast, pricing: .empty)
        XCTAssertEqual(scan.unknownModelsByDay["2026-07-12"], ["mystery-model · DeepSeek"])
    }

    // MARK: - Mapping and merge

    func testProviderMapping() {
        XCTAssertEqual(PiProviderMapping.cardID(forPiProvider: "claude-agent-sdk"), "claude")
        XCTAssertEqual(PiProviderMapping.cardID(forPiProvider: "zhipu"), "zai")
        XCTAssertNil(PiProviderMapping.cardID(forPiProvider: "nvidia-nim"))
    }

    func testMergedSumsNativeAndPiOnSameDay() {
        let native = DailyUsageAccumulator.merged([
            PiUsageScanner.aggregate(entries: [PiUsageScanner.parseLine(line(id: "n", cost: "1.0"))!], cardID: "claude", since: .distantPast, pricing: .empty)
        ])
        let pi = PiUsageScanner.aggregate(entries: [PiUsageScanner.parseLine(line(id: "p", cost: "0.5"))!], cardID: "claude", since: .distantPast, pricing: .empty)
        let merged = DailyUsageAccumulator.merged([native, pi])
        XCTAssertEqual(merged?.series.daily.first?.costUSD ?? 0, 1.5, accuracy: 0.0001)
        XCTAssertEqual(merged?.series.daily.first?.totalTokens, 300)
    }

    func testMergedReturnsNilWhenAllNil() {
        XCTAssertNil(DailyUsageAccumulator.merged([nil, nil]))
    }
}
