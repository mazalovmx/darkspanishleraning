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
window. These images are local ignored artifacts. Scenario dialogue is not tested yet.
