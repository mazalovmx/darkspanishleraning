# Project state

Updated: 2026-10-07
Branch: implementation
Current state: Gates A-H passed; Gate I open. Mainline, economy, equipment, optional
cases and ghost knights run on the province map with save v13. Open work is listed in
BACKLOG.md. Sections below are a chronological log; early entries describe the state
at the time they were written and are superseded by later ones.

## Handoff for the next agent (written 2026-10-07)

Read this block, then BACKLOG.md, then only the STATE.md entries you need.

Where things are:
- Remote: https://github.com/mazalovmx/darkspanishleraning (public), branch
  `implementation`. Remote `main` holds only a LICENSE commit; do not rewrite it.
  The game is a personal, local-only game; the remote is a backup, not a release.
- `.git` belongs to another Windows user: run git as
  `git -c safe.directory=C:/dev/game ...`. Do not change global git config.
- Engine: `tools/local/godot/Godot_v4.6.2-stable_win64_console.exe` (ignored, local).
- Entry scene `game/src/world/province_map.tscn`; canonical state is
  `game/src/world/world_state.gd`. Module map: ARCHITECTURE.md, first section.

How to verify:
- `./tools/run-tests.ps1` runs all 45 non-live suites plus the save restart pair,
  headless, about 15 minutes; `-Filter <text>` runs a subset. Last full run:
  54,890 checks, all passed. A script error in a test makes Godot hang; the runner
  reports it as TIMEOUT, so read `tools/local/test-logs/<suite>.log`.
- Windowed checks need `--accessibility disabled` on this machine (AccessKit crash).
- Never run `claude_live_test` or `run-game.ps1 -LiveTest` without the user's
  consent: they make paid API calls. The live path was last exercised 2026-10-05.

Working rules that are easy to miss:
- One task, its tests, a STATE.md entry, one commit (COPILOT.md); then push.
- Both copies of each specification (root and docs/) must stay byte-identical.
- Save validation in `save/save_game.gd` hard-codes key counts per version and the
  four conversable NPC ids; any new persisted state needs a new save version there.
- Every map modal is listed by hand in several guards in `world_map.gd`
  (`_end_turn`, `_update_preview`, button handlers, `_can_restart`). A new panel
  must be added to each list.
- UI built in code inherits the demo theme: dialogs need explicit font sizes.
- Tests reach campaign and case states with fixtures (`complete_opening`, `learn`,
  `visit` in `tests/campaign_test.gd`), not by real travel.

Done on 2026-10-07 (details in the dated entries at the end of this file):
audit and backlog rewrite, test runner, frozen-plan guards, working docs and both
specifications aligned with the runtime, innkeeper directions, new-game control,
troop/supply handover tab, windowed review of those UI changes, two accepted
paraphrases per campaign task, basic NPC memory with save v13, 42 golden
conversation cases, three new conversable NPCs.

What to do next, in order (BACKLOG.md has the full list):
1. P1 conversation breadth: 13 NPCs are conversable (target 30+). Acts II-VII, the
   SQ quests and the 108 cases are still sentence-entry cards with exact matching;
   move the investigative ones to grounded conversation plus inspection as in Act I.
2. The rest of NPC memory (lies told, relationship, validated summary); a live,
   opt-in variant of the golden conversations. To add an offline golden case, append
   to `game/tests/dialogue_golden.json`; no code change is needed.
3. Missing scenario content: MQ10, the Act VII crisis, a real choice in SQ05.
4. Art pass: remaining map markers, battle arena, UI panels, sound effects, volume
   control (assets are in `game/assets/third_party/`).
5. Release basics: export preset, title/menu, removal of the unused demo and Dialogic.
Open user decisions are listed at the end of BACKLOG.md.

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
scene isolates these dependencies. (Bootstrap-time note; gameplay was added later.)

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
Claude transport and UI completion were verified against the live service once, on
2026-10-05, and not rerun since. Runtime config lives at game/config/game.json.

## Gates

Bootstrap startup accepted with the documented nonfatal shutdown limitations.
Gates A through H: passed (see the dated entries below). Gate I: not passed.

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

## NPC grounding and canonical verifier (step 09)

Added npc_grounding.json with separate public knowledge, beliefs, false beliefs,
secrets, lie policy and register for the two prototype NPCs. Lucio's secret follows
bible 13.1; he does not receive the true nature of El Índice. Undisclosed secret text
is not sent to Claude. Prototype innkeeper remains separate from protagonist Mateo.
Profiles deliberately add no unsupported rumors or lies.

NpcGrounding builds copied, bounded per-NPC context and checks clue existence, actual
NPC knowledge, exact prerequisite states, repeat reveals and locally recognized intent.
Model-supplied player_intent is not authority. Unknown IDs and public facts that are
not clues are rejected. Missing policies fail closed. Secrets require an explicit,
nonempty canonical release policy. UI checks before showing a proposal or updating
learner observations; rejection uses the originating NPC's authored fallback, including
late responses after moving to another NPC.

Runtime clue catalog is intentionally empty until sequence steps 11-12. Tests use
synthetic clue fixtures to exercise acceptance and denial without adding story evidence.
No clue, quest, inventory or relationship mutation exists in this task. The verifier
protects canonical state; it cannot prove arbitrary generated prose factually correct.
Intent recognition is a conservative authored-keyword baseline, not semantic analysis.

Executed: 54 grounding checks, 72 client, 27 Spanish feedback and 25 authored dialogue
checks, all zero failures/exit 0. Grounding integration runs the actual map/dialogue
scene with a fake transport; no live API call was made. Existing ObjectDB/26-resource
shutdown diagnostics persist. Gate E is green for the verifier; evidence display/unlock
still follow save/load in the explicit sequence. Next implementation: step 10 save/load.

## Equipment and ghost knights: requested authored scope

Added equipment.json: 30 equipment types, six rarity ranks, 150 ordinary item variants,
24 unique components and six soul assemblies (180 total item records). Recipes reserve
all component slots, preserve bonuses/instances, require hero-specific Spanish persuasion
and delayed recall. Reward overlays reference existing SX quests without replacing AX
evidence. Added ghost_knights.json: eight manifestations of the semiotic enemy, each
with a distinct targeting policy, story effect, appearance, counter and combat script.

Authored simultaneous-world-turn contract freezes AI orders before player commit and
resolves from a shared snapshot. Language practice does not tick hostile turns. Local
effects are bounded, traced, reversible and cannot erase owned equipment, evidence,
soul consent or main plot truth. Maximum three active knights and two interventions.
Both root specifications are synchronized with their docs copies.

Executed the smallest catalog test scene: 1,886 checks, zero failures, exit 0. Validates
slots/recipes, all item IDs/effects/tiers, SX reward references, curriculum conditions,
knight effects and counter links. Existing shutdown diagnostics persist. These are
content checks, not gameplay or balance tests. Catalogs remain authored_not_integrated.
Next implementation stays step 10 save/load; runtime expansion waits for its gates.

## Save/load (sequence step 10)

Implemented one versioned user://savegame.json slot for the current prototype. It stores
day, hero cell, remaining movement, explored cells and the complete implemented learner
profile: grammar/verb observations, important-error counts/dates/examples, vocabulary,
recent-message deduplication and successful NPC contexts. The current curriculum block
is restored without unlocking new material. Fog visibility and weighted known-path
grids are rebuilt from the snapshot; terrain and NPC definitions remain canonical content.

Map UI has Guardar/Cargar, startup resume, and autosave after completed dialogue,
returning from a location and ending the day. Save/load are blocked during an in-flight
response. Loading replaces state only after validation, rebinds dialogue to its learner
and clears transient conversation history/feedback. No raw Claude history, API key,
request payload or generated world facts are serialized. Evidence, inventory, other
heroes and NPC summaries do not exist in the new runtime yet and are not claimed saved.

Writes validate a full snapshot, stage/flush/re-read a same-directory .tmp file and use
Godot rename replacement without truncating the prior slot. Malformed/oversized files,
unknown versions/maps, bad cells, malformed mastery/error fields and out-of-range values
are rejected. Corruption keeps the running session intact and suspends autosave; explicit
UI confirmation is needed to overwrite an unreadable slot. No power-loss durability
claim is made. JSON uses full float precision; tests allow numerical drift <=1e-12 and
integer counters are reconstructed as integers.

Executed: 523 save/load assertions headless and with OpenGL, plus 365 map, 25 authored
dialogue, 72 client, 27 Spanish feedback and 54 grounding assertions, all passed.
A separate write process exited, then a fresh read process verified position/day and
Spanish Unicode/profile data: both PASS/exit 0. Rendered save/load HUD screenshot
inspected. Tests use isolated save paths or disable persistence, never the user slot.
No live API call was made. Existing ObjectDB/26-resource shutdown diagnostics persist.
Step 10 complete; next step 11 is evidence display, then step 12 verified clue unlock.
This does not unlock campaign/equipment/knight runtime expansion or claim Gate F passed.

## Evidence notebook (step 11)

Added the canonical travel-food observation from bible Act I. Physical inspection is
available only at Santa Lucerna. The notebook separates observation, attributed claim,
four interpretations, institutional status and absent causal proof. Recording requires
a typed, authored present-tense Spanish description plus correct classification as an
observation. Guided matching does not award free-language mastery, prove a cause, unlock
a curriculum block or complete the investigation. Wrong attempts are repeatable.

Cuaderno opens the journal from the map; Examinar pertenencias opens the guided inspection
in the monastery. Notebook blocks travel/end-day input, supports Escape and autosaves a
successful record. Save v2 persists evidence ID/day/classification/Spanish note, never
canonical evidence prose. V1 loads with an empty notebook and preserves existing progress.
Unknown IDs, forged causal classifications and malformed records are rejected.

Executed: 53 notebook checks headless and OpenGL, 524 save/load, 365 map and 25 authored
dialogue checks passed. Final notebook screenshot inspected; all five sections visible.
Existing ObjectDB/26-resource shutdown diagnostics persist. Step 11 complete. Next:
step 12, one clue unlocked through grounded dialogue; no full investigation/Gate F yet.

## Verified dialogue clue unlock (step 12)

Added monastery_claim, the community's suicide explanation communicated by Lucio, from
bible Act I. It is recorded as an attributed claim, not a proven cause. The food
observation must already be recorded. The player asks a supported present-tense Spanish
question; the UI supplies a scaffold after inspection. A keyword alone is insufficient.

Actual request context now includes derived evidence prerequisites and eligible clue IDs.
The response boundary checks syntax, NPC knowledge, current prerequisites, local intent,
the request-time eligible set and the authored Spanish question before allowing mutation.
EvidenceGraph rechecks canonical eligibility independently. Unknown IDs, physical-clue
proposals, wrong intent, missing prerequisites and repeats cannot grant evidence.
Critical disclosure text is authored; generated prose cannot redefine the evidence node.

The authored no-API path performs the same local checks. A malformed/rejected proposal
cannot fall through to this unlock path. Valid ordinary replies may also trigger the
authored disclosure for a fully eligible question, so model reluctance or API availability
does not gate progress. Offline matching never fabricates language evaluation/mastery.
Late replies retain their source NPC and request day, and autosave after completion.

