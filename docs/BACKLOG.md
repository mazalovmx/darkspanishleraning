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
5. [ ] Innkeeper directions follow the actual map (wrong on the province).
6. [ ] If budget remains: "Nueva partida" control with confirmation (P2 below).
7. [ ] If budget remains: troop/supply transfer panel over the existing model.

Not attempted today: the P1 conversation work below. It is the largest gap and needs
its own multi-session plan and scenario-bible review per NPC.

## P1 - Spanish as the control surface (sections 1.2, 20, 21, 34, 39, 43)

- Conversable NPCs: 4 exist (innkeeper, Lucio, Gabriel, Leonor); the target is 30+.
  Add grounding, authored fallback and free-text dialogue for the bible principals
  first: Veyra, Beatriz Orma, Ysabel de la Sal, Simón Vale, Rodrigo Mendaña, Selmo
  Oribe, Esteban, and Inés/Elias as speakers. `save_game.gd` hard-codes the four ids.
- Acts II-VII are sentence-entry cards with one accepted sentence and a button that
  shows it. Give each task several accepted variants at minimum, and move the
  investigative ones to grounded conversation plus inspection as in Act I.
- The 108 optional cases reuse nine sentence templates; the per-quest
  `language.prompt/model_frame/independent_task/recall_task` fields are not read.
- Rejection messages for purchases print the full expected sentence; soul rituals
  return the retry text. Gated Spanish can be passed by copying.
- NPC memory (Epic 19): conversation count, discussed topics, revealed clues, lies
  told, relationship, bounded validated summary; persist them (section 33).
  `npc_attitude_delta` is currently forced to zero.
- Request context (section 17) lacks scene, relationship, focus_verbs, recent_errors
  and conversation_summary; recent dialogue is 3 exchanges instead of 4-6.
- Golden conversation tests (section 39): none of the required 30 exist.
- Transactional archetypes (Epic 13): only the merchant exists, at LOC11 only.
  Missing innkeeper/room, healer, stable master, guard, toll collector, food seller,
  smuggler, each in three difficulty versions; survival dialogues of section 30
  (water, room, road safety, stable, complaint, permission).
- Learner features: review of completed lessons, vocabulary practice, a progress
  screen, explanatory error tags in feedback (section 29), `mastery_after` in error
  memory (section 28). No placement; everyone starts at block 1.
- Claude client: no backoff, retries on 4xx, bare-JSON-only parsing; the scheduler
  cursor advances on failed/offline submissions; `difficulty_observation` is unused.
  The live smoke test has not been rerun since 2026-10-05 and predates the
  curriculum/grounding prompt context.

## P1 - Scenario coverage (bible sections 13, 17, 18, 26, 35, 36)

- Missing quests: SQ03, SQ04, SQ05, MQ10 and the Act VII political crisis.
- El Índice is not a queryable text interface (Act VI).
- Council: wrong classification is only retried, it does not affect endings; no
  military commander, Ysabel, Inés or Elias nodes.
- SQ01/SQ02/SQ06 have fixed outcomes instead of the bible's player options.
- Locations with no interaction beyond a description: LOC10, LOC17 entirely;
  LOC09, LOC12, LOC13, LOC14, LOC16, LOC18 have a campaign card only.
- Santa Lucerna sub-spaces and city-specific vocabulary sets are not represented.
- Lucio's `forbidden_research` secret needs flag `research_disclosed`, which nothing sets.
- Institutional speech acts (Epic 18): one hard-coded declaration; no general
  declaration record, authority/procedure model or world consequences.

## P2 - Strategic layer

- Troop/supply transfer between co-located heroes has a model and tests but no panel.
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
- Frozen-plan guard does not cover `party_state.transfer_*` (no caller yet).

## P2 - Release readiness (sections 33, 35, 42, Epic 14.3, Epic 20)

- No `export_presets.cfg`; no Windows build has been produced or run.
- No title screen, main menu, settings, quit, or new-game/reset; the save auto-loads
  and a finished game can only be restarted by deleting the file.
- No FPS measurement. `_refresh()` rewrites all 19,200 tiles per UI update and each
  autosave takes about half a second on the province.
- Upstream demo still shipped: `game/src/main.tscn`, `game/overworld`, `game/combat`,
  Dialogic, eight demo autoloads, demo README/CHANGELOG/icon. The standing
  "26 resources still in use" shutdown error comes from the unused Dialogic autoload.
- Art and audio (Epic 20) not started: placeholder squares, circles and letters; no
  movement animation; no sound in the new game.
- No project README; no CI. Screenshot paths in about 28 test lines are absolute.
- Autosave failure shows only a small label; save validation hard-codes key counts
  and the NPC whitelist, so adding state requires touching those lines.
- No off-machine backup: no git remote, single `implementation` branch.

## P3 - Measurement and playtest (section 43)

- Critical-path duration (4-5 h) and total content (8-10 h) have never been measured.
- No test walks the critical path by real map travel; campaign suites place heroes
  directly. Travel pacing (Mateo walking to Cárdena to unlock Inés) is unverified.
- Language-event cadence (section 31) is not measured.
- No human playtest of any kind is recorded.

## Decisions needed from the user

- Sections 49-50 of the master spec and the bible's expansion notes still say the
  side-case, equipment and ghost catalogs are authored only and must not replace the
  map/day loop. The runtime now does exactly that. Either update both spec copies to
  record the decision, or treat the expansion as out of sequence. Not edited here.
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
