# Project state

Updated: 2026-10-04
Branch: implementation
Current task: Epic 1 minimal world map completed, with existing shutdown diagnostics.
Next task: Epic 2 fog and POIs. Gate A passed by automated state/input tests and scene checks.

## Provenance

Upstream repository: https://github.com/gdquest-demos/godot-open-rpg
Upstream commit: 19bd328fae9e4b534d3bb6db380a3d871d6ea58f
Engine verified: 4.6.2.stable.official.71f334935
Working project: game/project.godot; main scene: game/src/world/world_map.tscn.
The upstream/ checkout is an ignored local reference, not an embedded submodule.
Original root specifications and docs/ copies match byte-for-byte.

## Retained and removed

Retained turn-based combat, field/grid movement, inventory, UI, Dialogic, camera,
transitions and their required assets. See ARCHITECTURE.md for paths.
No demo story assets removed: main.tscn directly references town/forest dialogue,
quest interactions and battle scenes. Deletion is deferred until a replacement main
scene isolates these dependencies. No investigation gameplay has been added.

## Bootstrap changes

Added missing working docs, initial config and tracked directory scaffolding.
Patched Dialogic's portrait container: runtime debug settings are read only outside
editor mode. Previously editor import raised a Nil/PortraitContainers script error.
No speculative refactoring or changes to scenario/specification content.

## Checks actually run

- Engine version: correct 4.6.2 build.
- Editor import: exit 0; no script/import errors after the portrait fix.
- Headless main scene, 180 frames: exit 0; no startup script errors.
- Windowed main scene, 180 frames: exit 0; OpenGL Compatibility initialized on
  AMD Radeon Vega 8; no startup script errors. Window launched hidden.
- Root/docs specification hashes match.

## Known issues and unverified behavior

Editor shutdown reports ObjectDB instances leaked. Both timed runtime runs report
ObjectDB instances leaked and `26 resources still in use at exit`. These are unresolved
shutdown diagnostics, not a clean all-errors-free result. They did not prevent startup.
Original demo dialogue/combat, performance targets and export have not been tested.
Claude API, learner model, canonical GameState, evidence and JSON save/load are not
implemented. Initial config is not yet loaded by runtime code.

## Gates

Bootstrap startup accepted with the documented nonfatal shutdown limitations.
Gate A: passed for the prototype movement loop. Gates B through I: not passed.
Epic 2 is next; no later gated features have been implemented.

## Epic 1: minimal world map

- Authored 20 x 20 JSON terrain rendered with TileMapLayer, a Sprite2D hero and Camera2D.
- Weighted AStarGrid2D routes, cardinal movement, blocked water/mountains, all specified
  terrain costs. Out-of-bounds/unreachable/over-budget moves leave state unchanged.
- Click hero to select; hover previews a route and total cost; click destination moves.
  Right click deselects; middle drag pans; wheel zooms. Spanish UI shows day and points.
- End turn advances the single-hero day and restores 18 movement points.
- RefCounted WorldState owns prototype data; visuals reflect it. A full campaign
  GameState/autoload, HeroState, saves and multi-hero rules remain future work.
- New runtime code/content/tests live in game/ so Godot resource paths work without
  copying or external-path dependencies. Root scaffolding remains reserved.

Validation: 58 checks passed headless and with OpenGL on Radeon Vega 8, exit 0.
Coverage includes weighted detours, blocked and unreachable cells, full budget use,
atomic rejection, selection/movement via viewport mouse events, pan/zoom picking,
route preview and end-turn signal wiring. New default main scene ran for 60 frames.
Imported scripts successfully; inspected a rendered 1280 x 720 screenshot with route,
hero selection and readable controls. Existing shutdown leak diagnostics persist.
No manual human playtest or FPS benchmark is claimed.

Limitations: placeholder colored tiles, instant movement (no animation), single hero,
whole-route affordability required (no partial movement). No fog or POIs yet.
