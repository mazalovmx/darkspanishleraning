# Third-party assets for El Índice de Ceniza

Everything here is CC0 1.0. Sources, authors and access dates are in `game/CREDITS.md`;
each Kenney pack keeps its own `LICENSE.txt` and each shader names its source in its
header. Nothing in this folder is used by the game yet: it is the material for the
art and audio pass (master spec Epic 20).

- `kenney_medieval_rts/` - 64x64 top-down PNGs: `Tile` (grass, sand, dirt, stone,
  roads), `Structure` (houses, towers, church, mill, mine), `Unit`, `Environment`
  (trees, rocks). Intended for the province map tiles and location markers.
- `kenney_ui_rpg/PNG/` - panels, buttons, bars, arrows and cursors for the UI.
- `music/` - `the_old_tower_inn.mp3` (inn), `kings_feast.mp3` and
  `minstrel_dance.mp3` (towns, travel), `dungeon_ambience.ogg` (crypt, ruins).
  The mp3 files are full tracks, not seamless loops; set looping in their import
  settings or crossfade when they are wired in.
- `shaders/` - `vignette.gdshader` (full-screen ColorRect; reads the screen texture),
  `fog_overlay.gdshader` (needs a seamless NoiseTexture2D in `noise`),
  `parchment.gdshader` (32 texture samples per pixel: small panels only).

Master spec section 35 asks to avoid heavy shaders on the target machine: measure
before enabling any of them on the whole map.
