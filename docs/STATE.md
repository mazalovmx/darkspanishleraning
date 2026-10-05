# Project state

Updated: 2026-10-05
Branch: implementation
Current task: 108 side quests and battle encounters authored and validated; integration gated.
Next task: NPC grounding and deterministic canonical verifier (sequence step 09 / Epic 6).

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
Claude transport and actual UI completion have now been verified against the live service. Learner model,
canonical GameState, evidence and JSON save/load are not implemented. Runtime config
now lives at game/config/game.json and is loaded by the client.

## Gates

Bootstrap startup accepted with the documented nonfatal shutdown limitations.
Gates A through D: passed. Gates E through I: not passed.
Epics 2 and 4 are complete. Do not claim Claude dialogue or language evaluation yet.

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
whole-route affordability required (no partial movement). Fog and POIs were added in Epic 2 below.

## Epic 2: fog and POIs

- WorldState owns UNKNOWN/EXPLORED/VISIBLE fog with a circular radius of 5 cells,
  without line-of-sight simulation. Each traversed cell reveals its surroundings;
  only the final hero radius remains visible. Exploration persists through turns.
- Unknown terrain is absent from TileMapLayer and painted opaque; explored terrain
  is dimmed. Player previews and moves use a separate AStarGrid2D containing only
  discovered traversable cells, so unknown routes and terrain costs cannot leak.
  The original full-terrain grid remains available for rule-level regression tests.
- JSON contains LOC11 Venta del Perro Negro and LOC01 Santa Lucerna with canonical
  names/IDs from the scenario bible. Positions [6,11] and [12,10] are prototype-only,
  not replacements for full-map coordinates or the campaign's monastery start.
- Discovered POIs show markers. Arrival opens a shared Spanish description window;
  revisiting the current cell reopens it without spending points. Close button and
  Escape restore controls. Modal blocks movement, camera input and end turn.
- No dialogue, purchases, clues, NPCs or quest transitions have been implemented.

Validation: 365 assertions passed headless and with OpenGL (exit 0), including the
existing movement regression suite, circular visibility, intermediate route reveal,
exploration retention, exclusion of every unknown cell from player navigation,
failed POI movement, actual close-button mouse input, Escape, reopening and modal
input isolation. Rendered map and monastery-window screenshots inspected at 1280x720.
Editor import also completed with exit 0 and no script/import errors.
The known ObjectDB/26-resources shutdown diagnostics persist. Manual playtesting and
FPS benchmarking remain unperformed. Gate B is not marked passed.

## Authored dialogue / Gate B

The reached POI window now contains a Spanish free-text field, Enter/Enviar submission,
a plain-text scrollable log and a compact feedback area. JSON defines greetings,
whole-word/phrase topics and a fallback for each speaker: the unnamed prototype innkeeper
and Abad Lucio Salcedo. Lucio's replies use only public background. Inn directions refer
to the prototype layout. No clue, transaction, quest or relationship is changed.
Logs are independent by location, retain twelve exchanges, survive close/reopen in the
current map instance, and are not saved to disk. Messages are limited to 300 characters.
Unknown questions receive authored fallback, not inferred facts. Keyword selection is
not semantic understanding or Spanish evaluation; the feedback explicitly says evaluation
is unavailable. Escape closes even while the input owns keyboard focus.

Validation: 25 dialogue assertions passed headless and with OpenGL; 365 map/fog/POI
regression assertions passed headless. Spanish accented characters were entered through
viewport key events and submitted with Enter. Verified bounded history, per-NPC isolation,
blank rejection, fallback, literal markup, reopening and no movement/day mutations.
Rendered 1280x720 dialogue screenshot inspected; editor import exited 0 with no script/import errors. Existing ObjectDB/26-resource shutdown
diagnostics remain. No human playtest, live API call or language scoring is claimed.

## User clarification: intensive Spanish practice

Every purchase and most quests must involve active Spanish production and meaningful,
intensive language practice; this is core gameplay, not optional decoration. Persisted
in both synchronized MASTER_BUILD_SPEC.md copies, section 1.2. Apply it when implementing
evaluation, transactions and quests, while keeping feedback concise, narrative contextual,
and offline progression possible. The current static conversation is only the foundation.

## Claude client / Gate C pending

HTTPRequest now sends one Messages request per player turn, with at most one retry
on transport, HTTP or validation failure. Timeout: 20 seconds per attempt. Response
size is bounded to 64 KiB; redirects are disabled; request headers, keys and raw bodies
are never logged or persisted. ANTHROPIC_API_KEY is read only from the environment.
Missing key or explicit offline mode returns authored dialogue without a request.
Pending submissions are locked; closing/reopening or changing POIs cannot misattribute
a late reply. Successful validated NPC text is displayed as plain text. Language data
is validated but not yet displayed/scored; that belongs to Gate D.

Validation rejects malformed/truncated envelopes, invalid nested fields/types/ranges,
oversized text, more than two corrections, and all non-null unlock/nonzero attitude
proposals until deterministic grounding/relationship systems exist. This is schema
validation, not proof of factual truth in model prose. Canonical state is untouched.
Prompt knowledge is limited to the existing authored NPC fixture and last three
exchanges, with present-tense/basic-request language constraints for the initial block.

Configuration moved from config/game.json to game/config/game.json so there is one
Godot-loadable source. Model default updated to claude-sonnet-5-5 after checking official
Anthropic model docs on 2026-10-05; both master specifications updated identically.
Offline mode defaults false, but no key still means immediate authored fallback.

