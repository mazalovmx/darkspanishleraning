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

- User requirement 2026-10-07 (master spec 1.3, "Conversation and orthography"):
  as many Claude conversations as possible, so play is typing Spanish to characters
  and never choosing an answer; tildes, ü and apostrophes are ignored except in the
  last block; grammar and naturalness are evaluated at every level. Done: the
  orthography rule in every gated check and in conversation feedback, naturalness in
  the Claude prompt. Gated sentence tasks now take free wording checked by authored
  keys, but keys check content and target forms, not full grammar: agreement and word
  order errors pass. Open: route more gated tasks through conversation (see the next
  items), and a grammar check for gated free answers that does not depend on the API.
  With the API, accepted campaign conclusions get a Claude review (feedback only);
  market, strategy, soul and side-case answers do not yet.

- Player level (user, 2026-10-07; master spec 1.3): the player is B1 but rusty on
  grammar. The 31 lessons are rewritten at that level with rule reminders. Still to
  do: review the campaign, market, strategy, optional-case and soul sentences against
  the same requirement; let the early blocks be consolidated faster than one game
  day per recall; have a Spanish speaker check the lesson texts.
- Conversable NPCs: 33 speakers exist (31 people, El Índice and the relay of LOC18): the 13 principal ones (innkeeper, Lucio, Gabriel,
  Leonor, Beatriz Orma, Bishop Veyra, Simón Vale, Rodrigo Mendaña, Selmo Oribe, Ysabel,
  Esteban, Inés and Elias) and the 17 named task speakers of bible 13.11. All but the
  four opening NPCs speak from bounded public knowledge and unlock no clue. Speakers
  with "requires" (one id or a list; "e:<id>" for evidence) appear only after those
  records. Inés and Elias must stand on the same cell at Cárdena / Monte Ciego and
  cannot be the active hero. Still missing: any conversation with a companion away
  from the place of introduction; a conversation changing a campaign card's outcome
  (the cards are still written separately after talking). To add one: an entry in
  `authored.json`, grounding facts and NPC record, a save whitelist id, and golden
  cases.
- Acts II-VII are sentence-entry cards. Each accepts its model, two authored
  paraphrases or the player's own sentence that meets the card's authored keys; the
  hint button names the needs instead of showing the model. The council resolution
  is still an exact choice among the proposals shown. Move the investigative cards to
  grounded conversation plus inspection as in Act I.
- The 108 optional cases still check grammar through nine templates (one target form
  each); their per-quest `independent_task`, `recall_task` and `model_frame` are now
  shown.
- Copying the model: the inn market (LOC11) no longer shows or prints its model
  sentence; it shows the facts to express and a rule reminder, accepts the player's
  own wording when the tier's verb form and the required content are present, and a
  rejection names the missing element. Town building/recruit/upgrade/artifact orders
  and mine claims (strategy panel) now work the same way. Soul rituals accept free
  answers against authored keys and name the missing need; their listen, compare and
  supported stages still show a model by design (introduction and supported practice).
  The 108 optional cases now read their own `language.independent_task` and
  `recall_task`, accept free answers (target form by template, a content word of the
  case, no sentence shown on screen copied whole) and name what is missing. Still
  showing a "Modelo:": the Act I evidence-notebook notes (the opening is the block-1
  introduction, where the curriculum shows a model) and the supported stages.
- NPC memory (Epic 19): conversation count, last day and discussed topics are stored
  per NPC, saved (v13), sent to Claude and shown as a return greeting. Still missing:
  lies told, relationship (`npc_attitude_delta` is forced to zero) and a bounded,
  validated conversation summary.
- Request context (section 17): scene, focus verbs, recent errors and the last four
  exchanges are now sent. Still not sent, because the data does not exist:
  relationship and conversation_summary.
- Golden conversation tests (section 39): 62 data-driven cases exist in
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

- MQ10 and the Act VII crisis (bible 35) exist: three crisis cards (convoy reported,
  workshop occupation observed, forged purge order inferred) and the decision on the
  bishop's emergency powers, whose grant is an institutional act that closes the
  Charter and adds an epilogue to every ending. SQ03, SQ04 and SQ05 are
  optional sentence-entry tasks (four, four and three nodes); none is required for an
  ending. SQ05 ends in a destroy/scale/ban decision with consequences.
- El Índice is a conversable machine in the crypt (after archive_meeting): crisis
  patterns for printing, machines and medicine; "REGISTROS INSUFICIENTES" for an
  ordinary day. Its answers do not yet feed the index_crisis/ordinary_tuesday cards.
