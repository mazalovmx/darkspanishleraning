# Architecture

## Current bootstrap

Godot 4.6.2 opens `game/project.godot`; `res://` resolves to `game/`.
The entry point remains `game/src/main.tscn`, the upstream demo used for bootstrap validation.
Upstream: https://github.com/gdquest-demos/godot-open-rpg at
`19bd328fae9e4b534d3bb6db380a3d871d6ea58f` (MIT; see game/LICENSE and game/CREDITS.md).

Retained reusable systems:
- `game/src/combat/` and `game/combat/`: turn-based battle orchestration, actions, battlers and UI.
- `game/src/field/`: maps, camera, gameboard, grid movement, interactions and transitions.
- `game/src/common/inventory.gd` and `game/src/field/ui/inventory/`: inventory data and UI.
- `game/addons/dialogic/` and conversation templates: authored dialogue infrastructure.
- `game/assets/`: upstream graphics, audio and fonts required by retained scenes.

Do not move retained files casually: scenes use resource paths and UIDs.
The root `src/`, `content/`, `assets/`, and `tests/` directories are planned scaffolding,
not yet loaded Godot resources. Before introducing new runtime files, establish an
explicit import/staging arrangement or document their placement inside `game/`.
Root `config/game.json` is an initial configuration contract; no loader exists yet.

## Planned authority boundary

One GameState will own canonical state. JSON content defines facts. Claude proposes
responses; deterministic validation precedes state changes. These systems are not
implemented at bootstrap. Do not treat upstream inventory persistence as the specified
JSON save/load system. Implementation order and gates are in MASTER_BUILD_SPEC.md.