Checks: 72 client assertions passed using a fake transport (no paid requests), including
strict parsing, retries, timeout/completion simulation, no-key/offline behavior and late
reply UI handling. 25 authored dialogue assertions passed headless; 365 map/POI assertions
passed headless. Authored dialogue also passed all 25 checks with OpenGL; editor import
exited 0 without script/import errors. Live HTTP/TLS/model access has NOT been tested: ANTHROPIC_API_KEY was
absent. Gate C stays pending, and later gates remain locked. Existing shutdown diagnostics
persist. See TESTING.md for local runs and how to perform the remaining live check.

## User clarification: sequential language curriculum

Both master specifications now define ordered prerequisite blocks: present foundations;
transactions/questions; preterite; imperfect and contrast; connected accounts; plans and
experience; conditions and argument. Each follows model -> supported production ->
independent use -> delayed recall, with repeated success across contexts before advancing.
No random jumps to untaught tenses. Reviews use taught material; stretch is restricted
to the nearest next block and may be reduced during consolidation. Story tasks must be
scaffolded to learner prerequisites. This is a design requirement, not an implemented
mastery scheduler. Implement and test thresholds at the learner/scheduler stages.

## Live Claude verification (2026-10-05)

User supplied a local .env containing ANTHROPIC_KEY. tools/run-game.ps1 reads only the
recognized Anthropic variables and maps the alias to the client's ANTHROPIC_API_KEY
in the child process environment. It restores the launching process environment after
exit; .env remains ignored, unchanged and untracked. No credential was printed.
The launcher also supports ANTHROPIC_API_KEY (preferred if both names exist).

Ran tools/run-game.ps1 -LiveTest: HTTP 200, HTTPRequest result 0, one attempt, exit 0.
The real map scene reached the inn, submitted a short Spanish question through its
dialogue panel, received a schema-valid proposal and verified that the actual reply
was appended to the correct UI conversation rather than authored fallback. Gate C
is now green. This supersedes the earlier pending notes; it is one live smoke test,
not a language-quality benchmark. Existing shutdown leak diagnostics persist.

game/tests/claude_live_test.gd is opt-in (--live); ordinary local suites make no paid
calls. Next: display validated Spanish feedback and implement learner updates without
randomly jumping ahead of the current curriculum block.

## Spanish evaluation / Gate D

The dialogue now displays understood/unclear meaning and at most two compact corrections,
separate from the NPC reply. Low-confidence evaluation is explicitly uncertain; offline
fallback clears stale feedback without changing progress. Feedback survives reopening
and stays with its original NPC when a response arrives late. Prompt requests natural
recasts and the UI preserves NPC text. Current present/basic-request objective is visible.

WorldState owns a RefCounted learner profile (transient until save/load). All 19 grammar
and 25 irregular-verb categories start at zero observed mastery, not a placement score.
Only known tags update metrics. Successful understood usage adds 0.05 once per tag;
errors subtract 0.08 and override conflicting success. Values clamp to [0,1]. Confidence
below 0.7 and duplicates among the last 40 normalized messages do not update observations.
Important errors keep count, last-seen day and up to three examples. Vocabulary caps at
100 entries. Distinct successful NPC contexts are recorded. These are initial engineering
heuristics, not calibrated educational scores. No score unlocks a new curriculum block.

The existing response schema carries irregular verbs using verb:<infinitive> tags.
Error type can combine grammar and verb with | (e.g. present|verb:tener); success tags
remain separate array entries. Unknown labels cannot create new mastery categories.
Profile/context is passed in the same dialogue call; no extra evaluation API call.

Checks: 27 learner/UI assertions passed headless and with OpenGL. Existing 72 client,
25 authored dialogue and 365 map assertions passed. Editor import exit 0, no script/import
errors. Rendered feedback screenshot inspected. Live test returned HTTP 200 on one
attempt for an intentional tener error and verified both visible correction and reduced
verb mastery from a test-only baseline of 0.5. Gate D is green for this initial loop;
this is not a language-quality benchmark or a complete teaching scheduler. Existing
ObjectDB/26-resource shutdown diagnostics persist. Save/load remains unimplemented.

## Side investigations: authored expansion, not runtime integration

User requested more than 100 side quests and battles with parallel scholarly mysteries.
Added 108 quests, 108 artifacts and 108 encounter configurations in 12 original cases,
with 108 evidence-inference puzzles plus 12 acrostics, 24 local disclosure outcomes and
12 optional cross-case links. Full authored Spanish prompts and seven ordered learning
blocks accompany the quests. Original main scenario and six SQ quests remain intact.
Index: SIDE_INVESTIGATIONS.md; source: game/content/scenario/side_investigations.json.

The catalog is not loaded by gameplay. Integration remains locked until Gate I and
save/load, stack battles and curriculum prerequisites are implemented. No battle balance
or complete campaign playthrough is claimed. All purchases remain subject to the
existing mandatory Spanish requirement; this change adds no transaction runtime.

Executed the dedicated Godot test scene: 5,341 checks, zero failures, exit 0. Covers
referential integrity, prerequisites/reachability, curriculum order, evidence/answer
coherence, acrostics, stacks and peaceful/retreat paths. Existing shutdown diagnostics
persist. This task changes authored content and its validator, not gameplay systems.
Gate D remains the latest passed gate; next implementation is grounding/verifier.
