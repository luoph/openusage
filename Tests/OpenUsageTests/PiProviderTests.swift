import Foundation
import XCTest
@testable import OpenUsage

/// The pi card: one card for everything pi spends, whatever provider it drove — including providers
/// OpenUsage has no card for, which is the only place that usage can appear.
final class PiProviderTests: XCTestCase {
    /// Two hours after the fixture's only session line, so both land on the same local day in any
    /// time zone the tests run in — "Today" is a local-calendar bucket.
    private let now = OpenUsageISO8601.date(from: "2026-07-12T12:00:00.000Z")!

    private func sessionLine(
        id: String, provider: String, model: String, cost: String, total: Int = 150
    ) -> String {
        """
        {"type":"message","id":"\(id)","timestamp":"2026-07-12T10:00:00.000Z","message":{"role":"assistant","provider":"\(provider)","model":"\(model)","usage":{"input":100,"output":50,"cacheRead":0,"cacheWrite":0,"totalTokens":\(total),"cost":{"total":\(cost)}}}}
        """
    }

    /// Writes one session file into a fresh sessions directory, mirroring pi's
    /// `<sessions>/<cwd-slug>/<stamp>.jsonl` layout.
    private func makeSessionsDirectory(lines: [String]) throws -> URL {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pi-provider-tests-\(UUID().uuidString)")
        let sessions = root.appendingPathComponent("sessions/--Users-test-project--")
        try FileManager.default.createDirectory(at: sessions, withIntermediateDirectories: true)
        try lines.joined(separator: "\n").write(
            to: sessions.appendingPathComponent("2026-07-12T10-00-00-000Z_session.jsonl"),
            atomically: true, encoding: .utf8
        )
        return root.appendingPathComponent("sessions")
    }

    @MainActor
    private func makeProvider(sessionsDirectory: URL?) -> PiProvider {
        let environment = FakeEnvironment(
            sessionsDirectory.map { ["PI_CODING_AGENT_SESSION_DIR": $0.path] } ?? [:]
        )
        let refreshedAt = now
        // A fresh in-memory incremental scanner: no persistence, so the test never touches the real
        // parse cache in Application Support.
        return PiProvider(
            scanner: PiUsageScanner(
                environment: environment,
                incrementalScanner: IncrementalJSONLScanner<PiUsageScanner.Entry>()
            ),
            paths: PiSessionPaths(environment: environment),
            pricing: { .empty },
            now: { refreshedAt }
        )
    }

    @MainActor
    func testCountsEveryProviderPiDroveIncludingOnesWithoutTheirOwnCard() async throws {
        let directory = try makeSessionsDirectory(lines: [
            sessionLine(id: "a", provider: "deepseek", model: "deepseek-flash", cost: "0.25"),
            sessionLine(id: "b", provider: "anthropic", model: "claude-opus-4-8", cost: "0.5")
        ])
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let snapshot = await makeProvider(sessionsDirectory: directory).refresh()

        XCTAssertNil(snapshot.errorCategory)
        let today = try XCTUnwrap(values(snapshot.lines, "Today"))
        // pi's own carried costs, summed across both providers: $0.25 + $0.50.
        XCTAssertEqual(today.first(where: { $0.kind == .dollars })?.number ?? 0, 0.75, accuracy: 0.0001)
        XCTAssertEqual(today.first(where: { $0.label == "tokens" })?.number, 300)

        let models = try XCTUnwrap(snapshot.usageHistory?.modelUsage?.daily.first?.models.map(\.model))
        // Each model says which provider billed it — the pi card is the one place they mix.
        XCTAssertEqual(Set(models), ["deepseek-flash · DeepSeek", "claude-opus-4-8 · Claude"])
    }

    @MainActor
    func testReportsNotDetectedWhenThereAreNoSessionLogs() async throws {
        let empty = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("pi-provider-tests-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: empty, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: empty) }

        let provider = makeProvider(sessionsDirectory: empty)

        let snapshot = await provider.refresh()
        XCTAssertEqual(snapshot.errorCategory, .notLoggedIn)
        let hasCredentials = await provider.hasLocalCredentials()
        XCTAssertFalse(hasCredentials)
    }

    @MainActor
    func testDetectsPiFromSessionLogsAlone() async throws {
        let directory = try makeSessionsDirectory(lines: [
            sessionLine(id: "a", provider: "deepseek", model: "deepseek-flash", cost: "0.25")
        ])
        defer { try? FileManager.default.removeItem(at: directory.deletingLastPathComponent()) }

        let detected = await makeProvider(sessionsDirectory: directory).hasLocalCredentials()
        XCTAssertTrue(detected)
    }

    /// Pi counts its own usage in full, so the provider cards must not also fold it in — otherwise the
    /// same dollar lands on two cards and twice in Total Spend.
    func testPiUsageIsNotAlsoFoldedIntoProviderCards() {
        XCTAssertFalse(PiProviderMapping.foldsIntoProviderCards)
    }

    private func values(_ lines: [MetricLine], _ label: String) -> [MetricValue]? {
        for line in lines {
            if case .values(let lineLabel, let values, _, _, _, _) = line, lineLabel == label {
                return values
            }
        }
        return nil
    }
}
