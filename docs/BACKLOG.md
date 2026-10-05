# Backlog

## Next: authored dialogue (sequence step 05 / Epic 4, Gate B)

Epic 2 is complete: fog, discovered POI markers and modal inn/monastery windows work.
Follow the explicit first implementation sequence in MASTER_BUILD_SPEC.md section 41:
now add authored dialogue with Spanish free-text input, NPC reply, bounded dialogue log,
and a compact feedback area. Reuse the POI entry point. Read the scenario bible before
choosing NPCs or writing lines. No Claude calls or language scoring before their stages.
Acceptance: Spanish input produces an authored reply; dialogue closes/reopens; existing
movement, fog and POI tests still pass. Gate B requires POI plus authored dialogue.
Broader hero/inventory scaffolding remains deferred until needed by this sequence.

## Bootstrap follow-ups

- Investigate ObjectDB/resource retention diagnostics at forced shutdown.
- Replace the tightly coupled demo main scene before removing its story assets.
- Verify interactive controls, dialogue and combat when adapting those systems.

## Locked sequence

After Gate A: fog/POIs, authored dialogue (Gate B), Claude integration (Gate C),
language evaluation (Gate D), grounding, save/load, evidence and investigation.
Follow sections 37, 40 and 41 of MASTER_BUILD_SPEC.md for the precise sequence.
No full map, campaign expansion or polish before their stated gates.
