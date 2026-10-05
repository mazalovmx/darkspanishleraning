# Backlog

## Next: Epic 1, minimal world map (Gate A)

Read MASTER_BUILD_SPEC.md and STATE.md before implementation.
Create a 20 x 20 TileMapLayer prototype, camera pan/zoom, selectable hero,
AStarGrid2D path preview, terrain costs and end-turn control.
Acceptance: movement consumes points; forest costs 2 vs road 1;
mountains/water are impassable. Run relevant tests and the smallest scene.
Resolve Godot resource placement for new root-level scaffolding before adding code.

## Bootstrap follow-ups

- Investigate ObjectDB/resource retention diagnostics at forced shutdown.
- Replace the tightly coupled demo main scene before removing its story assets.
- Verify interactive controls, dialogue and combat when adapting those systems.

## Locked sequence

After Gate A: fog/POIs, authored dialogue (Gate B), Claude integration (Gate C),
language evaluation (Gate D), grounding, save/load, evidence and investigation.
Follow sections 37, 40 and 41 of MASTER_BUILD_SPEC.md for the precise sequence.
No full map, campaign expansion or polish before their stated gates.
