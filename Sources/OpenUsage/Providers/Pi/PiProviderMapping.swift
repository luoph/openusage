import Foundation

/// Maps a pi session log's `provider` field to the OpenUsage provider whose subscription paid for it.
/// Pi is a BYO-key agent that drives other providers' models, so every request has two possible homes:
/// the agent that made it (pi) and the provider that billed it (Claude, Codex, …).
///
/// Pi has its own card here, and that card counts **all** of pi's usage — including the models pi drove
/// through a provider that has a card of its own. To keep a dollar from being counted twice (on the pi
/// card and again on the provider card, and so twice in Total Spend), the fold-in into provider cards is
/// off: see `foldsIntoProviderCards`.
///
/// Only providers OpenUsage already has a card for are listed. Pi providers with no OpenUsage
/// equivalent (`deepseek`, `nvidia-nim`, a plain OpenAI-compatible endpoint, …) are intentionally
/// absent — their usage still lands on the pi card, which is the only card that can show it.
enum PiProviderMapping {
    /// Whether pi usage also folds into the underlying provider's card (Claude's and Codex's spend
    /// tiles and Usage Trend). Off while pi is tracked as its own card, so pi's spend is counted once.
    ///
    /// Flip to `true` to get upstream's behavior back — pi usage attributed to the provider that billed
    /// it — at the cost of double-counting it against the pi card.
    static let foldsIntoProviderCards = false

    /// pi `provider` value → OpenUsage `Provider.id`.
    static let providerToCard: [String: String] = [
        "anthropic": "claude",
        "claude-agent-sdk": "claude",
        "openai-codex": "codex",
        "cursor": "cursor",
        "zai": "zai",
        "zhipu": "zai",
        "google-antigravity": "antigravity",
        "github-copilot": "copilot"
    ]

    /// The OpenUsage card id for a pi provider, or nil when pi used a provider OpenUsage doesn't track.
    static func cardID(forPiProvider provider: String) -> String? {
        providerToCard[provider]
    }
}