Notebook now selects between both nodes. Save v2 restores both and validates that the
claim has its earlier food prerequisite with consistent dates. Executed: 39 dialogue
clue checks headless and OpenGL; 53 notebook, 54 grounding, 72 client, 27 Spanish,
25 authored dialogue, 524 save and 365 map checks passed. Fresh write/read processes
restored both clues, classifications and Spanish profile: PASS/exit 0. Screenshot
inspected. No live API call was made; fake transport covers the model-proposal path.
Existing ObjectDB/26-resource shutdown diagnostics persist.

Steps 11-12 complete. Next step 13: the first complete investigation (Epic 11); existing
two-node notebook is not that full investigation, and Gate F remains pending.

## Opening investigation: physical evidence and custody document (step 13, partial)

The notebook now exposes four further physical inspections after the initial food:
broken brass tube, blood inside the tower, scraped boot and absent notebook.
Each has its own present-tense Spanish model, vocabulary and accepted production.
The notebook's absence does not recover it or skip Inés's later plot.
The local custody order becomes inspectable after the abbot's attributed account.
It requires institutional-declaration classification, not observation or proven cause.

Inspection lists only prerequisite-eligible physical/document nodes at the monastery;
the ordinary journal lists recorded evidence only. Testimony is not inspectable.
Recording and v2 restoration enforce all authored prerequisites and chronological
ordering, preserving state on rejection. Existing v1/v2 save compatibility remains.
Guided matching does not award free-language mastery or advance the curriculum.

The content file also holds authored Gabriel/Leonor testimony for subsequent integration.
These four reserved nodes are not exposed by the current conversation runtime.
The first complete investigation, hypothesis correction and causal assessment remain
unfinished; no battle, merchant, full economy or Gate F completion is claimed.

The user's Heroes III economic requirement is synchronized in both master copies:
seven core resources pay for buildings, troop recruitment/upgrades, artifacts and
services; mines, daily income, stock checks, seven target army slots and compulsory
Spanish transactions are specified. Supplies remain additional consumables.
Both bible copies document the opening staging without changing the canonical culprit.

Validation actually run: 48 opening-inspection checks headless and OpenGL; 53 notebook,
39 dialogue-clue, 524 save/load, 365 map and 25 authored-dialogue checks headless.
All final runs passed (1,054 distinct assertions). The first new UI test failed because
its direct hero teleport left the monastery undiscovered; corrected the fixture to
travel through discovered cells and reran successfully. Rendered 1280x720 document
notebook inspected; subsequently changed its recorded-note label to "Tu anotación".
Root/docs specification hashes match; git diff --check passed. No live API calls.
Existing ObjectDB/26-resources shutdown diagnostics remain unresolved.
## Opening witnesses integrated (step 13, partial)

Gabriel and visiting Leonor now join Lucio in the monastery speaker selector; the innkeeper
is the fourth slice NPC. Each keeps separate transient history and late-response routing.
Gabriel's initial denial, horse observation with mistaken inference and wine secret follow
authored prerequisite questions. Leonor's clinical report needs tube, blood and boot.
The absent notebook remains absent. Author reliability labels never enter player output.
Critical disclosures remain authored and all unlocks use request-time and live verification.
Offline Spanish production follows the same path; it does not invent language mastery.
The save validator accepts successful language contexts from all four canonical NPCs.

Executed: 27 witness checks headless/OpenGL, 39 dialogue-clue, 54 grounding, 524 save,
25 authored dialogue, 27 Spanish feedback and 72 client checks: final runs passed.
Fixed two test-fixture errors (StringName key and config access before node readiness)
before final runs. No live API calls. Existing shutdown leak diagnostics persist.
Gate F remains pending: next implement comparison/conclusion, then battle and purchase.
## Hypothesis comparison and causal reconstruction

Notebook comparisons now require a selected hypothesis, two distinct canonical supports
and a present-tense Spanish conclusion. Wrong interpretations provide authored explanation
and allow correction. Food cannot prove suicide; honest horse testimony does not identify
a smuggler; Gabriel's unrelated lie cannot establish murder. Final reconstruction orders
the fatal blow before the fall and explicitly leaves visitor identity/motive unproven.
All six opening clues, custody order, clinical report and both comparisons are required.
Save v2 persists accepted reasoning records and checks prerequisite chronology on restore.
The assessment never awards free-language mastery from guided answers.

Executed 29 reasoning checks headless/OpenGL, 48 inspection, 53 notebook, 39 dialogue-clue
and 524 save checks: all final runs passed. Fixed an initial generated-script newline
error before these runs. Inspected the rendered assessment with all controls visible.
No live API calls; preexisting shutdown warnings persist.
Step 13's investigative portion works. Gate F remains pending until its battle/purchase
acceptance criteria are provided by the immediately following steps 14 and 15.
## Stack battle adapter (step 14, arena complete)

Added a seven-slot army combat adapter over retained Open RPG BattlerStats and an
inherited CombatArena scene. Aggregate HP determines living count; attacks scale with
count and attack/defense. Initiative orders rounds, melee retaliates once per round,
ranged attacks avoid retaliation, defense lasts until the next action, and each unit
type has one once-per-battle ability. Deterministic enemy targeting and seeded damage
support repeatable checks. Retreat, defeat and victory return survivor armies once.
Four authored unit types: militia, archers, bandits, spectral guard.

Executed 38 combat checks headless and OpenGL; all final checks passed. Fixed the
retaliation test to observe the same round rather than the next-round reset.
Reviewed the rendered arena. Existing shutdown warnings persist.
This commit provides the arena only; next connect map encounters, persistent losses,
rewards and save migration before claiming step 14 complete.
## Persistent map battle (step 14 complete)

The inn exposes a road-bandit encounter after the first clue. Starting spends two
movement points; battles block movement, day changes, notebook and save/load. Settlement
reads the canonical battle model rather than trusting UI result arguments. Survivors
persist, retreat/defeat consume remaining movement, victory grants 60 gold exactly once,
and completed encounters cannot be farmed. The initial army is eight militia/four archers.
Seven named resources now exist in state; only initial values and battle gold are active.
Buildings, mines, recruitment and resource purchases are still subsequent work.

Save v3 adds army/resources/encounter results, validates bounded quantities/types, and
migrates v1/v2 to starting strategic defaults without fabricated victories.
Executed 64 integration checks headless/OpenGL; 39 arena checks headless/OpenGL;
525 save, 365 map, 53 notebook, 29 reasoning and 27 witness checks passed.
Corrected the first arena preview's inherited large font and missing CanvasLayer;
added a viewport-bound check and inspected the corrected arena and actual map transition.
The earlier arena snapshot was visually unusable despite passing logical checks.
No paid calls. Existing shutdown warnings persist. Gate F awaits transactional purchase.
## Transactional merchant and recruitment (step 15)

The inn market sells bread, water, bandages, horse feed, lamp oil and militia recruits.
Every transaction requires a typed Spanish request, correct price statement and explicit
product/quantity/total confirmation. Canonical prices and stock are rechecked at commit;
gold, goods/army and stock change together. Cancellation, stale quotes, insufficient
funds and full army slots cannot charge. Recruiting merges matching stacks or fills a
free slot, including recovery from an empty defeated army. No click-only buying route.
The initial exercise is guided present-tense practice and does not fabricate mastery.

Save v4 stores inventory, stock and bounded validated Spanish receipts. V1-v3 migration
keeps previous state and adds empty trade defaults. Pending quotes are transient.
Purchases autosave; practice does not advance days. No Claude calls are needed.

Executed 43 market checks headless/OpenGL, 64 battle integration, 525 save, 53 notebook,
365 map and 29 reasoning checks: passed. Reviewed rendered market. Fresh write/read
processes preserved purchase/army/evidence/learner: PASS (after fixing test indentation).
Existing shutdown diagnostics persist. Full merchant archetypes and advanced variants
remain later curriculum/campaign work. Combined Gate F/G test is next; not yet marked.
## Combined vertical slice: Gates F and G passed

Executed vertical_slice_test.gd headless and OpenGL: 31 checks, zero failures, exit 0.
The test travels on discovered paths, talks to all four NPCs, buys supplies through
three typed Spanish stages, inspects all physical clues and the institutional document,
makes and corrects a wrong hypothesis, uncovers the lie/unrelated secret, gets the
medical report, saves/loads mid-case, compares testimony, reconstructs the cause,
returns to the inn, wins the actual encounter, and saves/loads the combined outcome.
Purchase costs, reward, survivor army, receipts, evidence and current language block
remain consistent. Claude outage is explicit for this test; live transport was verified
earlier at Gate C. This is automated integration coverage, not a human playtime study.

Gates A-G are now passed for the vertical slice. H/I and full-game completion remain
pending. Next: the ordered curriculum scheduler before adding the second/third heroes.
Known shutdown diagnostics remain. The full MVP checklist still needs more POIs and
other listed content; Gate F/G completion does not imply the entire game is finished.
## Ordered curriculum engine (step 16, integration pending)

Authored seven prerequisite blocks with 31 topics, each with a model, guided production,
two distinct transfer questions and delayed recall. Block advancement requires all topics
and recall on a later game day, across at least three contexts per block. Game-day spacing
is an engineering proxy, not a claim of real-world retention. The scheduler chooses
60% weak/review, 25% current and 15% stretch after consolidation, suppresses early stretch,
avoids recent focus repetition where possible, and never selects an untaught tense.
Three understood exchanges adjust one difficulty dimension; two comprehension failures
reduce pressure. Per-conversation adjustment is capped at 0.10.

Executed curriculum_test.gd: 890 checks, zero failures, exit 0, after correcting two
test type declarations. Covers every block, every intermediate restore, forged/skipped
prerequisites, delayed recall, grammar/verb coverage and scheduling/difficulty limits.
The engine and content are not yet wired into learner saves or gameplay UI.
Next task is that integration. Existing shutdown warnings persist.
## Curriculum in gameplay and save v5

The Español control opens the ordered course. It shows the model only for introduction/
guided production, changes prompts for two independent transfers and requires recall
on a later game day. Lessons autosave and never advance hostile turns. The learner's
current block is derived from canonical lesson records, not a writable difficulty label.
Completed lessons remain distinct from observed free-language mastery.

NPC prompts receive the actual curriculum, taught grammar, scheduled focus and bounded
difficulty dimensions. Repeated/uncertain dialogue cannot farm difficulty changes;
model tags for untaught tenses cannot award grammar observations. Added future_simple
as a separate grammar category rather than mislabelling it ir_a_future.

Save v5 validates course proofs and block consistency. V1-v4 migration initializes an
empty course and future_simple=0 while preserving previous observations and game state.
Executed: 22 curriculum integration checks headless and OpenGL; 890 course, 525 save,
43 market, 64 battle integration, 53 notebook, 27 Spanish feedback, 72 Claude client,
31 vertical-slice checks headless, all passed.
The first OpenGL attempt failed inside AccessKit Windows with resource-memory error.
No Godot processes were left running. Repeated the test with --accessibility disabled
for that test process only: 22/0 and OpenGL initialized; screenshot inspected.
The game's accessibility settings were not changed. Existing shutdown warnings persist.
Next apply transaction language tiers, then the three-hero milestones; full game pending.
## Transaction language follows the curriculum

