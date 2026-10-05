# Architecture

## Current bootstrap

Godot 4.6.2 opens `game/project.godot`; `res://` resolves to `game/`.
The entry point is `game/src/world/world_map.tscn`. The original demo remains at `game/src/main.tscn`.
Upstream: https://github.com/gdquest-demos/godot-open-rpg at
`19bd328fae9e4b534d3bb6db380a3d871d6ea58f` (MIT; see game/LICENSE and game/CREDITS.md).

Retained reusable systems:
- `game/src/combat/` and `game/combat/`: turn-based battle orchestration, actions, battlers and UI.
- `game/src/field/`: maps, camera, gameboard, grid movement, interactions and transitions.
- `game/src/common/inventory.gd` and `game/src/field/ui/inventory/`: inventory data and UI.
- `game/addons/dialogic/` and conversation templates: authored dialogue infrastructure.
- `game/assets/`: upstream graphics, audio and fonts required by retained scenes.

Do not move retained files casually: scenes use resource paths and UIDs.
New runtime source/content/tests are placed under `game/` to keep them inside res://.
Root `src/`, `content/`, `assets/`, and `tests/` remain reserved scaffolding. No staging
or duplicate copies are required. This is a documented placement decision, not a specification edit.
Root `config/game.json` is an initial configuration contract; no loader exists yet.

## Planned authority boundary

One GameState will own canonical state. JSON content defines facts. Claude proposes
responses; deterministic validation precedes state changes. These systems are not
implemented at bootstrap. Do not treat upstream inventory persistence as the specified
JSON save/load system. Implementation order and gates are in MASTER_BUILD_SPEC.md.

## Prototype movement

`game/src/world/world_state.gd` owns day, hero cell, remaining movement, terrain and
weighted AStarGrid2D. It is RefCounted and independent of scene nodes. Moves validate
reachability and total cost before changing state; costs apply on entering a cell.
The one-hero end turn advances day and replenishes movement.
`world_map.gd` builds TileMapLayer, Sprite2D, camera and UI and routes mouse events to
this state. `game/content/world/prototype.json` authors the fixed terrain layout.
`game/tests/world_map_test.gd` tests state and actual viewport input dispatch.
Retained upstream autoloads are unchanged; the new scene activates its own camera.
