# Architecture

## Current layout (updated 2026-10-07)

Godot 4.6.2 opens `game/project.godot`; `res://` resolves to `game/`.
The entry point is `game/src/world/province_map.tscn` (the 160x120 province). It reuses
`world_map.gd`; `world_map.tscn` is the 20x20 development map. The original demo
remains at `game/src/main.tscn` and is not used by the new game.

Runtime modules, all under `game/src`:
- `world/world_state.gd`: the canonical state object (RefCounted, owned by the map
  scene, no autoload). It owns day, fog, resources, encounters and these controllers:
  `party_state.gd`/`hero_state.gd` (three heroes), `campaign_state.gd` (acts II-VII
  and endings), `side_investigations.gd` (108 optional cases), `equipment_state.gd`
  (items, assemblies, soul consent), `ghost_state.gd` with `simultaneous_turn.gd`
  (knights and frozen daily orders).
- `economy/trade_state.gd` (supply market) and `economy/strategy_economy.gd`
  (buildings, recruitment, mines, artifact sales).
- `evidence/evidence_graph.gd`, `spanish/learner_profile.gd`, `spanish/curriculum.gd`.
- `dialogue/authored_dialogue.gd`, `dialogue/npc_grounding.gd`, `claude/claude_client.gd`.
- `combat/stack_battle.gd` and `stack_arena.gd`: seven-slot stack battles.
- `save/save_game.gd`: versioned JSON save (v12) with migration from v1.
- Panels (`*_panel.gd`, `evidence_notebook.gd`) are views; they call the controllers
  above and never hold canonical facts.
Sections below the authority boundary are a historical description of the first
prototype stages; STATE.md logs what was added afterwards.
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
`game/config/game.json` is the single runtime configuration, loaded by the Claude client.

## Authority boundary

WorldState owns canonical state. JSON content defines facts. Claude proposes
responses; deterministic validation precedes state changes. Upstream inventory
persistence is not the game's save system; `save/save_game.gd` is. Implementation order and gates are in MASTER_BUILD_SPEC.md.

## Prototype movement

`game/src/world/world_state.gd` owns day, hero cell, remaining movement, terrain and
weighted AStarGrid2D. It is RefCounted and independent of scene nodes. Moves validate
reachability and total cost before changing state; costs apply on entering a cell.
The one-hero end turn advances day and replenishes movement.
`world_map.gd` builds TileMapLayer, Sprite2D, camera and UI and routes mouse events to
this state. `game/content/world/prototype.json` authors the fixed terrain layout.
`game/tests/world_map_test.gd` tests state and actual viewport input dispatch.
Retained upstream autoloads are unchanged; the new scene activates its own camera.

## Fog and locations

WorldState stores fog separately from visuals. A second AStarGrid2D, known_grid,
contains discovered traversable cells; player moves/previews use discovered_only=true.
The full grid remains useful for deterministic terrain tests. Fog is updated along
successful routes; rejected movement does not reveal terrain. Rendering omits unknown
tiles, dims explored cells and draws only discovered POI markers.
Location records live in prototype.json. The map uses one modal for any reached
location, populated from its authored name and description. No gameplay effects or
quest transitions occur in the location handler. Authored dialogue is embedded below. The modal guards both world input and end-turn callbacks.

## Authored dialogue

`game/src/dialogue/authored_dialogue.gd` builds the conversation controls and selects
replies from `game/content/dialogue/authored.json`. It normalizes Spanish accents/case
and checks whole words/phrases in authored priority order. It does not assess meaning,
grammar or canonical knowledge. Unknown questions select the speaker's fallback.
The bounded per-location UI histories are transient and have no world-state authority.
`world_map.gd` opens this panel only inside a reached POI and preserves modal input guards.

## Claude transport boundary

`game/src/claude/claude_client.gd` owns HTTPRequest, bounded retries and schema validation.
It emits a validated proposal or an empty dictionary for authored fallback. Dialogue UI
captures the originating location before the asynchronous call and stores the eventual
reply only in that location's log. No canonical state object is supplied to the client.
The prompt carries NPC grounding, curriculum focus and at most three exchanges. A clue
proposal is accepted only after `npc_grounding.gd` and the evidence graph verify it;
attitude changes are rejected. Validated language evaluation is displayed and observed.
JSON schema validation cannot prove factual grounding of arbitrary NPC prose.

## Learner observations

WorldState now owns `game/src/spanish/learner_profile.gd`, a RefCounted data object.
Dialogue captures day/location before submission, revalidates proposals at completion,
and applies only validated language observations. NPC text never changes world facts.
Known grammar and verb labels update bounded metrics; repeated recent messages and
confidence below 0.7 are ignored. Context is copied into the same request. Feedback is
cached per location; authored fallback clears it. The current block is derived from
completed lessons in `curriculum.gd`; observed mastery never unlocks a block.