Market and recruitment requests now progress through present requests, taught preterite,
ir-a plans and conditional/justified requests. The selected tier derives from taught
grammar, not hero level or model output. Every tier retains three typed stages, canonical
price/stock validation and atomic settlement. Earlier receipts remain valid; mixed
incompatible stage text is rejected on restore. No advance to an untaught tense.
Lesson context names are now player-facing Spanish rather than internal English keys.

Executed 38 market-curriculum checks headless/OpenGL and 43 base market checks, all passed.
The tier test completes actual prerequisite lessons, makes purchases at all four tiers,
restores their mixed history and checks the real shop prompt. OpenGL test used
--accessibility disabled after the earlier AccessKit failure; screenshot inspected.
Existing shutdown diagnostics remain. Step 16 complete; next implement three heroes.
## Three-hero state foundation (steps 17-18, map integration pending)

Added Mateo, Inés and Elias definitions and independent positions, movement, health,
armies and supply inventories. Shared strategic resources/evidence remain world-owned.
Party selection never refreshes movement. Co-located heroes can transfer troops/supplies;
stack merges, seven-slot limits and quantity conservation are validated.
Elias's small prototype escort uses two relic sentinels with the existing brace mechanic.
Snapshot validation rejects unknown/locked active heroes, bad positions and malformed
inventories/armies transactionally.

Executed 36 party-state and 39 combat regression checks, all passed; shutdown warnings
persist. This is the party model only. Next wire portraits/F1-F3, shared visibility,
per-hero trading/battles and save v6 before claiming Gate H.
## Three heroes integrated: Gate H passed

Portrait controls and F1/F2/F3 select Mateo, Ines and Elias without resetting movement.
Positions, armies and supplies are independent; resources, shop stock, evidence and the
ordered Spanish course are shared. Fog combines every unlocked hero's current vision.
Purchases and combat settle against the active hero. Switching is blocked during a
quote, battle, location interaction, course or other modal; HTTP responses cannot be
reassigned by switching. NPC requests include the selected hero's public role/register.

Save v6 validates and restores all three heroes and the active selection, checking its
compatibility aliases against the party. V1-v5 migrate to Mateo without losing prior
progress. Prototype staging remains a mechanical fixture, not early campaign arrivals.
The troop/supply transfer model is available; its player-facing panel remains pending.

Executed 46 party integration checks headless and OpenGL, 365 map, 526 save, 64 battle
integration, 43 market, 22 curriculum integration, 53 notebook and 31 vertical-slice
checks: all passed. Fixed a boolean misuse in the new test before running the suite.
Reviewed the rendered scene and tightened sidebar spacing to keep the legend on screen;
repeated 46 checks in both modes after that adjustment. OpenGL used accessibility
disabled for the test process only. Existing engine shutdown warnings remain.
Gate H passed for the three-hero development slice. Next step 19: full map; scenario
acts, strategic economy, artifact and ghost-knight runtime remain unfinished.
## Full province model (step 19, display integration next)

Added authored 160x120 terrain, eight regions, eighteen canonical-coordinate POIs,
thirteen named roads/branches and seven resource-site placements. The northern pass
uses verified opening reconstruction as its access condition; blocked pathfinding
cannot bypass the ridge. Resource sites are placements only, not income yet.
WorldState accepts either authored map. Campaign starts Mateo at Santa Lucerna;
Ines and Elias retain canonical future locations but remain locked and reveal no fog.

Save v6 now uses the actual map identity and map-specific bounds, preserving prototype
compatibility. Executed 38,753 province checks (including cell/region validation,
road connectivity, closed-pass isolation, discovered travel to Cardena across days,
and province save/restore), 526 save checks and 46 party scene checks: all passed.
Existing shutdown diagnostics remain. Root/working bible updated together for the
northern checkpoint. Next integrate campaign rendering/camera and launch scene.
## Province display and launch (step 19 complete)

The main scene now starts the province at Santa Lucerna. Its separate province save
preserves the existing prototype save; the original development scene remains available.
Camera bounds follow actual dimensions, portraits recenter the view, and locked heroes
cannot be selected. Only explored tiles are populated; fog drawing is limited to the
viewport rather than scanning 19,200 cells on every mouse update. Discovered resource
sites and the closed northern pass have map markers. Opening inspection, conversations
and the notebook work at the canonical coordinates.

Executed 17 province-scene checks headless/OpenGL, 365 map regression, 46 party
integration and 31 vertical-slice checks; headless main scene 60 frames: all passed.
The initial scene test asked the witness before the required physical clue; corrected
the test to inspect and classify the food through the UI first, then reran both modes.
Reviewed province screenshot. Existing shutdown diagnostics persist. This completes
the geographic/display stage, not the missing NPC/act/economy interactions.
Next step 20: remaining scenario acts and their deterministic progress gates.
## Remaining-acts model and authored tasks (step 20, interface pending)

Added 29 canonical mainline tasks from the episcopal order through the five council
claim categories. Separate causal chains preserve Roque/Tomas, Leon's accident,
Selmo/Gaspar, the Order/Beltran and Esteban's voluntary entry. Gabriel identifies the
visitor and reports what he witnessed; he is not fabricated as an eyewitness to the blow.
New supporting records/scenes are authored fiction consistent with the bible.
Formal classification, Spanish production, prerequisites and distinct supporting records
are deterministic. Hero introductions occur at Cardena and Monte Ciego; the crypt requires
all three at Santa Lucerna. No task advances on a click, wrong classification or an
unpracticed grammar form. Later tense use requires actual lesson transfer and earlier
block recall; chronological restore checks prevent backdating practice.

Save v7 persists the campaign ledger and checks hero unlock consistency. Older saves
retain empty campaign progress. Executed 328 campaign checks, 527 save, 46 party,
64 battle integration, 43 market, 22 curriculum integration, 53 notebook, 31 vertical
slice and 17 province scene checks: passed. Existing shutdown diagnostics persist.
This commit is model/content only. Campaign task UI, final decision derivation, optional
cases, economic runtime and full NPC conversation expansion are still pending.
## Mainline act journal connected

Expedientes opens the currently available tasks and previously recorded claims.
Future documents are withheld until prerequisites, language practice and location
requirements hold. Each task needs typed Spanish and a claim category; causal tasks
also require two distinct records chosen from the actual shared ledger. Optional
models never auto-fill the answer or award free-language mastery.
Introductions enable portraits immediately, and every completed task autosaves.
The panel blocks map/day/hero input and closes correctly on Escape or load.

Executed 285 campaign-panel checks headless and OpenGL, including every one of the 29
tasks through UI controls and its autosave, 365 map, 46 party and 31 vertical-slice
regressions: all passed. Screenshot reviewed; shutdown diagnostics remain.
The mainline is playable through council classifications. Final disposition and its
consequences are next; no claim of complete endings or a human playtime test yet.
## Council resolutions and four endings

The council now requires the five claim categories, supporting records and a typed
Spanish proposal acknowledging the chosen policy's limits. Destroy, preserve and open
have distinct provincial/character consequences; the Evidence Charter additionally
requires three optional investigations: disrupted grain supplies, ventilation with
working-hour safeguards and the capacitor/pilgrimage economy. Those cases each have
a source and a reviewed conclusion. Their records support the Charter; detailed
economic simulation of those local policies remains future work.

The ending is derived from the immutable recorded proposal, never a writable ending
label. Missing evidence/optional cases, backdated proofs or a replaced save sentence
cannot grant the Charter. Repeated submissions cannot change the council decision.
The ending screen leads with consequences and character outcomes, followed by the
actual declaration. This is an authored scenario ending, not proof of human playtime.

Executed 376 campaign checks, 182 ending-model checks, 322 expanded panel checks
headless and 323 OpenGL (including the ending display), 527 save checks. After moving
consequences to the top, executed the focused ending scene headless/OpenGL: 184 checks
each, passed; screenshot reviewed. Existing shutdown diagnostics remain.
The core mainline now reaches all four endings. Gate I expansion continues: the
108-case catalog, strategic economy, equipment/souls, ghost knights, wider live NPC
dialogue coverage and manual balance/playtime testing are still incomplete.
## Strategic economy model (integration next)

Added eight construction offers with real seven-resource costs, prerequisite buildings,
one construction per settlement/day, daily building income, weekly recruitment pools
and paid militia-to-veteran upgrades. Recruitment respects seven stack slots; upgrades
conserve troop counts and can reuse a vacated slot. Quotes use three typed Spanish
stages with curriculum-derived language tiers and recheck all resources before commit.
Mines require physical presence and a Spanish order; guarded sites require a recorded
victory. Income is idempotent within one world day. Restore validates buildings,
prerequisite chronology, receipts, recruitment counters and mine claims atomically.

Executed 50 economy-model, 39 stack-battle and 36 party-state checks: passed.
The guarded-mine victory in this isolated model test is an explicit fixture, not yet
a played mine encounter. Existing shutdown diagnostics persist.
Next connect world turns, guarded battles, save v8 and the construction/recruitment UI.
The artifact market building is authored; artifact sales await equipment integration.
## Economy connected to world turns, mine combat and save v8

World day changes now pay owned-mine and constructed-building income. Strategic quotes
lock hero changes and battle entry. Guarded mines use canonical site-specific battles
and actual surviving armies; winning clears guards, then a typed Spanish claim establishes
ownership. Mine victories cannot reuse the inn reward or be repeatedly farmed.
Save v8 validates the economic ledger against recorded mine victories and supports both
maps; older saves migrate with no invented buildings, mine ownership or retroactive income.

Executed 26 world-economy checks including an actual won mine battle and another mine's
retreat, 527 save, 43 market, 64 battle integration, 46 party integration and
22 curriculum integration checks: passed. Existing shutdown diagnostics persist.
The economic model is now world/save-connected; construction and mine interaction
controls are the next task, so the full player-facing loop is not yet claimed.
## Strategic economy interface connected

Settlements expose construction, weekly recruitment and troop upgrades. The panel shows
all seven resource balances, prerequisites, stock and full costs; a quote locks its
item/quantity until completion or cancellation. Every purchase uses typed request,
cost comprehension and confirmation. Reached resource sites expose their guards and
Spanish ownership order. After an actual mine fight the panel resumes at the claim
step; only the next world day grants income. Owned sites change marker color.
The sidebar now scrolls, keeping its expanded resource display and controls accessible.

Executed 20 economy-scene checks headless/OpenGL, including UI construction, recruitment,
cancelled quotes, a won mine fight, ownership autosave and the next day's income;
365 map, 64 battle integration, 46 party and 31 vertical-slice regressions: passed.
The first new UI test retained quantity four while typing a quantity-one request;
corrected that fixture and reran successfully. Screenshot reviewed. Existing shutdown
diagnostics remain. Artifact sales, equipment effects, optional case runtime and
simultaneous ghost-knight turns are still next; the artifact-market building alone
does not yet provide equipment sales.
## Strategic Spanish wording and curriculum validation

