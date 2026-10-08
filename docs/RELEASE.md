# Windows build

`game/export_presets.cfg` defines one preset, "Windows Desktop": x86_64, the `.pck`
embedded in the `.exe`, every resource plus the JSON content (`*.json`, read with
FileAccess, so it must be listed explicitly), and no test scripts.

## Build

1. Install the Godot 4.6.2 export templates once: in the editor, Editor → Manage Export
   Templates → Download; or unzip `Godot_v4.6.2-stable_export_templates.tpz` into
   `%APPDATA%\Godot\export_templates\4.6.2.stable\`.
2. From the repository root:

```powershell
& tools/local/godot/Godot_v4.6.2-stable_win64_console.exe --headless --path game --export-release "Windows Desktop" ../exports/windows/ElIndiceDeCeniza.exe
```

`exports/` is ignored by git. Put a `.env` with the API keys next to wherever you run
it from only if you start it through `tools/run-game.ps1`; the exported game reads
the keys from the process environment, and without any key it plays offline.

## What was verified (2026-10-08, Linux)

- The export with the official 4.6.2 Windows template finished without errors or
  warnings and produced a 148 MB `ElIndiceDeCeniza.exe`.
- The embedded pack contains the JSON content and `config/game.json`.
- Running that pack with the Linux engine (`--main-pack`) opened the title screen and
  the province map for 200 frames each without errors.

Not verified: the `.exe` itself on Windows (no Windows machine here), frame rate on a
weak PC, an application icon (the preset uses the default).
