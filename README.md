# El Índice de Ceniza

A personal, local strategy-investigation game in Godot 4.6 for practising Spanish at
about B1: you travel a 160×120 province, talk to characters (DeepSeek, then Claude, or authored
offline replies; order in `game/config/game.json`), classify evidence and write your
conclusions in Spanish. Gameplay and design references live in `docs/`.

- Game project: `game/` (open `game/project.godot`; the title screen is
  `src/ui/title_menu.tscn`).
- Run on Windows: `tools/run-game.ps1` (reads `ANTHROPIC_API_KEY`, `DEEPSEEK_API_KEY`
  and `NVIDIA_API_KEY` from a local `.env`).
- Tests: `tools/run-tests.ps1` (every non-live suite, headless; no paid requests).
- Windows build: see `docs/RELEASE.md`.
- State and open work: `docs/STATE.md`, `docs/BACKLOG.md`.

Licences of the code and of third-party material: `LICENSE` and `game/CREDITS.md`.