Construction requests now use the correct indefinite article, recruitment agrees in
number, upgrades name both the source soldier and resulting type, and costs explicitly
name coins/resource units. Confirmation wording follows the operation. Previously saved
economic receipts remain accepted as complete historical variants; new transactions
use the corrected forms.

Executed 55 economic-model checks (including historical receipt compatibility),
28 strategy-curriculum checks through actual prerequisite lessons and all four language
tiers, and 20 economy-scene checks: passed. Existing shutdown diagnostics persist.
## Equipment and soul model (world integration next)

Indexed all 180 catalog entries, thirty types and fourteen slots. Ordinary instances
and unique fragments have explicit owners and slots; backpack items grant no bonuses.
Assembly keeps the exact four component instances and their occupied slots, adds the
set bonus once within catalog caps, and reverses without losing parts or consent.
Co-located transfers preserve ownership correctly; a new wearer receives only component
bonuses until completing their own soul conversation. Specials have a per-set daily
use guard; their ghost-counter effects are not integrated yet.

Each of six souls has a staged authored offline conversation: listen, compare two
distinct memories, supported production, independent argument, answer an objection,
recall on a later day and accept the pact. Current grammar requires actual practice
and earlier block consolidation. Copying the supported line cannot satisfy the
independent prompt. Selected understood grammar-error variants pass with a correction;
no free-language mastery score is fabricated. Early fear wording follows taught forms.

Executed equipment-model checks: initial 474 passed; after adding memory-duplication
and corrective-feedback cases, 498 passed. Covers all six sets, both owners' separate
consents, reversibility, transfer, daily special limits and forged-save rejection.
Existing shutdown diagnostics persist. Acquisition verification belongs to the upcoming
purchase/quest callers; this model is not yet connected to world saves or battle stats.
## Equipment connected to battles, travel and save v9

Equipped owner bonuses now affect allied attack, defense, per-unit HP, initiative,
ranged damage, seeded luck and at most one morale extra action per stack/round.
Enhanced HP does not create soldiers. Movement bonuses apply on the next world day;
removal clamps remaining points and re-equipping cannot refill them. The map displays
the actual movement maximum. Combat and pending transactions lock equipment changes.
Save v9 retains item identities, component slots, assemblies and staged soul consent;
it rejects movement unsupported by currently worn items. V8 migrates with empty gear.

Executed 285 equipment integration checks, 39 stack-battle scene, 527 save/load,
26 economy-world, 64 battle integration, 46 party integration, 43 market,
22 curriculum integration and 365 map checks: passed. The first integration run
incorrectly tried to put a soul component over worn boots; corrected the test setup
and reran. Existing shutdown leak/resource diagnostics persist.
Acquisition and equipment controls remain the next task; knight-specific specials
and balance are not yet integrated or playtested.
## Artifact market purchases and save v10

The artifact-market building now sells sixty common/uncommon catalog variants across
all thirty equipment types. Each settlement has one copy of each offer. Requests,
full-price comprehension and confirmation use the current Spanish tier; only the final
validated stage deducts gold and creates an owned backpack instance. Quest components
and soul assemblies cannot be purchased. Funds/capacity are rechecked at confirmation.
A permanent sale ledger links stock to actual item identities even after transfer;
save v10 validates it and migrates earlier economic saves with an empty ledger.

Executed 19 artifact-market scene checks headless and OpenGL, 55 economy-model,
20 economy-scene, 527 save/load and 285 equipment-integration checks: passed.
Reviewed the market screenshot; switching offers now also clears stale feedback.
Existing shutdown diagnostics persist. Equipment controls are being connected next;
optional quest rewards and knight interventions remain incomplete.
## Equipment and soul interface connected

The map now opens an inventory with fourteen named slots, item effects, capped hero
bonuses and co-located transfers. Assembly, disassembly and whole-set transfer use
the same validated model. A separate soul tab shows component requirements and follows
all seven conversation stages; independent and recall answers are not displayed.
Later grammar prompts remain hidden until curriculum prerequisites are met. Missing
parts, occupied recipient slots and same-day recall block the relevant operations.
Typing blocks travel, hero changes and world turns; each accepted action autosaves.
Loading closes and rebinds the panel.

Executed 157 equipment-scene checks headless and OpenGL; after visual improvements,
157 OpenGL checks passed again. Also executed 365 map, 19 artifact-market and 46 party
integration checks: passed. Reviewed inventory and soul screenshots. The scene test
uses explicitly granted component fixtures; live quest acquisition remains next.
Existing shutdown diagnostics persist. No knight-counter special is exposed yet.
## Optional encounter combat definitions prepared

Added the four authored optional-investigation troop types using their existing HP,
damage and initiative values. Since that catalog has no attack/defense modifiers,
these start at zero modifiers rather than silently borrowing another unit's stats.
Temporary brace halves incoming damage until the next actor turn; feint bypasses
active defensive reductions once, and crossbow guards can use aimed shots. Existing
militia brace behavior is unchanged. Enemy choices use these abilities when applicable.

Executed 334 side-battle checks covering all 108 authored stack configurations,
retreat preservation, abilities and an expanded battle scene; 39 existing battle-scene
and 285 equipment-integration checks: passed. Existing shutdown diagnostics persist.
This validates battle execution, not encounter balance or availability on the map.
Quest custody, language stages and rewards still require their runtime controller.
## Optional investigation controller (world integration next)

All 108 cases now have a deterministic controller for location/prerequisite access,
peaceful custody or recorded victory, twelve access acrostics, physical inspection,
supported-versus-overreaching interpretations, written supported production, changed
sentence structure and recall on a later world day. Twelve final branch choices use
written conditional proposals. Current grammar practice and consolidation of earlier
blocks gate every case; battle victory cannot establish an interpretation.

Offline practice is bounded authored sentence work with the actual artifact names,
not unrestricted Spanish grading. It does not award fabricated free-language scores.
Twenty-four reward bindings grant unique components once, separately from evidence;
restore checks contiguous stages, chronology, prerequisite cases and reward identities.
Executed 1574 checks through all 108 cases and all component rewards: passed.
Existing shutdown diagnostics persist. This controller is not yet connected to world
saves or the investigation interface; its passing test is not a completed playthrough.
## Optional cases connected to world combat and save v11

The world now owns optional case progress and exposes all 108 encounter definitions.
Battle entry checks the same location, branch and curriculum conditions as peaceful
access. Settlement transfers actual survivors and grants no evidence or fragment by
victory alone. Retreat leaves negotiations available. Save v11 preserves partial case
stages, final choices, acrostics, custody and component identities; earlier saves migrate
without invented optional progress. Encounter chronology is validated against the
branch and language history. Recall accepts previously practised sentences as well
as the authored recall variant, so it does not require guessing an unseen sentence.

Executed 1575 full-catalog checks including a world-save round trip, 144 side-world
checks including an actual won battle and retreat, 334 side-battle scene, 527 save,
285 equipment integration, 43 market, 22 curriculum integration, 46 party integration,
26 economy-world and 19 artifact-market checks: passed. One initial test incorrectly
assumed the first grammar topic could not be practised on day one; replaced it with
an actual unmet branch-prerequisite check and reran. Existing shutdown diagnostics
persist. Player-facing optional case controls are the next integration step.
## All optional cases exposed on the map

Investigaciones locales lists prerequisite-ready cases at the hero's actual location.
The panel implements peaceful requests, the optional battle route, inspections,
supported/rejected comparisons, access acrostics, written grammar practice, changed
sentence frames, later-day recall and final publication/privacy choices. It shows
local consequences and separately awarded equipment components. Battle completion
returns to the custody step; every accepted investigation step autosaves. Modals block
travel and day changes, and loading rebinds the panel. Authored catalog status now
reflects runtime availability while retaining untested balance labels.

Executed a nine-case branch through actual interface controls: 215 checks headless
and 215 OpenGL, including a won battle, retries, an acrostic, later recall, rewards,
protected-copy outcome and autosaves. Reviewed both screenshots. Regressions: 365 map,
157 equipment-scene, 20 economy-scene and 31 vertical-slice checks passed. Catalog
validation: 5341 side and 1886 equipment/ghost checks passed. Existing shutdown
resource/leak diagnostics persist. All 108 controllers were separately checked, but
human playtime, combat balance, broader NPC dialogue and ghost turns remain unfinished.
## Distinct ghost-knight combat tactics prepared

The battle model accepts validated authored enemy scripts. All eight knight profiles
have their specified opening/second-round actions and target rules: weakest defense,
highest attack, fastest stack, lowest health, highest initiative, strongest ranged
threat, last attacker or highest expected damage. Last-attacker tracking uses actual
strikes. Spent or invalid abilities fall back to attack, and ordinary battle startup
clears a previous script. No script can write campaign or equipment state.

Executed 116 ghost-battle checks including all eight tactics and the arena scene,
39 standard battle, 334 optional battle and 285 equipment-integration checks: passed.
Existing shutdown diagnostics persist. This prepares their tactical behavior; knight
map spawning, frozen simultaneous strategic orders, bounded interventions and counters
are still not connected to live play.
## Frozen simultaneous route resolver prepared

Added a pure daily plan with a shared start snapshot, frozen knight orders and
replaceable player routes. Planning neither moves actors nor advances time. Routes
respect each actor's allowance, terrain costs, known player cells and current gates.
Resolution handles destination contacts, opposite edges, fixed knight initiative,
nonselected guarding participants and later arrivals at an existing collision. It
revalidates before producing a result and does not mutate the world while calculating.

Executed 33 resolver checks including JSON round trips, malformed-plan rejection,
route changes, terrain timing and collision cases; 365 map-scene checks passed.
The initial JSON test exposed int/float coordinate differences; normalized restored
coordinates and reran successfully. Existing shutdown diagnostics persist. This is a
prepared resolver, not yet the live map's travel loop; spawning, AI target policy,
interventions, strategic UI and world-save integration remain next.
## Ghost strategy and bounded interventions prepared

Added eight distinct target preferences, curriculum/branch-gated activation, a maximum
of three active profiles and frozen move/intervene/guard/recover orders. Perception
uses the current nearest discovered location and its two nearest discovered neighbors.
At most two interventions resolve per day and one effect per branch; effects expire
within one or two turns and repeated targets have a three-turn cooldown. More recently
served knights yield intervention priority to longer-waiting profiles, with fixed
initiative/ID ties, preventing one profile from permanently excluding another.

Effects gate only their designated optional-case stage. Typed Spanish counters cite
owned branch evidence; some require two distinct sources. Optional consenting soul
countermeasures still require Spanish and evidence. Counters may interrupt telegraphed
orders; defeats disperse a knight for three turns. Recovery actors do not block routes.
Owned evidence, equipment and mainline claims are not mutated by these effects.

Executed 1449 ghost-strategy checks covering all eight profiles, expiry, counters,
recovery and invariants; 33 route-resolver and 116 ghost-battle scene checks passed.
Initial checks found starvation on a shared target and a test that had already claimed
the escrow component; fixed arbitration and the unclaimed-component fixture, then
reran. Existing shutdown diagnostics persist. This is still a standalone controller;
world persistence, travel planning UI and live intervention/counter controls remain next.
## Ghost controller persistence validated

