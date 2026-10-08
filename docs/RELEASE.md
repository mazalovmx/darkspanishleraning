# Windows build

`game/export_presets.cfg` (tracked in git; it holds no credentials) defines one preset,
"Windows Desktop": x86_64, the `.pck` embedded in the `.exe`, every resource plus the
JSON content (`*.json`, read with FileAccess, so it must be listed explicitly), and
neither `tests/`, `media/` nor Markdown files. API keys never enter the pack: they are
read from the process environment.

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
weak PC, how Windows shows the icon (see below).

## Icon

`game/icon.png` (project icon) and `game/icon.ico` (16-256 px, set as
`application/icon` in the Windows preset) are drawn by `tools/make_icon.py`: a closed
book with an ember flame. A test export on 2026-10-08 embedded all six sizes in the
`.exe` (checked by searching the file for each image); how Windows Explorer shows it
has not been seen.

## Preset in the repository (2026-10-08, Linux, cloud session)

The preset was previously ignored by `game/.gitignore`, so a fresh checkout could not
export. It is now tracked. Checked with `--export-pack "Windows Desktop"` (no Windows
template needed): the pack holds `config/game.json` and all of `content/**/*.json`, and
no file under `res://tests/`, no `.env`, no `media/` and no `.md`. Not checked here: the
`--export-release` `.exe` from a clean checkout and running it on Windows.
