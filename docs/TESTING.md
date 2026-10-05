# Testing

Run from repository root in PowerShell. Local engine binaries and logs are ignored.

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --version
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --editor --import --log-file C:/dev/game/tools/local/bootstrap-import.log
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --quit-after 180 --log-file C:/dev/game/tools/local/bootstrap-runtime.log
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --path game --quit-after 180 --log-file C:/dev/game/tools/local/bootstrap-window.log
```

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