# Backlog

## Next: Epic 2, fog and POIs (toward Gate B)

Read MASTER_BUILD_SPEC.md, STATE.md and WORLD_AND_SCENARIO_BIBLE.md before scenario work.
Add UNKNOWN/EXPLORED/VISIBLE fog with radius 5, location markers, generic POI window,
and inn/monastery examples. Unknown terrain stays hidden; discovered terrain persists
as explored; reaching a POI opens its UI. Authored dialogue follows in Epic 4.
Gate A passed: the 20 x 20 movement prototype and its tests are complete.

## Bootstrap follow-ups

- Investigate ObjectDB/resource retention diagnostics at forced shutdown.
- Replace the tightly coupled demo main scene before removing its story assets.
- Verify interactive controls, dialogue and combat when adapting those systems.

## Locked sequence

After Gate A: fog/POIs, authored dialogue (Gate B), Claude integration (Gate C),
language evaluation (Gate D), grounding, save/load, evidence and investigation.
Follow sections 37, 40 and 41 of MASTER_BUILD_SPEC.md for the precise sequence.
No full map, campaign expansion or polish before their stated gates.