Ghost snapshots now retain actor birth/cooldown/recovery dates, active effects,
per-target cooldowns, bounded event history, frozen plans and interrupted orders.
Spanish counter events retain their hero, typed answer, distinct source evidence and
optional soul-use proof. Restore validates these against actual case inspections,
curriculum history, consent and special-use dates. Active recovery requires a recorded
victory. Removed effects cannot be resurrected by replaying an older intervention.

Executed 325 persistence checks including exact JSON reload/re-resolution, forged-state
rejection, a real tactical victory and a soul counter whose four parts were earned
through actual case stages. The first test stopped one prerequisite quest too early
for SP004; corrected it to the authored SX013 reward and reran. Also executed 1449
strategy and 116 ghost-battle scene checks: passed. Existing shutdown diagnostics
persist. The controller snapshot is ready; global save integration and replacement of
the province travel loop still remain, so live strategic opponents are not yet claimed.
## Province simultaneous turns and save v12

Province movement now queues a route against frozen knight orders; ending the day
applies hero and knight positions together, reveals the travelled route and advances
income once. Contacts retain their previous hero position, force the next encounter,
and block further travel until settlement. Retreat separates actors and consumes the
hero's movement; an unescorted hero yields automatically. Ghost battles use their
individual tactical scripts and victory disperses the opponent.

Save v12 restores the controller after case, curriculum and equipment proofs, including
queued routes and pending contacts. Earlier versions migrate with empty ghost state.
Executed 146 world integration, 38669 province map, 527 save, 325 ghost persistence,
144 side-world and 17 province-scene checks: passed. JSON comparisons normalize numeric
representations. Existing shutdown resource diagnostics persist. Map controls and
intervention counter UI remain the next integration step.
## Map presents planned travel and forced contacts

The province button now resolves orders, queued routes persist and are drawn in hero
colors, and an explicit cancel control removes the selected hero's route. Visible
non-dispersed knights have numbered map markers. End-turn and load reopen a pending
contact in the battle arena after saving the strategic state. Updated travel help.

Executed 147 ghost-world checks headless and OpenGL (screenshot reviewed), 365 map,
17 province scene and 43 market checks: passed. Regression testing had found that the
new quote guard changed prototype day advancement; scoped that guard to the province
and reran the market checks. Additional migration regressions passed: 19 artifact
market, 22 curriculum, 26 economy-world, 285 equipment, 46 party and 33 resolver checks.
Existing shutdown diagnostics persist. Spanish counter controls remain next.
## Spanish ghost-counter controls on the map

Caballeros y pruebas presents visible opponents and traces of active interventions,
freezes daily orders explicitly, offers inspected branch sources and guided Spanish
counterproduction, and allows the consenting soul route. Accepted counters autosave
their proofs. Nearby manual combat is available before orders are frozen. The modal
blocks overlapping panels and day changes and rebinds after loading.

Executed 152 scene checks headless and OpenGL, 147 ghost-world and 365 map checks:
passed. Reviewed the OpenGL screenshot. The initial scene fixture inherited an already
active effect instead of the intended fresh telegraphed order; isolated fresh opposition
while retaining real case/language progress and reran. Existing shutdown diagnostics
persist. The next task is enforcing live case-stage effects and frozen-plan action guards.
## Live interventions now gate optional investigation stages

Optional cases consult active ghost effects at their designated stage and explain how
to open Caballeros y pruebas or wait for expiry. Prepared strategic orders also block
case mutation. The nine-case interface test now handles actual interventions through
the counter panel at access, recall and final-choice boundaries. The 108-case catalog
test explicitly isolates its controller from live opposition before world-save validation.

Executed 219 complete branch UI checks, 1575 catalog-controller, 145 side-world,
1459 ghost-strategy and 331 ghost-persistence checks: passed. Initial branch runs
exposed the previously unhandled access and final-choice counter steps; the final run
passed all nine cases with actual counter controls. Shutdown diagnostics persist.## Audit, backlog rewrite and one-command test runner (2026-10-07)

A read-only audit compared the repository with the master spec and the bible.
BACKLOG.md was rewritten from its findings; it now lists only open work, ordered by
priority, plus decisions that need the user. The stale STATE.md header and bootstrap
leftovers above were corrected. No gameplay claim was changed by this entry.

Added tools/run-tests.ps1: runs every non-live suite headless, then the two-process
save restart check, and prints one line per suite. It clears the Anthropic key
variables for its own process and never runs claude_live_test.

Executed the runner on the working tree: 45 suites plus restart write/read, all
passed, 54,880 counted checks, exit 0. Not run: windowed/OpenGL variants, editor
import, live Claude test. Existing shutdown diagnostics persist in every log.
## Frozen-plan action guards completed

While the day's orders are frozen, building, recruitment, mine claims, supply trade,
campaign tasks, optional-case steps and equipment changes are rejected with a Spanish
explanation; a soul special used as a ghost counter is still allowed. A destination
the planner rejects (unknown, unreachable or too expensive) no longer leaves the day
frozen: the freshly created plan and any knight activation are rolled back. The map
status line now states that orders are frozen and what that blocks.

Deliberately unchanged: cancelling a queued route keeps the plan frozen, because the
knights' orders may already have been shown; releasing it would let the player react
to them with non-counter actions. Hero transfers of troops/supplies are not guarded
(no caller exists yet; see BACKLOG.md).

Executed in the full runner pass above: ghost_world_test 154 checks (six new),
ghost_state 1459, ghost_scene 155, ghost_persistence 331, plus every regression
suite: passed. The status wording was changed after that run and is not covered by
an assertion; no windowed run or screenshot review was done for it.
## Working documents brought in line with the runtime

ARCHITECTURE.md now names the real entry scene (province_map.tscn), the canonical
WorldState and its controllers; CLAUDE_PROMPTS.md describes the context actually
sent; CONTENT_SCHEMA.md and EQUIPMENT_AND_GHOST_KNIGHTS.md no longer call integrated
catalogs unintegrated; TESTING.md points to the later suites. ghost_knights.json
status changed from authored_not_integrated to runtime_integrated_unbalanced, and the
catalog test asserts the new label. The label is not read by gameplay code.

Not edited: both copies of MASTER_BUILD_SPEC.md and WORLD_AND_SCENARIO_BIBLE.md still
describe the expansion as authored only (sections 49-50 and the bible's expansion
notes). That is a specification decision listed for the user in BACKLOG.md.

Audit item reviewed and dropped: campaign_state.language_ready keeps only the last
lesson carrying a grammar tag. Because lessons are completed strictly in order, that
equals requiring every lesson with the tag, so there is no defect and no change.

Executed after the label change: equipment_ghost_catalog 1886, ghost_battle 116,
ghost_persistence 331, ghost_scene 155, ghost_state 1459, ghost_world 154: passed.
## Innkeeper directions match the province

The innkeeper's authored reply and grounding fact sent the player east, which is true
only on the 20x20 development map. On the province Santa Lucerna (52,39) lies north-
west of the inn (74,59): Camino de la Venta runs north to Camino del Este, which runs
west to the monastery. Both texts now say north, then west. On the development map
this wording is inaccurate; that map is a test fixture, not the shipped game.

Executed: authored_dialogue 25, dialogue_clue 39, npc_grounding 54, claude_client 72,
vertical_slice 31: passed. The bible was consulted only for the location table
(coordinates of LOC01 and LOC11), not reread in full for this one-line change.
## New game control

The map sidebar has "Nueva partida". It asks for confirmation, copies the current save
to `<save>.bak`, replaces the running state with a fresh one for the same map, rebinds
every panel and saves it. It is refused while a battle, a pending reply or any modal
panel is open. Loading and restarting now share one state-adoption routine.
There is still no title screen or menu; restoring the `.bak` file is manual.

Executed the full runner after the change: 45 suites plus restart write/read, all
passed, 54,884 counted checks (save_game_test 531, four new). The first run of the
new assertions failed on a wrong accessor in the test itself; corrected and reran.
Headless only: the dialog and the new sidebar button were not viewed in a window.
## Troop and supply handover between heroes

The equipment panel has a third tab, Tropas. It lists the active hero's stacks and held
supplies, limits the quantity to what is held and hands the chosen amount to the
recipient already selected at the top of the panel. It calls WorldState.transfer, which
refuses during frozen orders, a battle or a pending quote and then uses the existing
party model (same cell, seven-slot limit, stack merge, conservation). Accepted
handovers autosave through the panel's existing change signal. Handing over troops or
supplies between the player's own heroes is not a purchase and needs no Spanish.

Executed the full runner: 45 suites plus restart write/read, all passed, 54,890
counted checks (equipment_scene_test 162, five new; ghost_world_test 155, one new).
Headless only; the tab layout was not viewed in a window. Supplies still have no
gameplay effect, so moving them is currently bookkeeping.

## Session summary 2026-10-07

Six commits after c4321a0: backlog and test runner, frozen-plan guards, working-doc
alignment, innkeeper directions, new-game control, troop/supply handover. Open work
and user decisions are in BACKLOG.md. Next: windowed review of today's three UI
changes, then the P1 conversation work (more grounded NPCs, NPC memory, golden tests).
## Specifications record the integrated expansion (user decision 2026-10-07)

The user chose to update the specifications to the actual state. Sections 49 and 50 of
MASTER_BUILD_SPEC.md and the two expansion status notes in the scenario bible now say
that optional cases, equipment, soul assemblies, ghost knights and simultaneous
province turns are integrated, and list what is still not implemented. Root and docs
copies were patched identically and compare byte-for-byte equal. No other section was
changed; the four-versus-seven stack wording in section 13 is still open in BACKLOG.md.
Later the same day the user named a GitHub repository; the branch was pushed there.
## Windowed review of the three UI changes

Rendered the province map with OpenGL (Radeon Vega 8, accessibility disabled for the
process) and inspected three 1280x720 screenshots. Findings and fixes:
- The frozen-orders status line was clipped and widened the sidebar. Shortened to
  "Órdenes congeladas: / resuelve el día primero"; it now fits.
- Confirmation dialogs inherited the demo theme's oversized pixel font: the text was
  cut off and only one button was visible. Both dialogs (replace unreadable save, new
  game) now wrap their text, use a 24 px font and Sí/No buttons, and fit on screen.
- The Tropas tab renders correctly with stacks, supplies, quantity and the button.
Remaining observations, not changed: "Nueva partida" sits below the fold of the
scrolling sidebar; the recipient selector shows a locked hero by default.

Executed after the fixes: save_game 531, world_map 365, province_scene 17,
ghost_scene 155: passed. The review script was a throwaway outside the repository.
## Campaign tasks accept authored paraphrases

Each of the 35 act and optional-review tasks now has two `variants` in campaign.json:
paraphrases of the same claim in the same taught grammar, adding no fact (the full
bible was read before authoring them). The council resolution has none because its
four sentences select the ending. Matching is still exact after normalisation, so
this widens what is accepted from one sentence to three; it is not free-form
evaluation. "Ver un modelo" still shows the first sentence. Recorded variants pass
save validation because restore uses the same check.

