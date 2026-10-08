# Claude prompt contract

Status (2026-10-07): the text below is the target contract from the master spec. The runtime prompt in game/src/claude/claude_client.gd is a condensed variant of it. One live smoke test passed on 2026-10-05 and has not been rerun since the prompt gained grounding and curriculum context.

<role>
You are an NPC in a dark low-fantasy investigation game and,
separately, an invisible Spanish-language evaluator.

Inside npc_reply you must never behave like a language teacher.
</role>

<world_rules>
WORLD_FACTS are canonical.
NPC_KNOWLEDGE contains facts this NPC can know.
NPC_BELIEFS may be wrong.
NPC_SECRETS may be concealed.

Never invent canonical events, clues, locations, identities or causes.
If information is absent, the NPC does not know it.
</world_rules>

<npc_behavior>
Remain in character.

The NPC may:
- misunderstand,
- lie when motivated,
- evade,
- bargain,
- refuse,
- speculate,
- express uncertainty.

Separate knowledge from belief.
Do not reveal information merely because the player asks.
</npc_behavior>

<spanish>
The player is learning Spanish.

LANGUAGE_PROFILE defines target difficulty.

Adjust:
- grammar,
- vocabulary,
- sentence length,
- implicitness,
- interaction pressure.

If meaning is understandable, continue the conversation.
Correct no more than two important errors per turn.
Prefer implicit recasts inside npc_reply.
</spanish>

<progression>
Successive conversations should generally become harder.

Increase difficulty through:
1. grammar,
2. richer vocabulary,
3. longer clauses,
4. less explicit context,
5. pragmatic implication,
6. conflicting interpretations.

Do not increase all dimensions at once.
</progression>

<semiotics>
A statement is evidence about a person's belief or intention,
not automatic truth about the world.

When relevant distinguish:
observation,
inference,
rumor,
accusation,
promise,
order,
confession,
declaration.
</semiotics>

<output>
Return valid JSON only.
Follow RESPONSE_SCHEMA exactly.
</output>

The client sends NPC grounding (knowledge, beliefs, releasable secrets), the player
message, the last three exchanges, the learner profile, the taught grammar and the
scheduled focus. The runtime prompt requires one JSON response and at most two
corrections. A suggested unlock is verified deterministically before any change;
attitude deltas other than zero are rejected. Not sent yet: scene, relationship,
focus verbs, recent errors, conversation summary (see BACKLOG.md).
Reference checked 2026-10-05:
- https://platform.claude.com/docs/en/api/messages/create
- https://platform.claude.com/docs/en/models/overview
Model default: claude-sonnet-5-5, stored only in runtime configuration (not scripts).

Language context now includes observed grammar/verb mastery and allowed tag lists.
The runtime prompt requests current-block corrections and natural NPC recasts, and
forbids crediting the NPC's wording as player success. Only four NPCs use this path.

Update 2026-10-07: 30 NPCs use the conversation path. The learner context carries
`curriculum.orthography` ("ignore" before the last block, "check" in it); the system
prompt tells Claude to ignore tilde, ü and apostrophe differences when "ignore" and to
judge naturalness. Before the last block the game also drops such corrections itself.

Review prompt (`REVIEW_PROMPT`, `request_review`): after the campaign journal accepts a
conclusion, the typed sentence, the card's prompt and the learner context are sent for a
review that returns only the `language` object of the response schema (validated by
`valid_language`). Its corrections are shown under the journal feedback; it changes no
record and no mastery, and offline it is skipped without a request. It uses its own
client instance, so the map is not locked while it runs.

Provider chain (user request 2026-10-08; order changed by the completion plan):
`claude_client.gd` follows `provider_order` in `config/game.json`, by default DeepSeek
(`deepseek_model`: `deepseek-flash`), then Claude (`claude_model`), then the authored
offline reply. NVIDIA (`nvidia_model`) is used only when listed. Keys `DEEPSEEK_API_KEY`,
`ANTHROPIC_API_KEY`, `NVIDIA_API_KEY` are loaded from the local `.env` by
`tools/run-game.ps1`. DeepSeek requests set `thinking: {"type": "disabled"}` and
`response_format: {"type": "json_object"}` (official API reference, create chat
completion; the system prompt already asks for JSON, which JSON mode requires).
Anthropic offers no balance endpoint for an API key, so its budget is judged by the
response: HTTP 402 (`billing_error`) or a 400 mentioning the credit balance marks it
exhausted for the session. DeepSeek's `GET /user/balance` is checked once before its
first use (`is_available: false` skips it); a 402 also marks it exhausted. A 401, 403 or
404 (key, permission, model) skips that provider for the session as well. A temporary
failure (transport, timeout, 408, 429, 5xx, unparseable answer) is retried once on the
same provider; a second failure or another client error moves the turn to the next
provider. One turn sends at most three requests and lasts at most 45 seconds (each
request at most 20 s); then the authored offline reply is used. Only one answer is ever
applied to a turn; a request still in flight when the turn ends is cancelled. DeepSeek
and NVIDIA receive the same system prompt and context in the OpenAI chat format; their
answer is converted to the Messages envelope and passes the same validation. The client
keeps `last_turn` in memory (request id, provider, model, reason, ms, output tokens),
never keys, prompts or replies. With no provider left the game plays offline.
