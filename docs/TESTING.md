# Testing

Run from repository root in PowerShell. Local engine binaries and logs are ignored.

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --version
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --editor --import --log-file C:/dev/game/tools/local/bootstrap-import.log
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --quit-after 180 --log-file C:/dev/game/tools/local/bootstrap-runtime.log
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --path game --quit-after 180 --log-file C:/dev/game/tools/local/bootstrap-window.log
```

## All suites in one command

```powershell
./tools/run-tests.ps1                 # every non-live suite, headless
./tools/run-tests.ps1 -Filter ghost   # only suites whose name contains "ghost"
```

The runner executes each `game/tests/*_test.gd` (the two catalog suites through their
`.tscn`), then the two-process `save_restart_test`. It never runs `claude_live_test`
and clears the Anthropic key variables for its own process, so no paid request is
possible. A suite passes only with exit code 0, `failures: 0` and no script/parse
error in its log. Logs go to `tools/local/test-logs` (ignored). It does not run the
windowed/OpenGL variants, the editor import or the live check; run those by hand as
described below. A full run takes roughly a quarter of an hour on this machine.
Sections below describe individual suites as they were when added; suites added
later (campaign, economy, equipment, side cases, ghosts, province) follow the same
`--script res://tests/<name>.gd` form and are all covered by the runner.

Inspect logs as well as exit codes: Godot may return zero despite script errors.
`--quit-after` counts frames, not seconds. The windowed smoke run checks graphics
initialization and main-scene startup, not interactive playability or FPS.

## World map regression checks

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/world_map_test.gd
```

Omit `--headless` for graphics validation. The graphics run writes a review screenshot
at `tools/local/world-preview.png` (local path currently specific to this workspace).
Expected: `World map checks: 365, failures: 0`, exit 0. Also inspect script/error logs.
The suite instantiates the real map scene and dispatches mouse input through the
viewport. It checks rules, weighted paths, blocked destinations, point spending,
selection, pan/zoom, picking and route previews. End-turn wiring is tested through
its button signal; it is not a manual playtest. Original bootstrap shutdown diagnostics
remain and are recorded in STATE.md. Root tests/ directories remain scaffolding.
See STATE.md for actual results and known shutdown diagnostics.

Fog/POI coverage includes visibility radius, explored retention, discovery along
movement paths, hidden navigation, hidden terrain removal, POI arrival affordability,
reopening without cost, actual close-button mouse input, Escape and modal input
isolation. Graphics tests also save tools/local/poi-preview.png for the monastery
window. These images are local ignored artifacts. Authored dialogue has a separate suite below.

## Authored dialogue checks

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/authored_dialogue_test.gd
```

Expected: 25 assertions, zero failures. Remove --headless to exercise graphics and
write tools/local/dialogue-preview.png. Checks include Spanish Unicode typing and
Enter through actual viewport events, authored replies/fallbacks, isolated bounded
history, reopen, blank/oversized input, literal markup, and Escape with input focus.
No external API is used; these tests do not validate language evaluation quality.

## Claude client checks

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/claude_client_test.gd
```

Expected: 72 assertions, zero failures. Fake transport simulates completed HTTPRequest
signals; no real HTTP/TLS or paid API calls are made. Tests cover malformed schema,
wrong types/ranges, truncated output, proposals that would mutate state, retry limit,
missing key, offline mode, duplicate submissions, delayed replies and fallback UI.
The authored-dialogue suite explicitly forces offline mode even if a key is available.

Live Gate C passed on 2026-10-05. To repeat: configure ANTHROPIC_API_KEY in the local environment and
start a fresh Godot process. Keep dev_flags.offline_mode=false in game/config/game.json.
Reach the inn, send a short Spanish message and verify a validated Claude reply rather
than fallback. Use the debugger to inspect client completion if needed, never key/header
contents. Record actual outcome and model availability before starting Gate D.

## Local key launcher and opt-in live check

```powershell
# Launch the game with a locally supplied .env:
./tools/run-game.ps1
# Explicitly send one short real conversation (maximum one retry):
./tools/run-game.ps1 -LiveTest
```

.env accepts ANTHROPIC_API_KEY or ANTHROPIC_KEY; the standard name takes precedence.
The launcher supports simple KEY=value lines with optional matching quotes and optional
export prefix; it does not execute the file. Existing process key is retained when no
recognized nonempty value exists. Keys are passed only via the process environment.
No key is put in command arguments or logs. Live test success requires schema validation
AND the reply appearing in the originating UI log. Verified: HTTP 200, one attempt,
PASS, exit 0. Tests without --live do not send a live request.

## Spanish evaluation checks

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/spanish_feedback_test.gd
```

Expected: 27 assertions, zero failures. Remove --headless for the rendered feedback
screenshot tools/local/spanish-preview.png. Covers clamping, deduplication, confidence,
unknown tags, error/success conflicts, verb tracking, memory bounds, UI corrections,
reopen, fallback, invalid evaluation and absence of automatic curriculum advancement.
The opt-in tools/run-game.ps1 -LiveTest now sends an intentional tener error and requires
an actual correction in the feedback plus decreased tener mastery from a test-only 0.5
baseline. Passed HTTP 200 in one attempt. This baseline never affects normal new games.

## Side catalog validation

Run the smallest relevant fixture scene:

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game res://tests/side_catalog_test.tscn
```

Executed 2026-10-05: 5,341 checks, zero failures, exit 0. Validates all 108 quests,
108 artifacts, 108 battle records, 12 branches and cipher answers. These checks do
not exercise campaign integration, combat balance, language assessment or persistence.
The existing ObjectDB/26-resource shutdown diagnostics still appear.

## NPC grounding checks

Run: Godot --headless --path game --script res://tests/npc_grounding_test.gd
(using the local binary shown above). Executed: 54 checks, zero failures, exit 0.
Covers per-NPC isolation, withheld secrets, copied context, known/unknown clue IDs,
exact prerequisite types, repeated reveals, belief vs knowledge, local intent and the
actual map/dialogue response boundary with fake transport. Existing 72 client, 27
Spanish feedback and 25 authored dialogue checks also passed. No live call on this step.
Existing shutdown retention diagnostics remain; arbitrary prose truth is not verified.
## Equipment and ghost catalog fixture

Run the local Godot binary with:

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game res://tests/equipment_ghost_catalog_test.tscn
```

Executed: 1,886 checks, zero failures, exit 0. Covers 30 types, 180 items, six ranks,
six recipes, 24 SX reward overlays and eight knight profiles. Checks slot compatibility,
component provenance, curriculum order, non-click assembly requirements, bounded
effects, valid battle commands, optional counters and recovery contracts. This does
not test implemented assembly, persuasion, simultaneous movement or battle balance:
those systems have their own later suites (equipment_*, ghost_*, simultaneous_turn). Existing ObjectDB/26-resource shutdown diagnostics remain.

## Save/load checks

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/save_game_test.gd
```

Executed: 523 assertions, zero failures, exit 0 (headless and OpenGL). Tests use an
isolated user://save_test_<process_id> directory, then clean only their own files.
Existing map/dialogue/client/learner/grounding tests now disable persistence. The live
test also disables it; that live test was not rerun in this task.

Covers complete implemented-state round-trip, all 400 fog cells, weighted routes,
learner deduplication, malformed input, future versions, corrupt/oversized files,
validation/write/replacement failures, startup resume, UI confirmation before replacing
an unreadable file, pending-reply guards, autosave and clearing transient feedback.
Mastery equality tolerance is 1e-12; integer counters are restored as integers.
The map scene was rendered and tools/local/save-preview.png was inspected.

Fresh-process smoke (use a fresh unique filename beginning save_restart_):

```powershell
$testSavePath = 'user://save_restart_' + [guid]::NewGuid().ToString('N') + '.json'
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/save_restart_test.gd -- --write $testSavePath
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --script res://tests/save_restart_test.gd -- --read $testSavePath
```

Both processes passed and exited 0; the reader removes that test file. Regression:
365 map + 25 authored + 72 client + 27 Spanish + 54 grounding passed. Existing
ObjectDB/26-resource shutdown diagnostics remain. Abrupt power-loss recovery is not
tested. Replacement uses the documented [Godot DirAccess.rename_absolute](https://docs.godotengine.org/en/4.6/classes/class_diraccess.html#class-diraccess-method-rename-absolute)
behavior; successful Windows replacement and failed-destination preservation are tested.

## Evidence notebook checks

Run local Godot with --headless --path game --script res://tests/evidence_notebook_test.gd.
Executed: 53 assertions, zero failures, exit 0, headless and OpenGL. Checks empty journal,
location restriction, mandatory typed Spanish and classification, open interpretations,
copy isolation, save/restore, v1 migration, forged record rejection, modal input and
autosave. tools/local/evidence-preview.png inspected after final layout adjustment.
Regression: 524 save/load, 365 map, 25 authored dialogue assertions passed. Existing
shutdown diagnostics persist. No live API calls or complete-investigation claim.

## Verified dialogue clue tests

Run local Godot with --headless --path game --script res://tests/dialogue_clue_test.gd.
Executed: 39 checks, zero failures, exit 0, headless and OpenGL. Fake transport tests
actual request eligibility, model proposal verification, rejected-proposal isolation,
original-NPC/day handling after movement, canonical disclosure, journal selection and
autosave. Explicit offline mode tests the same unlock without invented mastery.
tools/local/dialogue-clue-preview.png inspected.

Regression: 53 notebook + 54 grounding + 72 client + 27 Spanish + 25 authored dialogue +
524 save + 365 map checks passed. Fresh-process save_restart_test now also verifies
both evidence nodes and claim classification; write/read passed. No live API run was
performed. Existing ObjectDB/26-resource shutdown diagnostics remain.