Executed the full runner: 45 suites plus restart write/read, all passed, 54,996
counted checks (campaign_test 482: every task is completed through a paraphrase,
paraphrases are distinct from the model, and a paraphrase with an added claim is
refused). No Spanish speaker reviewed the paraphrases.
## Basic NPC memory and save v13 (Epic 19, partial)

WorldState keeps, for each conversable NPC, how many exchanges were completed, the
day of the last one and which locally recognised topics came up. It is updated only
after a completed turn, online or offline, from the locally derived intent; model
output cannot write it. The request context now carries `npc_memory` (count, last
day, topics and the clue ids this NPC already gave, derived from the evidence
graph), and the system prompt tells the model it may acknowledge a return visit but
must not invent what was said. Offline, each NPC has an authored `greeting_again`
shown when the player returns after the earlier transcript is gone (for example
after loading).

Save v13 stores the memory and validates NPC ids, bounded counts, days not in the
future and topics from the authored intent list; v1-v12 migrate with empty memory.
Not implemented from Epic 19: lies told, relationship values, a generated and
validated conversation summary. The memory does not change NPC behaviour offline
beyond the greeting.

Executed the full runner: 45 suites plus restart write/read, all passed, 55,010
counted checks (save_game 540, authored_dialogue 29, dialogue_clue 40). Nine
migration fixtures in other suites now drop the new key when imitating old saves.
No live API call was made, so the model's use of `npc_memory` is unverified.
## Golden conversations and a refused-proposal fix (section 39)

Added game/tests/dialogue_golden.json with 34 cases and dialogue_golden_test.gd,
which runs each through the production response parser, grounding verifier, learner
and dialogue panel with a fake transport. Cases cover clue unlocks and every refusal
path (missing prerequisite, invented or physical id, wrong NPC, wrong location,
model-claimed intent, keyword-only message, repeat), outage and malformed output,
correction display, mastery credit and its limits, and withheld secrets.

The suite found a defect: when a model proposal was refused, the fallback reply still
printed the clue's canonical text and said it "queda anotada", although nothing was
recorded. A refused proposal now gets the plain authored reply. Asking again about a
clue already recorded says it "ya consta en el cuaderno".

Executed the full runner: 46 suites plus restart write/read, all passed, 55,308
counted checks (dialogue_golden 298). These are offline boundary tests; they do not
evaluate real model prose, recasts or tone. That needs a paid, opt-in live variant.
## Three more conversable NPCs and Leonor at her hospital

Judge Beatriz Orma and Bishop Aureliano Veyra can be spoken to in Valdora (speaker
selector), Simón Vale at Taller Rojo, and Leonor Valera at the Hospital de Miralba in
addition to her monastery visit. Each has a grounding record, public facts taken from
bible sections 13 and 33, an authored greeting, return greeting, keyword replies and
fallback in present-tense Spanish, and uses the same free-text panel and Claude path
as the opening NPCs. They hold no clue: talking to them unlocks nothing, and the
campaign cards at those locations are unchanged. Four intents were added for topic
memory (declaration, stability, machine, illness), appended after the existing ones
so earlier keyword priorities are unchanged. A testimony clue is now only offered in
the conversation at its own location, so the monastery medical report is not recited
at the hospital. The save NPC whitelist has seven ids; no save version change.

Executed the full runner: 46 suites plus restart write/read, all passed, 55,396
counted checks (dialogue_golden 386 over 42 cases, including a generic check that
every conversation has grounding, a saveable id and offline replies). Rendered the
Valdora conversation with OpenGL at 1280x720 and inspected it: selector, transcript,
hint and input are readable. The other three were not viewed. No live API call; no
Spanish speaker reviewed the new lines.
## Four unmerged agent branches (2026-10-07, session ended at the usage limit)

Four parallel agents each finished and committed one task on its own local branch,
in worktrees under C:/dev/gwt/. None is merged into `implementation`, none is pushed,
and the full runner has NOT been run on any of them or on their combination. Each
agent ran only its own suites and reported them passing; the coordinator did not
review the diffs.
- wt/npcs 882d033: Mendaña, Selmo Oribe, Ysabel, Esteban conversable; `requires`
  field gates a conversation on a campaign record; 52 golden cases.
- wt/quests 9286f9d: SQ03 and SQ04 as four optional campaign nodes.
- wt/client efd9480: retry policy, fenced JSON, focus slot not consumed on failure,
  in-memory usage counter.
- wt/perf 352a12b: performance_test.gd, incremental tile repaint, single save
  validation.
Next agent: review each diff, merge into `implementation` one at a time (npcs and
client both touch authored_dialogue.gd), run `./tools/run-tests.ps1` on the result,
write the STATE.md entries and BACKLOG.md updates from the agents' reports in
the workflow journal or by reading the commits, push, then remove the worktrees with
`git worktree remove`. Do not treat these four tasks as verified until then.

## Four agent branches reviewed, merged and jointly verified (2026-10-07)

The initial push confirmed implementation matched origin. Three review agents and the
coordinator then inspected the four committed diffs. No blocking defect was found.
Merged sequentially without conflicts: wt/npcs 882d033, wt/quests 9286f9d,
wt/client efd9480 and wt/perf 352a12b. Both shared files (authored_dialogue.gd and
save_game.gd) merged cleanly; the full tests below ran on their combined result.
This completes the unmerged-branches handoff above.

- NPCs: eleven conversable characters, including Mendaña, Selmo Oribe, Ysabel and
  Esteban. Ysabel/Esteban require their canonical campaign records at open, speaker
  selection and submit. The save whitelist includes the four new identities. The
  authored conversations use bounded public facts and add no clue authority.
  Golden dialogue coverage is now 52 cases (502 assertions).
- Scenario: SQ03 El niño que confesó and SQ04 La carta verdadera are four optional
  tasks. Each accepts its model and two authored variants, while retaining source
  comparison and classification. They add no requirement to any ending, including
  the Charter. These remain sentence-entry tasks, not unrestricted conversation.
- Client: one retry after a 1.5-second delay for transient failures; permanent 4xx
  failures do not retry. Whole-response JSON fences are accepted with unchanged
  proposal schema checks. Failed, offline or rejected turns return their focus slot.
  Session counters record answered JSON envelopes and output tokens only; full cost
  accounting and live-model behavior remain unverified.
- Performance: terrain is painted only when exploration grows or state is replaced.
  Saves validate the parsed serialized payload once, verify temporary-file bytes and
  then replace the destination. Save format is unchanged. The benchmark checks these
  paths on all 19,200 discovered cells; it is not an FPS or weak-hardware acceptance
  test. This run measured worst unchanged refresh 0.233 ms, save write 278.283 ms,
  save read 228.593 ms and move/day resolution 1083.557 ms.

Executed ./tools/run-tests.ps1 on the merged implementation: 47 suites plus fresh-
process save write/read, 49 runs total, 55,739 counted checks, zero failures, exit 0.
Relevant suites: campaign 523, campaign panel 346, council endings 253, Claude client
147, golden dialogue 502, performance 19 and save/load 540. No paid/live request was
made. Existing ObjectDB/26-resource shutdown diagnostics persist; the runner does not
claim those are resolved. Updated BACKLOG.md and TESTING.md to reflect implemented
work and retain remaining limitations. The four worktrees were checked clean before
cleanup; retain their branch refs and merged history for traceability.## Third-party art, music and shaders downloaded (not yet used by the game)

At the user's request, CC0 material was added under `game/assets/third_party/` with
sources and authors in `game/CREDITS.md` and a usage note in the folder's README:
Kenney "Medieval RTS" default-size PNGs (126 tiles, structures, units, environment),
Kenney "UI Pack: RPG Extension" PNGs (87), three medieval tracks by RandomMind and a
dungeon ambience loop by JaggedStone (about 15 MB of audio), and three canvas shaders
from godotshaders.com (vignette, fog overlay adapted to Godot 4 syntax, parchment).
The licence shown on each source page was CC0 when accessed on 2026-10-07. The shader
texts were retrieved through a page-reading tool because the site refused direct
download; they were not diffed against the site byte for byte.

Nothing is wired into gameplay: the map still draws coloured squares and the new
game has no sound. `--headless --import` completed with exit 0 in a worktree and the
`.import` files are committed. A windowed script loaded every shader, the four audio
streams (lengths 94-139 s) and sprites from each folder without script or shader
errors; the shader output itself was off-screen in that capture and was not judged
visually. Executed afterwards on the main checkout: world_map 365, province_scene
17, dialogue_golden 502: passed. Three other agents were working in worktrees
(wt/next-context, wt/next-npcs, wt/next-quest) at the time; their work is not part
of this entry.
## Map art and music wired in (Epic 20, first step)

The map now bakes its nine terrain cells from the Kenney tiles at startup (grass,
sand road, dense forest, dirt field, stone mountain and ruins with rock overlays,
water, snow, tinted marsh) instead of flat colours; the tile atlas layout and atlas
coordinates are unchanged. Locations are drawn as a structure sprite chosen by their
`kind` (dimmed when only explored), and the active hero token is a unit sprite per
hero. Every use falls back to the earlier drawn placeholder if its file is missing.
A looping music player starts a travel track, switches to an inn, ruin/mine or town
track when a location opens and back when it closes. `game/config/game.json` has an
`audio` block (`music`, `music_db`); there is no in-game volume control. Other
heroes, mines, gates and knights are still drawn as shapes; battles and panels are
unchanged; the three shaders and the UI pack are still unused.

Rendered the province with OpenGL at 1280x720 and inspected two screenshots (start
view and a zoomed-out view with fields, forest, roads and four location sprites):
terrain, markers and hero draw correctly and music reported playing. Sound was not
listened to, and track changes were not exercised in that run. Executed the full
runner afterwards: 47 suites plus restart write/read, all passed, 55,739 counted
checks. No FPS measurement was taken with the new art.
## Three abandoned agent drafts reviewed, finished and merged (2026-10-07)

Three worktrees (wt/next-context, wt/next-npcs, wt/next-quest) held uncommitted work
from other agents, idle for about 45 minutes. At the user's request the drafts were
read first so nothing would be redone, then completed and merged. The code and
content in all three were already written and came with tests; what was missing was
verification, commits, the merge and this record. Nothing in them was rewritten.

What was done to finish them:
- Reverted `game/project.godot` in two worktrees: an editor import had dropped the
  Dialogic directory block there. That was a side effect, not part of either task.
