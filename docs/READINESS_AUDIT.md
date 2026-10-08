# Readiness audit — 2026-10-08

Scope: merged origin/implementation at 6e5c09b into the local implementation branch,
preserving the earlier Windows verification commit. The only merge conflict was
two appended sections of STATE.md; both were retained. No gameplay code was changed
by this audit. Root/docs specification pairs have matching SHA-256 hashes.

## Implemented, with automated coverage

- Province map: 160 × 120 cells, three heroes, terrain costs, fog, locations,
  simultaneous turns, economy, equipment, optional investigations and ghost knights.
- Campaign: Acts I–VII, 54 campaign cards, deterministic council outcomes,
  institutional declarations and offline progression. Tests use fixtures; this is
  not evidence of a complete human playthrough.
- Content: 33 distinct conversation speakers; 108 optional quests in 12 branches,
  with artifacts, battles, comparisons and outcomes.
- Spanish: seven ordered curriculum blocks, 31 lesson cards, rule reminders,
  learner progress, review, nine survival exchanges and 127 vocabulary items in
  seven themes. Transactions require typed answers in multiple regions.
- Dialogue: grounded unlock validation, bounded provider fallback and 91 offline
  golden cases. Adaptive difficulty uses understanding/confidence; the separate
  difficulty_observation response field is validated but not consumed.
- Persistence: versioned saves, restart coverage, corrupt-save handling, failed-save
  warnings and safeguards against leaving the session or replacing a save after
  failed writes. Title/menu and audio settings exist.

## Partial or still missing

1. Free-answer checks recognise authored content and target forms, not complete
   Spanish grammar. Agreement and word-order quality still need work. Market,
   strategy, soul and optional-case answers lack the campaign's model review.
2. Most later investigation conclusions remain separate typed cards. Talking to
   36 speakers' cards is a prerequisite, but conversation does not itself resolve
   their outcomes. Five decisions still use authored choices. Companion dialogue
   away from introduction locations is missing.
3. NPC memory stores counts, dates, topics and revealed clues. Persistent lies,
   relationships and a validated conversation summary are missing;
   npc_attitude_delta is explicitly restricted to zero.
4. Survival conversations quote prices; purchases happen at separate counters.
   The complaint reply does not replace inventory items.
5. Santa Lucerna sub-spaces and city-specific vocabulary remain absent. Some art
   is placeholder, and the new prose and Spanish lessons lack human editorial review.
6. Full input/cache/cost accounting and a live golden-conversation suite are absent.
   The latest provider chain has offline tests, not a live result from this audit.

## Unverified acceptance criteria

- Gate I stays open. Gates A–H are historical project acceptances, not newly
  repeated live/API acceptances in this audit.
- The 4–5 hour critical path and 8–10 hour full game are estimates in
  MEASUREMENTS.md, not observed playtime. Language-event cadence is unmeasured.
- No human playtest or current end-to-end balance validation is recorded.
- The Windows export preset is tracked, but this machine has no 4.6.2 Windows
  release export template in the documented installation path. No release .exe
  was built or run here. The earlier Linux export is documented in RELEASE.md.
- A graphics fixture can prove startup, not visual quality, audible output or
  sustained frame rate on weak hardware. Shutdown leak warnings remain.

## User-owned music

Eight MP3 files and their Godot import descriptors were added and pushed in
82ec61f after the user identified the music as their own and requested upload.
The editor imported all eight successfully. Scene music selection still uses
earlier tracks: these new assets are stored, not assigned to scenes or auditioned.

## Checks in this audit

- Godot 4.6.2 editor import on Windows: exit 0, no import/script errors.
- Windows OpenGL title/menu/map fixture: 9 checks, zero failures, exit 0, AMD
  Radeon Vega 8. Hidden window; no visual review. CanvasItem/ObjectDB leak warnings.
- Full offline regression: 62 runs (60 suites and the save restart pair), 58,553
  counted checks. 61 runs passed; performance_test failed six timing budgets. Worst
  results: map refresh with new cells 60.832/60 ms, unchanged refresh 5.296/5 ms,
  rebuild 371.495/250 ms, travel day 2698.402/2000 ms, save write 2043.467/1200 ms,
  save read 1590.317/1000 ms. These are genuine unpassed checks; machine load may
  affect timings but has not been established as the cause. All functional suites
  passed. Logs: tools/local/test-logs.
- No paid/live API requests, release export, listening test or manual playthrough.

Next priorities: investigate the failed timing budgets, address language-validation and
conversation gaps in small tasks, then conduct a timed human playtest and verify
an exported Windows build. Do not equate passing fixtures with full-game acceptance.
