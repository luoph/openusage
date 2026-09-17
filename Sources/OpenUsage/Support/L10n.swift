import SwiftUI

/// UI string translation.
///
/// The English text **is** the key: `L10n.t("Usage Trend")`. That keeps English free (nothing to look
/// up, nothing to keep in sync) and makes an untranslated string degrade to readable English instead of
/// showing a raw identifier. The cost is that editing English copy needs the matching table entry
/// updated — cheap next to maintaining a parallel set of key constants.
///
/// Translation happens where a string is **displayed**, not where it is produced. Provider code
/// (metric titles, error descriptions) keeps returning plain English `String`s, so nothing in the
/// provider layer, the widget registry, or the snapshot cache has to know about language at all — and
/// switching language doesn't need a refresh to repaint already-fetched data.
enum L10n {
    /// The language strings resolve to right now.
    static var current: ResolvedLanguage { AppLanguage.current.resolved }

    /// Translate one UI string, given its English original.
    static func t(_ english: String) -> String {
        t(english, language: current)
    }

    /// Testable seam: the same lookup against an explicit language.
    static func t(_ english: String, language: ResolvedLanguage) -> String {
        switch language {
        case .english: return english
        case .chinese: return ChineseStrings.table[english] ?? english
        }
    }

    /// Interpolating counterpart for copy with a runtime value: the format string is the English
    /// original with `%@` placeholders — `L10n.format("Updated %@ ago", value)`.
    static func format(_ english: String, _ arguments: CVarArg...) -> String {
        String(format: t(english), arguments: arguments)
    }
}

extension Text {
    /// `Text` from a translated UI string. Deliberately not an overload of `Text.init` so it stays
    /// obvious at the call site that the string goes through the table.
    init(localized english: String) {
        self.init(L10n.t(english))
    }
}

/// Rebuilds its content when the UI language changes, so every `L10n.t(…)` call re-runs and the whole
/// tree repaints in the new language. Mounted once at the popover root.
///
/// `.id()` is the blunt instrument here on purpose: translation is a plain function rather than
/// observable state, so there is nothing for SwiftUI to track. Rebuilding drops transient view state
/// (scroll offset, open disclosure) — acceptable for an action the user takes once.
struct LocalizedRoot<Content: View>: View {
    @AppStorage(AppLanguage.key) private var language = AppLanguage.fallback

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .id(language.resolved)
            // Dates, numbers, and any `LocalizedStringKey` in system controls follow the same choice.
            .environment(\.locale, language.resolved == .chinese ? Locale(identifier: "zh-Hans") : Locale(identifier: "en"))
    }
}
