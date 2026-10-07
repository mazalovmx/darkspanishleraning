# Backlog

Rewritten 2026-10-07 after a read-only audit of the repository against
MASTER_BUILD_SPEC.md and the scenario bible. Everything listed here is open work;
completed work is logged in STATE.md. Section numbers refer to the master spec.

## Current position

Gates A-H passed. Sequence steps 01-20 are implemented and their suites pass headless.
Gate I (full scenario content expansion) is open. Of the fifteen full-game criteria in
section 43, seven are met, three are partial and five are unmet or unmeasured.

## Session plan 2026-10-07

Small, verifiable tasks first; each ends with tests, a STATE.md entry and one commit.

1. [x] `tools/run-tests.ps1`: one command runs every non-live suite headless and
   prints a per-suite summary. Document it in TESTING.md.
2. [x] Finish the frozen-plan guard left uncommitted in five files: a rejected
   destination must not freeze the day; the map must say that orders are frozen.
3. [-] `campaign_state.language_ready`: dropped, not a defect. Lessons are strictly
   sequential, so "the last lesson with the tag was applied" already means every
   lesson with that tag was applied. No code change.
4. [x] Working-doc drift: STATE.md header and bootstrap leftovers, ARCHITECTURE.md,
   CLAUDE_PROMPTS.md, CONTENT_SCHEMA.md, EQUIPMENT_AND_GHOST_KNIGHTS.md header,
   TESTING.md suite list, `ghost_knights.json` status label.
5. [x] Innkeeper directions follow the actual map (wrong on the province).
6. [x] "Nueva partida" control with confirmation (P2 below).
7. [x] Troop/supply handover between co-located heroes (Tropas tab of the equipment panel).

Done: windowed review of the three UI changes (frozen-
orders status line, Nueva partida, Tropas tab), which were verified headless only.

P1 conversation work has started with eleven speakers. The remaining gap needs
its own multi-session plan and scenario-bible review per NPC.

## P1 - Spanish as the control surface (sections 1.2, 20, 21, 34, 39, 43)

- Conversable NPCs: 11 exist (innkeeper, Lucio, Gabriel, Leonor, Beatriz Orma,
  Bishop Veyra, Simón Vale, Rodrigo Mendaña, Selmo Oribe, Ysabel and Esteban);
  the target is 30+. The added speakers use bounded public knowledge and unlock no
  new clues. Ysabel and Esteban require their canonical campaign records. Still
  missing: Inés and Elias as speakers and the minor task speakers. To add one:
  an entry in `authored.json`, grounding facts and NPC record, a save whitelist id,
  and golden cases.
- Acts II-VII are sentence-entry cards. Each now accepts its model sentence or two
  authored paraphrases, but matching is still exact and a button shows the model.
  Move the investigative ones to grounded conversation plus inspection as in Act I.
- The 108 optional cases reuse nine sentence templates; the per-quest
  `language.prompt/model_frame/independent_task/recall_task` fields are not read.
- Rejection messages for purchases print the full expected sentence; soul rituals
  return the retry text. Gated Spanish can be passed by copying.
- NPC memory (Epic 19): conversation count, last day and discussed topics are stored
  per NPC, saved (v13), sent to Claude and shown as a return greeting. Still missing:
  lies told, relationship (`npc_attitude_delta` is forced to zero) and a bounded,
  validated conversation summary.
- Request context (section 17) lacks scene, relationship, focus_verbs, recent_errors
  and conversation_summary; recent dialogue is 3 exchanges instead of 4-6.
- Golden conversation tests (section 39): 52 data-driven cases exist in
  `game/tests/dialogue_golden.json`, run offline with a fake transport. They cover the
  deterministic boundary only. A live variant that sends the same player lines to the
  real model and checks recasts and non-invention is still missing (paid, opt-in).
- Transactional archetypes (Epic 13): only the merchant exists, at LOC11 only.
  Missing innkeeper/room, healer, stable master, guard, toll collector, food seller,
  smuggler, each in three difficulty versions; survival dialogues of section 30
  (water, room, road safety, stable, complaint, permission).
- Learner features: review of completed lessons, vocabulary practice, a progress
  screen, explanatory error tags in feedback (section 29), `mastery_after` in error
  memory (section 28). No placement; everyone starts at block 1.
- Claude client: bounded retry delay, non-retryable client errors, whole-response
  fenced JSON and failed/offline focus rollback are implemented. Still missing:
  use of `difficulty_observation` and complete input/cache/cost accounting. Current
  counters track answered envelopes and output tokens in memory only. The live
  smoke test has not been rerun since 2026-10-05 and predates the expanded context.

