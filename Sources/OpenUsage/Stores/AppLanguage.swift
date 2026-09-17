import Foundation

/// The language the app actually ships strings for. English is the source language — every UI string
/// is written in English in code — so it needs no table and can never be missing.
enum ResolvedLanguage: String, Hashable, Sendable {
    case english
    case chinese

    /// Matches one entry of `Locale.preferredLanguages` ("zh-Hans-CN", "en-GB", …) to a shipped
    /// language, or nil when the app has no strings for it. Only the base code is compared: every
    /// regional English is English, and Traditional Chinese falls in with Simplified rather than
    /// dropping to English, which would read far worse for a Chinese reader.
    init?(preferredLanguage code: String) {
        let base = code.split(separator: "-").first.map(String.init)?.lowercased()
            ?? code.lowercased()
        switch base {
        case "en": self = .english
        case "zh": self = .chinese
        default: return nil
        }
    }
}

/// UI language, overridable in Settings. `.auto` follows macOS; a system language the app has no
/// strings for lands on English rather than a half-translated screen.
enum AppLanguage: String, Hashable, Sendable, CaseIterable, UserDefaultsBacked {
    case auto
    case english
    case chinese

    static let key = "language"
    static var fallback: AppLanguage { .auto }

    /// Each option names itself in its own language (the macOS convention), so "中文" stays readable
    /// while the UI is still English — only "Automatic" follows the current language.
    var label: String {
        switch self {
        case .auto: return L10n.t("Automatic")
        case .english: return "English"
        case .chinese: return "中文"
        }
    }

    /// The language strings actually render in.
    var resolved: ResolvedLanguage {
        switch self {
        case .english: return .english
        case .chinese: return .chinese
        case .auto: return Self.systemLanguage
        }
    }

    /// The first macOS preferred language the app ships strings for, else English.
    static var systemLanguage: ResolvedLanguage {
        for code in Locale.preferredLanguages {
            if let match = ResolvedLanguage(preferredLanguage: code) { return match }
        }
        return .english
    }
}
