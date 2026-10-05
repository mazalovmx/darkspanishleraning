# Backlog

## Next: Claude client and validated response (steps 06-07 / Epic 5, Gate C)

Gate B passed: reached POIs support authored free-text conversations and reopening.
Add API key access from the environment, one request per turn, timeout, one retry,
strict response parsing/schema validation, and authored fallback. Verify current
Anthropic API/model availability before live integration; the configured ID is not
proof of availability. Never log/store API keys or let response IDs mutate world state.
Acceptance: malformed/network failures cannot crash or block gameplay; fallback remains
usable without a key. Gate C requires actual dialogue integration, not just mocked tests.
Spanish evaluation follows (step 08 / Gate D); grounding and save/load follow in order.

## Required language practice

User clarification 2026-10-05: every purchase and most quests require active Spanish
production and intensive practice. Apply this in evaluation, transactional archetypes
and quest content. Do not implement click-only bypasses or make live API availability
a progression gate. Root and docs specifications contain the same clarification.

## Bootstrap follow-ups

- Investigate ObjectDB/resource retention diagnostics at forced shutdown.
- Replace the tightly coupled demo main scene before removing its story assets.
- Verify interactive controls, dialogue and combat when adapting those systems.

## Locked sequence

After Gate A: fog/POIs, authored dialogue (Gate B), Claude integration (Gate C),
language evaluation (Gate D), grounding, save/load, evidence and investigation.
Follow sections 37, 40 and 41 of MASTER_BUILD_SPEC.md for the precise sequence.
No full map, campaign expansion or polish before their stated gates.