- Council: a wrong classification is recorded and closes the Charter. Ysabel, Inés
  and Elias have council statements; the commander speaks through council_unknown.
- SQ01 (threaten/bargain/investigate), SQ02 (approve/keep the ban) and SQ06
  (destroy/explain/leave the cult) are decisions; harsh options close the matching
  review and with it the Charter, and every choice adds an ending epilogue.
- LOC10 Marjal Negro has a conversable bandit chief and the guarded caches. LOC18
  Torre del Relé has a talking relay (after Elias arrives) besides Elias's card.
- Santa Lucerna sub-spaces and city-specific vocabulary sets are not represented.
- Lucio's `forbidden_research` secret needs flag `research_disclosed`, which nothing sets.
- Institutional speech acts (Epic 18): authorities, procedures and acts are data
  (`institutions.json`); acts of recorded nodes and chosen outcomes are in force and
  listed in the journal; effects are flags. Still few acts use it (see MQ10 below).

## P2 - Strategic layer

- Supplies and health act on the province map: bread and water on the road, rest,
  bandages, horse feed, weakness below half health. Lamp oil still has no effect.
- Map treasures exist (`treasures.json`): 30 caches hold the 90 optional_treasure
  items; six bandit-guarded caches of relics stand in the Marjal Negro ruins.
- Owned mines are contested: raiders every seventh day after the claim stop the
  income until a victory. Ghost knights do not attack mines.
- Hero-specific troops exist (novices, hospitallers, inquisitorial guard for Mateo;
  thieves, knife fighters, crossbow mercenaries for Inés; relay automatons for
  Elias). Towns differ (`town_buildings`): Santa Lucerna holds all buildings,
  Valdora and Cárdena trade (treasury, artifact market), Ferraza works (forge,
  laboratory, lumber yard), San Vélaro farms. Balance unplaytested.
- Optional cases: 12 cross-branch links unused; 24 disclosure outcomes are recorded
  but set no flag and have no consequence; case results do not reach the notebook.
- Soul specials reduce counter evidence from two to one for every set; the authored
  per-set actions and durations are not implemented.
- Ghost activation takes the first three eligible ids, so NK07/NK08 may never appear.
- Balance: an automated probe (`tests/balance_sim.gd`, BALANCE.md) tuned battles
  so difficulty rises with the curriculum; no human playtest. Economy income and
  prices were tuned by arithmetic (`tools/economy_check.py`), not by play.

## P2 - Release readiness (sections 33, 35, 42, Epic 14.3, Epic 20)

- A Windows preset exists and a build was produced (RELEASE.md); the `.exe` has not
  been run on Windows; no application icon.
- Title screen with continue, new game, audio settings (saved in
  `user://settings.json`) and quit; the map has "Menú principal".
- Frame rate: after moving fog to a tile layer, one windowed run on the development
  machine measured 259 fps idle and 268 fps with the pointer moving (whole province
  explored, zoomed out); 189 and 151 with the optional vignette. No weak-hardware
  acceptance measurement. The headless benchmark measures logic timings only.
- Demo removed: Dialogic, the field autoloads, `overworld/`, `combat/`, `src/field`,
  `src/main.tscn`, demo README/CHANGELOG. Still kept because the arena extends them:
  `src/combat` (with CombatEvents, Music, Transition autoloads). The shutdown warning
  dropped from 26 to 1 resource.
- Art and audio (Epic 20): terrain, locations, heroes, resource sites, knights, looping
  music and interface sounds are wired into the map; the title screen uses the
  parchment page and the battle arena shows a Kenney unit figure per stack (coloured
  by side). Still placeholder or missing: gates; unit figures in battle are
  small Kenney RTS sprites scaled ×3 (no animation frames); movement animation; The 20 newer speakers have simple generated busts
  (`tools/make_portraits.py`), not illustrated portraits. The fog
  and parchment shaders are unused; the vignette is optional and off. Nobody has
  listened to the audio.
- Project README exists; no CI. Screenshot paths in about 28 test lines are absolute.
- Autosave failure shows only a small label; save validation hard-codes key counts
  and the NPC whitelist, so adding state requires touching those lines.

## P3 - Measurement and playtest (section 43)

- Mainline travel and writing load are measured by a real-path probe
  (MEASUREMENTS.md: 61 travel days, 35 cards, 124 lesson sentences); the hours are an
  estimate (about 4 h mainline, 8-10 h with optional content), not observed.
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