- Committed each draft on its branch and merged the three into `implementation`
  (commits 6ea77e0, 9b3118c, ca98cb9). One add/add conflict on `save_game.gd.uid`
  (each worktree's import generated a different id) was resolved by keeping one.
  The merge also brought in the `.uid` files Godot generates for the new game's
  scripts; the repository already tracks such files for the upstream scripts.
- The quest worktree could not run its own tests (its import cache was broken, giving
  parse errors in upstream scripts), so that draft was verified only after the merge.
- Updated BACKLOG.md, CONTENT_SCHEMA.md and the handoff block above.

What the three changes are and why they exist:
1. Dialogue request context (master spec section 17; backlog P1). The model now
   receives `scene` (map, day, location id and name), up to three `focus_verbs` drawn
   only from verbs of the current and earlier course blocks and ranked by the
   learner's weakest scores and recorded errors, up to four `recent_errors` for taught
   tags with at most two stored examples each, and the last four exchanges instead of
   three. Why: the spec lists these fields, and without them the model could not aim
   practice at the learner's actual weak verbs or revisit real past mistakes.
   Selection never changes mastery or the curriculum; untaught tenses are excluded.
   Relationship and conversation summary are still not sent because that data does
   not exist.
2. Inés Vargas and Elias Venn as conversations (bible sections 12.2, 12.3; backlog P1
   "Inés and Elias as speakers"). They can be spoken to at Cárdena and Monte Ciego
   after `ines_arrival` / `elias_arrival`, through a new optional `companion_hero`
   gate: the companion must be unlocked, on the same cell and not the active hero.
   Why: the two protagonists had no voice at all outside task cards; the gate keeps
   a hero from interviewing themself and from speaking before being introduced. Their
   grounding holds only identity and what their introduction tasks already record
   (Inés's commission and who paid, Elias's origin as his own unverified account and
   his observable objects); neither reveals later-act facts or unlocks evidence.
   Conversable NPCs: 13.
3. SQ05 "La máquina de Simón" (bible section 18; backlog "Missing quests"). Three
   optional campaign tasks: observe that the engine works (Taller Rojo), report the
   three incompatible requests of workers, owner and the Order (Ferraza, Inés), and
   infer the trade-off in the conditional with both as sources (Elias, block 6). Why:
   it was one of three bible side quests with no content. No ending requires it. It
   stops at recording the conflict: the bible's destroy / scale / ban decision and
   any consequence are not implemented, so "there is no clean choice" is stated, not
   played.

Executed the full runner on the merged branch: 49 suites plus restart write/read
(51 runs), all passed, 56,128 counted checks; dialogue_context 23, dialogue_golden
628 over 62 cases, simon_quest 190, campaign 553, council_endings 256. Headless only.
No live API call was made, so how the real model uses the new context fields and
voices Inés and Elias is unverified; no Spanish speaker reviewed the new lines.
## Map art step two, interface sounds and the first frame-rate measurement

Resource sites are drawn with a sprite per resource (owned ones get a frame), ghost
knights with a tinted armoured figure and their number, and the non-active heroes
with their unit sprites. Interface sounds from the existing `game/assets/sfx` play
when a route is queued or refused, when the day resolves or is refused, and on
entering and leaving a location. The vignette shader can be enabled with
`effects.vignette` in game.json; it is off by default. Gates are still a drawn line.
province_scene_test now asserts that every location kind, resource and hero has a
sprite, that terrain cells are baked from distinct art, that music changes on entering
and leaving a location, and that the shader is off by default (50 checks).

First windowed frame-rate measurement (throwaway script, Radeon Vega 8, 1280x720,
vsync off, whole province explored, camera zoomed out, hero selected): 81 fps idle
and 36 fps while the pointer moves every frame; with the vignette 72 and 30. The
30 fps floor of section 35 therefore holds in this worst case only without the
shader, and with little margin while the pointer moves. This is one run on the
development machine, not a weak-hardware acceptance test. The moving-pointer cost
comes from recomputing the route preview and redrawing fog for every visible cell
on each motion event.

Executed the full runner: 49 suites plus restart write/read, all passed, 56,161
counted checks. Inspected one screenshot with the vignette on. Sounds were not
listened to.
## Fog drawn from a tile layer; frame rate re-measured

The moving-pointer cost found in the first frame-rate measurement is removed. Explored
but unseen cells are now dimmed by a second TileMapLayer that is painted together with
the terrain; on each refresh only the cells around unlocked heroes are cleared and the
previously clear ones re-dimmed. Unknown cells carry no tile and show the clear colour
(set to the former fog colour), so `_draw` no longer loops over every visible cell.
The route preview is recomputed only when the hovered cell changes.

Same throwaway windowed script as before (Radeon Vega 8, 1280x720, vsync off, whole
province explored, zoomed out, hero selected): idle 81 -> 259 fps, pointer moving
36 -> 268 fps; with the vignette 72 -> 189 and 30 -> 151. One run each on the
development machine; still not a weak-hardware acceptance test. A screenshot of the
start area and a zoomed-out view looks the same as before the change.
province_scene_test now also asserts that exactly the visible cells are clear and
that unknown cells carry no fog tile (52 checks).

Executed the full runner: 49 suites plus restart write/read, all passed, 56,163
counted checks.
## Portraits, parchment document panels, more music; licence notice; player level

Assets from the Godot Asset Store, checked on 2026-10-07 (the awesome-godot list has
no art assets, only tools and a link to godotshaders.com):
- Claw & Blade by SPIRIT CLAW: 16 character portraits, used on the hero buttons and
  beside the transcript for all 13 conversable NPCs. Its licence allows use in games
  but not redistribution as an asset pack, so only the files the game uses are in the
  repository, renamed, with the licence text and a note. The user chose to keep them
  in the public repository and to state the licence there.
- Pixel UI Fantasy Free by heyheythere (CC BY 4.0): the parchment art. A small helper,
  `game/src/common/parchment_theme.gd`, gives the evidence notebook and the case
  journal a paper page with dark ink, framed buttons and fields. Other panels are
  unchanged.
- RPG Town and Safezone Pack by Talon Trueblood (CC BY 4.0): five tracks, played in
  the monastery, archive, hospital and university, workshop and industrial city,
  and towns, customs and farm.
A root LICENSE file now carries the project's MIT text followed by a section listing
the third-party material and its licences; `game/CREDITS.md` has the credit lines.

Player level (user, 2026-10-07): the player is about B1 but rusty on grammar. Both
specification copies (section 1.3) and BACKLOG.md now say that the ordered blocks stay
as a refresher, task content must suit B1 from the first block, and each grammar
point carries a short rule reminder. The lessons themselves are not rewritten yet.

Verification at the time of this commit: rendered and inspected at 1280x720 the
monastery conversation with the abbot's portrait, the notebook and the journal. Three
defects seen in the first render were fixed and re-inspected (stretched paper
texture, oversized controls pushing the notebook off-screen, unreadable field text).
The hero-button portraits and the other 12 NPC portraits were not inspected; the
audio was not listened to. The full runner was still in progress when this was
committed at the user's request: 14 of 51 runs had passed, none had failed. Its
final result is recorded in the next entry.
## Result of the interrupted run, and lessons rewritten for a B1 player

The full run that was still in progress at the previous commit finished with two
failures out of 51, so commit e3f4c9f was pushed with a failing suite:
- province_scene_test: a stale assertion of mine. It expected the old town track at
  the monastery after the monastery had been given its own track. The test now reads
  the expected track from the location-music table and checks every listed file
  exists (64 checks).
- performance_test: "move + end of day" worst case 2.29 s against a 2.0 s budget
  while windowed review scripts were running at the same time. Rerun alone on an idle
  machine it passed (average 0.51 s, worst 0.84 s). No code change; do not run other
  Godot processes during the runner.

Lessons (user requirement of 2026-10-07, master spec 1.3): all 31 lessons and their 93
exercises were rewritten. Block order, lesson ids, grammar tags, contexts and target
verbs are unchanged. Each lesson now has a fuller rule with the irregular forms it
needs, a full-sentence model from the game's world, and exercises that ask for a full
sentence. Where two natural versions exist (comma, word order, gender) both are
accepted. 39 prompts that literally contained their answer ("Di que Gabriel oía…")
became cue prompts the player must conjugate ("Cuenta una costumbre pasada: Gabriel /
oír campanas cada noche / desde la bodega"). The rule is shown at introduction, during
guided practice, as "Recuerda:" during the two independent applications, and after
an error; delayed recall stays unaided. Lesson sentences avoid plot solutions.

Not changed: answers are still matched exactly against the authored variants, recall
is still gated on a later game day for every lesson, and the campaign, market, case
and soul sentences were not reviewed against the B1 requirement.

curriculum_test now asserts for every lesson a rule of at least 60 characters, a
model of at least five words, exercise answers of at least four words that differ
from the model, and that neither rule nor prompt contains any accepted answer (1,128
checks). curriculum_integration_test reads the first lesson from data and checks the
reminder during independent practice and that copying the model fails (25 checks).

Executed the full runner on an idle machine: 49 suites plus restart write/read, all
passed, 56,416 counted checks. Rendered and inspected the lesson screen in the
independent stage with an error shown: prompt, reminder and feedback fit. The Spanish
was written by the agent and not reviewed by a Spanish speaker.

## Inn market: cue and rule reminder instead of a model sentence to copy

Backlog P1 "gated Spanish can be passed by copying", first slice: the LOC11 market
(`economy/trade_state.gd`, `economy/market_panel.gd`). The panel no longer shows
"Modelo: <sentence>". It shows the facts to express (product with quantity, total in
coins) and a rule reminder for the current tier and stage. A sentence is accepted when
it equals the old model or, in the player's own word order, contains one accepted verb
form for the tier (for example quiero / necesito; decidí; voy a; querría / me gustaría),
any required word (si for the hypothesis, porque for the argued confirmation), the
quantity with the product (digits or number words up to veinte, un / una by gender)
and, where needed, the total in coins. A rejection names what is missing and repeats
the rule reminder; it never prints the model or the correct total. Old receipts still
validate because the model sentences satisfy the same check. Limitation: this is a
content check, not a grammar parser; a list of the right words in a strange order is
accepted. Strategy orders, soul rituals, optional cases, campaign cards and notebook
conclusions still show their model (BACKLOG.md).

Tests: market_test gained 10 checks (own wording with number words, rejections name
the gap without the model or total, gendered "one", panel shows cue and reminder);
market_curriculum_test's two prompt checks now look for the tier reminder and the
absence of the model. Executed on Linux with Godot 4.6.2 headless: market_test 53/0,
market_curriculum_test 38/0, party_integration_test 46/0, vertical_slice_test 31/0,
save_game_test 540/0, save_restart write/read PASS. The full non-live run was still in
progress at this commit; its result is recorded in the next entry. Not rendered in a
window; the Spanish of the reminders was written by the agent and is not reviewed.

Full run for the commit above (Linux, Godot 4.6.2 headless, a bash equivalent of
`run-tests.ps1` because PowerShell is not installed in that environment): 49 suites,
all exit 0 with `failures: 0` and no script error. The save restart pair passed
separately.

## Town orders and mine claims: cue and rule reminder instead of a model

Second slice of "gated Spanish can be passed by copying": `economy/strategy_economy.gd`
and `economy/strategy_panel.gd`. Building, recruitment, upgrade and artifact orders
show the order and its full cost plus the tier's rule reminder (the market reminders
are reused). Accepted: the model, the legacy model, or the player's own wording with a
tier verb form, the required word (si / porque in the argument tier), the ordered thing
(building or artifact name; quantity with the troop noun) and, for price and
confirmation, every resource amount followed within two words by its unit (monedas /
oro, gemas, or the resource name). A rejection names what is missing and repeats the
reminder. Mine claims need a tier verb form, "mina" and the resource; the panel names
what is missing instead of a generic retry. Saved receipts and mine records validate
with the same check, so old saves still load. Same limitation as the market: content
check, not a grammar parser.

Tests: strategy_economy_test gained 7 checks (own construction request, partial cost
rejected without the model, own cost sentence with number words, confirmation without
cost rejected, cue without model, claim missing its resource, claim in own words that
then survives the save round trip). Results are in the next entry.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Soul rituals: free answers checked against authored keys

The independent stages of a soul conversation (independent argument, answer to the
objection, delayed recall) accepted only one exact authored sentence, plus one
near-miss for the objection, which the player never sees, so they could only be passed
by guessing. `content/spanish/soul_rituals.json` now gives each set, for every stage
except listening (keys in code) and consent (still exact), a list of needs: a label and
the whole-word forms that satisfy it, for example for SA01's independent argument
"protejo", the witness, and a second present-tense action. An answer passes when it is
the model, a near-miss alternative, or meets every need. A near-miss still gets
"Se entiende. Forma sugerida: …"; an own answer that meets the needs gets no
correction. A rejection keeps the soul's retry line and adds "Tu frase necesita: …" with
the missing labels, never the answer. The keys are authored so that the supported
frame does not pass the independent argument and the soul's false reason does not pass
the objection; a remembered supported frame may pass the delayed recall, which is the
point of that stage. Listen, compare and supported stages still show their model, as
the curriculum's introduction and supported practice require. Saved ritual answers
validate through the same check. Limitation: a list of the right words is accepted
regardless of grammar; the near-miss alternatives in the data are deliberate errors.

Tests: equipment_state_test checks for all six sets that every model meets its own
keys, that the copied supported frame is rejected with a "Tu frase necesita" hint that
does not contain the answer, that the false reason is rejected, and that an own SA01
independent argument is accepted without correction (584 checks). The keys and labels
were written by the agent and are not reviewed by a Spanish speaker. Results in the
next entry.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Campaign cards: free conclusions checked against authored keys

`content/scenario/campaign.json` gives the 42 free campaign conclusions (all but the
council resolution) authored keys in the soul-ritual format. `campaign_state.missing`
accepts an answer or variant as before, otherwise requires every need, one sentence, at
most eight words more than the longest authored version, and the polarity of the first
answer (skipped where the variants mix negated and affirmative forms). A failed
language check now returns "Tu frase necesita: …" with the missing labels; wrong
classification or supports keep the generic retry message so the category cannot be
found by elimination from the feedback. The journal button "Ver un modelo" became
"¿Qué debe decir?" and lists the needs. Labels describe a role or a form, never the
answer. Saved records validate through the same check, so old saves still load.
`curriculum.words()` is the shared tokenizer for this check.

Limitations: content check, not a parser; a sentence with the right words and a wrong
relation between them can pass. The keys and labels were written by the agent, not
reviewed by a Spanish speaker. "golpeó" was deliberately left out of the verbs for
"quién mató a Tomás".

Tests: campaign_test checks that every free node has keys and every answer and
variant meets them alone, that a missing need is named without the answer, that a
reversed claim, a dropped negation and a second sentence are rejected, and completes
tomas_cause and confession_review with own wording (726 checks). campaign_panel_test
checks that the hint names needs and never the model (363 checks). Results in the next
entry.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## User requirement: conversations first; tildes count only in the last block

User clarification (2026-10-07), recorded in both specification copies (section 1.3,
"Conversation and orthography") and BACKLOG.md: add as many Claude conversations as
possible so that the game is not reduced to choosing the right answer; ignore errors
in tildes, ü and apostrophes in every block except the last; keep evaluating grammar
and naturalness.

Implemented in this commit:
- `Curriculum.fold()` (static) lower-cases and drops tildes, ü and apostrophes. The
  curriculum, market, strategy, soul ritual and evidence-note checks use it, so ü and
  apostrophes are now ignored too (tildes already were).
- `Curriculum.orthography_errors(message, authored)` names each typed word that
  differs from an authored word only by those marks ("querria → querría"); words absent
  from the authored sentences are not judged. It applies at submission time to tasks of
  the last block: its lessons, the argument tier of the market, town orders and mine
  claims, campaign nodes with min_block 6 and the SA06 soul ritual. Save restore stays
  lenient so existing saves load.
- Conversations: the learner context carries `orthography: ignore|check`; the system
  prompt tells Claude to ignore those marks when "ignore" and to judge naturalness. As a
  deterministic guard, before the last block any returned correction whose original and
  better text differ only by those marks is dropped before it reaches mastery or the
  feedback panel.

Not done: more conversations (the main part of the requirement; P1 in BACKLOG.md), and
a grammar check for gated free answers that works without the API; the key checks of
the previous commits accept agreement and word-order errors.

Tests: curriculum_test (fold, named tilde errors, forms authored both ways, unknown
words, last-block detection), market_curriculum_test (a missing tilde passes in the
past tier and is named in the argument tier), a golden conversation case in which a
tilde-only correction leaves feedback and mastery unchanged; that case fails without the
filter (checked by running it against the previous authored_dialogue.gd). Results in the
next entry. The live prompt change has not been exercised against the real API.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Seventeen named task speakers become conversable (30 NPCs)

User request (2026-10-07): as many Claude conversations as possible, and fictional names
for the speakers that had only a role. The 17 campaign speakers without a conversation
received names, recorded in both bible copies as section 13.11 (Fermín Cuesta, Clara
Ibarra, Nicolás Ferrer, Julián Pardo, Remedios Galán, Marta Ugarte, Baltasar Quiroga,
Catalina Rius, Damián Soler, Pilar Montoya, Águeda Llorente, Anselmo Vidal, Hernando
Ruiz, Tobías Marín, Lorenzo Villar, Gonzalo Ferrán, Hermano Cipriano). The campaign cards
show the new names as speaker.

Each has an `authored.json` entry (greeting, return greeting, hint, keyword replies for
offline play, fallback), an NPC record and facts in `npc_grounding.json` taken only from
the source text of their campaign card, no secrets, `can_lie: false`, and a save
whitelist id. Quiroga holds the council's claim "Todas las muertes tienen el mismo
autor" as a belief, not a fact; Llorente believes the object is sacred; Vidal believes
the confession proves guilt. Each appears only once the prerequisite of their card is
recorded: `requires` now accepts a list (Clara Ibarra needs leon_cause and gaspar_cause)
and "e:<id>" evidence (Fermín Cuesta needs the opening conclusion). Opening a place
whose own speaker is absent, or that has none (Archivo, Puente Seco, San Vélaro…), now
opens the first speaker present instead of nothing.

Tests: dialogue_golden_test checks for every new speaker grounding, save id, offline
replies, absence before each requirement and presence after all of them; 20 new
golden cases (an offline keyword answer per speaker, and three boundary cases showing
that a minor speaker cannot hand out the monastery claim): 83 cases, 940 checks. The
replies were written by the agent and are not reviewed by a Spanish speaker; no live
model call was made.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Optional cases: free answers and their own prompts

The 108 optional cases (`world/side_investigations.gd`, `world/side_panel.gd`) no longer
show their model before access, independent production or the final proposal. Access
asks for an inspection of the named piece and accepts a request verb, an examining verb
and the piece (its name, "pieza", "prueba" or "objeto"). Independent production and
recall show the case's own `language.independent_task` / `recall_task` (until now
unread) plus its `model_frame` as a frame with gaps. A free answer passes with the
template's target form (`side_practice.json` gains `keys`; tenses are recognised by
regular expressions over endings and frequent irregular forms, so a tense written
without its tilde and identical to another form, such as "examino", is not recognised),
at least four words, one word of five letters or more from this case, and, at the
independent stage, no sentence of three words or more that the panel showed. The
final proposal needs a conditional and the chosen outcome. The authored sentences
still pass, so old saves restore. Rejections name what is missing; block-7 cases
apply the last-block tilde rule.

