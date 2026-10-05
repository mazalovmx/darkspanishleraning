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

Current automated gameplay tests: none. The tests directories are scaffolding.
Add deterministic movement tests with Epic 1; later tests must follow the gates.
See STATE.md for actual results and known shutdown diagnostics.
