# Pi

Tracks what the [pi](https://github.com/earendil-works/pi) coding agent costs you, read from the
session logs pi already writes on your Mac.

Pi is bring-your-own-key: it drives whatever model you point it at, so its bill is spread across
whichever providers you use it with. This card puts that back together — **one card for everything pi
spends**, whatever model it drove. It's also the only place usage on a provider OpenUsage has no card
for (DeepSeek, an OpenAI-compatible endpoint, a local gateway) can show up at all.

## What it tracks

| Metric | Meaning |
|---|---|
| Usage Trend | A day-by-day sparkline of tokens over the last month |
| Today / Yesterday / Last 30 Days | Local cost and tokens across every request pi made |

There are no quota meters: pi has no account and no usage API — it's a local CLI — so there is nothing
to meter against. The spend tiles and trend are the whole card.

Hover a spend tile for the per-model breakdown. Because this one card mixes providers, every model says
which one billed it — `deepseek-flash · DeepSeek`, `claude-opus-4-8 · Claude`. That keeps the same model
name reached two ways (a vendor's own API and a gateway like OpenRouter) as two rows, since they bill
separately. A provider OpenUsage doesn't recognize keeps pi's own name for it, unchanged.

## Where the data comes from

Use pi as usual. OpenUsage reads its session logs under `~/.pi/agent/sessions/`, honoring pi's own
overrides: `$PI_CODING_AGENT_SESSION_DIR` wins, then `$PI_CODING_AGENT_DIR/sessions`. There is no login,
no API key, and nothing to paste. No log data leaves your Mac.

Pi records what each request cost in its own logs, so those dollars come straight from pi. When pi logs
a request at `$0` — subscription usage it doesn't price — the tokens are priced through the shared
[model pricing](../pricing.md) instead. Either way the dollars are an estimate at published rates (that's
the ⓘ), not a provider invoice; the token counts are measured. Days are grouped in your Mac's local time
zone. A period with no usage reads **No data** rather than a misleading `$0.00 · 0 tokens`, the same as
every other spend-tracking provider.

## How pi usage is counted once

A request pi makes has two plausible homes: pi (the agent that made it) and the provider that billed it
(a Claude sub, a Codex sub, …). OpenUsage counts it **on the pi card only**, so a dollar is never counted
twice — not on two cards, and not twice in Total Spend.

That means a Claude sub driven through pi appears in pi's spend tiles, not in Claude's. Claude's own
Session and Weekly meters are account-wide and come from Anthropic, so they are unaffected: they still
include everything that sub spent, pi included.

## Troubleshooting

- **"Pi not detected"** — OpenUsage found no session logs. Run `pi` once so it writes one, or set
  `PI_CODING_AGENT_SESSION_DIR` if your sessions live somewhere custom.
- **Spend tiles show "No data"** — pi wrote no sessions in the last 30 days.
- **A model shows as unpriced** — pi logged the request at `$0` and the shared pricing has no rate for
  that model, so it's excluded from the totals and named in the tile's warning.