Tests: side_investigations_test adds an own-words access and independent answer for
SX001, rejects a copied on-screen sentence, a missing target form and an irrelevant
answer, and for SX009 a proposal without its tilde and one without a conditional
(1,581 checks). The patterns and labels were written by the agent.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Claude review of accepted campaign conclusions (feedback only)

Toward the user's "grammar and naturalness are checked": the key checks accept
agreement and word-order errors, so an accepted campaign conclusion is now sent, when
the API is configured, to a review prompt (`claude_client.gd`: `REVIEW_PROMPT`,
`request_review`, `reviewed` signal, `parse_review`, `valid_language` shared with the NPC
schema, `review_text`). The journal appends "Revisión de español: Mejor: … → …" under
its feedback; outside the last block tilde/ü/apostrophe-only corrections are dropped.
The review changes no record and no mastery and never gates progress; offline it emits
an empty result at once. The journal owns a separate client instance, so a review does
not lock the map the way a conversation does.

Tests: claude_client_test (valid and invalid reviews, a full proposal is not a review,
own prompt and signal, offline path, tilde filtering; 156 checks), campaign_panel_test
(the review line is appended, tilde-only notes dropped, record unchanged; 365 checks).
Not exercised against the real API: the live smoke test needs the user's consent.

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Lucio's forbidden-research secret becomes reachable

The secret `forbidden_research` required the flag `research_disclosed`, which nothing
set. `npc_grounding.json` now has `campaign_flags` ({"research_disclosed":
"ysabel_account"}): once Ysabel's account is recorded, the step before Lucio agrees to
open the crypt (archive_meeting), the flag reads "confirmed". `npc_grounding.gd` gains
`campaign_flags(records)`; `authored_dialogue.gd` merges these with the evidence flags
everywhere it builds context. Authored branches accept an optional `requires_flag`, so
Lucio's offline reply about the hidden research exists only after that point (bible
13.1: he knows of the research, not the nature of El Índice; the reply says so).

Tests: npc_grounding_test (flag derivation, secret released only with it; 56 checks),
two golden cases before and after the account (85 cases, 958 checks).

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.

## Ghost knights: activation follows the player's latest cases (NK07/NK08 reachable)

`ghost_state._activate` took the first three eligible knights in ID order every day,
so with NK01-NK03 eligible, NK07 (branches SB11/SB12) and NK08 never appeared. Now the
three places go first to knights holding a live intervention (so it can still be
countered), then to the knights of the branches in which the player advanced a case
most recently (`_activity`, latest progress day), then to a knight already on the map,
then ID order. Defeat semantics are unchanged: a beaten knight stays on the map and
recovers. Save format is unchanged.

Tests: ghost_state_test adds a rotation scenario with every branch open: equal
activity gives NK01-NK03 and keeps them; advancing SB11 and SB03 brings NK07 and NK08;
a knight with a live intervention keeps its place (1,588 checks).

Executed for this commit: the full non-live run, 49 suites, all exit 0 with
`failures: 0` and no script error; save restart write/read PASS. Not rendered in a window.
