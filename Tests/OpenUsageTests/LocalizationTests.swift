import XCTest
@testable import OpenUsage

/// UI language selection and string lookup: the English text is the key, so English is pass-through
/// and anything untranslated degrades to English rather than showing a raw identifier.
final class LocalizationTests: XCTestCase {

    // MARK: - Matching a system language

    func testMatchesEnglishAndChineseRegardlessOfRegion() {
        XCTAssertEqual(ResolvedLanguage(preferredLanguage: "en"), .english)
        XCTAssertEqual(ResolvedLanguage(preferredLanguage: "en-GB"), .english)
        XCTAssertEqual(ResolvedLanguage(preferredLanguage: "zh-Hans-CN"), .chinese)
        // Traditional Chinese reads far better in Simplified than in English.
        XCTAssertEqual(ResolvedLanguage(preferredLanguage: "zh-Hant-TW"), .chinese)
    }

    func testUnshippedLanguageDoesNotMatch() {
        // No table for these, so `.auto` must fall through to English rather than half-translate.
        XCTAssertNil(ResolvedLanguage(preferredLanguage: "ja"))
        XCTAssertNil(ResolvedLanguage(preferredLanguage: "de-DE"))
        XCTAssertNil(ResolvedLanguage(preferredLanguage: ""))
    }

    // MARK: - Explicit choice

    func testExplicitChoiceIgnoresTheSystemLanguage() {
        XCTAssertEqual(AppLanguage.english.resolved, .english)
        XCTAssertEqual(AppLanguage.chinese.resolved, .chinese)
    }

    func testAutomaticResolvesToAShippedLanguage() {
        // Whatever this machine is set to, `.auto` always lands on a language with strings.
        XCTAssertTrue([.english, .chinese].contains(AppLanguage.auto.resolved))
    }

    func testUnsetDefaultsToAutomatic() {
        XCTAssertEqual(AppLanguage.fallback, .auto)
    }

    // MARK: - Lookup

    func testEnglishReturnsTheKeyItself() {
        XCTAssertEqual(L10n.t("Usage Trend", language: .english), "Usage Trend")
        // Even copy with no table entry at all.
        XCTAssertEqual(L10n.t("Some brand new string", language: .english), "Some brand new string")
    }

    func testChineseTranslatesKnownStrings() {
        XCTAssertEqual(L10n.t("Usage Trend", language: .chinese), "用量趋势")
        XCTAssertEqual(L10n.t("Session", language: .chinese), "会话")
        XCTAssertEqual(L10n.t("No data", language: .chinese), "无数据")
        XCTAssertEqual(L10n.t("Language", language: .chinese), "语言")
    }

    func testUntranslatedChineseFallsBackToEnglish() {
        // A provider error the table deliberately doesn't cover yet: English, never a raw key.
        let untranslated = "Pi not detected. Run `pi` once so it writes session logs."
        XCTAssertEqual(L10n.t(untranslated, language: .chinese), untranslated)
    }

    // MARK: - Table hygiene

    func testTableNeverMapsAStringToItself() {
        // A self-mapping entry is dead weight — English already returns the key.
        let noops = ChineseStrings.table.filter { $0.key == $0.value }
        XCTAssertTrue(noops.isEmpty, "redundant entries: \(noops.keys.sorted())")
    }

    /// A format string's translation must keep the same placeholders: `String(format:)` silently drops
    /// the argument when one goes missing, so "刷新 %@" losing its %@ would render as a bare "刷新".
    func testFormatPlaceholdersSurviveTranslation() {
        for (english, chinese) in ChineseStrings.table {
            for token in ["%@", "%d"] where english.contains(token) {
                XCTAssertEqual(
                    chinese.components(separatedBy: token).count,
                    english.components(separatedBy: token).count,
                    "\(token) count differs for \"\(english)\" → \"\(chinese)\""
                )
            }
        }
    }

    func testFormatSubstitutesIntoTheTranslation() {
        XCTAssertEqual(L10n.t("Refresh %@", language: .chinese), "刷新 %@")
        XCTAssertEqual(String(format: L10n.t("Refresh %@", language: .chinese), "Claude"), "刷新 Claude")
        XCTAssertEqual(String(format: L10n.t("%d metrics", language: .chinese), 4), "4 个指标")
    }

    func testTableHasNoEmptyValues() {
        let empties = ChineseStrings.table.filter { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertTrue(empties.isEmpty, "empty translations: \(empties.keys.sorted())")
    }

    /// The option labels must survive a round trip through the picker: each is looked up the same way
    /// the Settings picker does.
    func testLanguageOptionLabelsAreNonEmpty() {
        for option in AppLanguage.allCases {
            XCTAssertFalse(option.label.isEmpty, "\(option) has no label")
        }
        // Explicit choices name themselves in their own language, so they read the same either way.
        XCTAssertEqual(AppLanguage.chinese.label, "中文")
        XCTAssertEqual(AppLanguage.english.label, "English")
    }
}