## P1 - Scenario coverage (bible sections 13, 17, 18, 26, 35, 36)

- Missing quests: SQ05, MQ10 and the Act VII political crisis. SQ03/SQ04 now have
  four optional sentence-entry tasks; they do not add an ending requirement.
- El Índice is not a queryable text interface (Act VI).
- Council: wrong classification is only retried, it does not affect endings; no
  military commander, Ysabel, Inés or Elias nodes.
- SQ01/SQ02/SQ06 have fixed outcomes instead of the bible's player options.
- Locations with no interaction beyond a description: LOC10 entirely;
  LOC09, LOC12, LOC14, LOC16, LOC17, LOC18 have campaign cards only.
- Santa Lucerna sub-spaces and city-specific vocabulary sets are not represented.
- Lucio's `forbidden_research` secret needs flag `research_disclosed`, which nothing sets.
- Institutional speech acts (Epic 18): one hard-coded declaration; no general
  declaration record, authority/procedure model or world consequences.

## P2 - Strategic layer

- Supplies and hero health have no effect on play.
- 90 `optional_treasure` equipment items have no source; no map pickups or guarded
  treasures (section 12).
- Owned mines cannot be contested (section 12).
- Hero-specific army archetypes (section 9) are absent; every town sells the same.
- Optional cases: 12 cross-branch links unused; 24 disclosure outcomes are recorded
  but set no flag and have no consequence; case results do not reach the notebook.
- Soul specials reduce counter evidence from two to one for every set; the authored
  per-set actions and durations are not implemented.
- Ghost activation takes the first three eligible ids, so NK07/NK08 may never appear.
- Balance: every battle, knight and equipment rule is `authored_unplaytested`;
  side-case enemy units have zero attack/defense modifiers; gold income looks high.

## P2 - Release readiness (sections 33, 35, 42, Epic 14.3, Epic 20)

- No `export_presets.cfg`; no Windows build has been produced or run.
- No title screen, main menu, settings or quit. (A confirmed "Nueva partida" control
  on the map now restarts the game and keeps the previous save as `.bak`.)
- No rendered FPS or weak-hardware acceptance measurement. Incremental terrain
  repaint and single-decode save validation are implemented; the headless benchmark
  measures logic timings only.
- Upstream demo still shipped: `game/src/main.tscn`, `game/overworld`, `game/combat`,
  Dialogic, eight demo autoloads, demo README/CHANGELOG/icon. The standing
  "26 resources still in use" shutdown error comes from the unused Dialogic autoload.
- Art and audio (Epic 20): CC0 tiles, structures, UI art, four music tracks and three
  shaders are in `game/assets/third_party/` but nothing uses them yet. To do: a
  TileSet for the nine terrain types from `kenney_medieval_rts/Tile`, structure
  sprites as location markers, unit sprites for heroes, music per location type with
  a volume setting, UI panels from `kenney_ui_rpg`; measure before enabling any
  full-screen shader (section 35). No movement animation; no sound effects wired.
- No project README; no CI. Screenshot paths in about 28 test lines are absolute.
- Autosave failure shows only a small label; save validation hard-codes key counts
  and the NPC whitelist, so adding state requires touching those lines.

## P3 - Measurement and playtest (section 43)

- Critical-path duration (4-5 h) and total content (8-10 h) have never been measured.
- No test walks the critical path by real map travel; campaign suites place heroes
  directly. Travel pacing (Mateo walking to Cárdena to unlock Inés) is unverified.
- Language-event cadence (section 31) is not measured.
- No human playtest of any kind is recorded.

## Decisions needed from the user

- (Resolved 2026-10-07: both spec and bible copies now record the expansion as
  integrated; the branch is pushed to the public GitHub repository named in STATE.md.)
- Section 13 says four stacks per side; section 12 says seven. Code follows seven.
- Section 33 names one save file; the province uses `user://province_savegame.json`
  next to the prototype's `user://savegame.json`.
- Spec repository layout (root `src/`, `content/`, `tests/`) versus actual `game/`.

## Standing rules

- Every purchase and most quests require active Spanish production; no click-only
  bypass; live API availability is never a progression gate (section 1.2).
- Follow the ordered curriculum of section 1.3; no untaught tense in gated tasks.
- Claude output never mutates canonical state without deterministic validation.
- Never record a check as passed unless it was run.
