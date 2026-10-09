extends Node2D

const WoodTheme = preload("res://src/common/wood_theme.gd")
const Settings = preload("res://src/common/settings.gd")
const WorldState = preload("res://src/world/world_state.gd")
const SaveGame = preload("res://src/save/save_game.gd")
const PlayLog = preload("res://src/common/play_log.gd")
const CELL_SIZE := 32
const COLORS := {"road": Color("bda474"), "grass": Color("69764b"),
	"forest": Color("304a37"), "marsh": Color("64716b"), "mountain": Color("555660"),
	"water": Color("365f80"), "field": Color("a29446"), "ruins": Color("80716a"),
	"snow": Color("ccd7d7")}
# CC0 art and music (game/CREDITS.md). Each use falls back to the drawn placeholder
# when its file is missing. Terrain: tile number, centred overlay sprite, tint.
const ART := "res://assets/third_party/kenney_medieval_rts/"
const MUSIC := "res://assets/third_party/music/"
const TERRAIN_ART := {"road": [1, "", Color.WHITE], "grass": [57, "", Color.WHITE], "forest": [48, "", Color.WHITE],
	"marsh": [57, "Environment/medievalEnvironment_13", Color(0.55, 0.72, 0.64)], "mountain": [15, "Environment/medievalEnvironment_10", Color.WHITE],
	"water": [27, "", Color(0.72, 0.84, 1.0)], "field": [13, "", Color.WHITE],
	"ruins": [16, "Environment/medievalEnvironment_09", Color(0.86, 0.8, 0.74)], "snow": [29, "", Color.WHITE]}
const LOCATION_ART := {"monastery": 4, "capital": 6, "university": 20, "industrial": 5, "port": 18, "customs": 1,
	"town": 17, "mine": 8, "ruin": 12, "marsh": 23, "inn": 9, "farm": 13, "workshop": 21, "archive": 11,
	"hospital": 19, "guildhouse": 3, "camp": 10}
const HERO_ART := {"inquisitor": 4, "smuggler": 11, "survivor": 19}
# Three decorated variants per terrain (base tile, overlay); row 0 is the plain tile.
# Cells pick a variant from a fixed hash of their position, so the map never changes.
const TERRAIN_VARIANTS := {"grass": [[57, "Environment/medievalEnvironment_13"], [57, "Environment/medievalEnvironment_01"], [57, "Environment/medievalEnvironment_20"]],
	"forest": [[45, ""], [46, ""], [47, ""]],
	"field": [[13, "Environment/medievalEnvironment_14"], [13, "Environment/medievalEnvironment_13"], [13, "Environment/medievalEnvironment_06"]],
	"marsh": [[57, "Environment/medievalEnvironment_20"], [57, "Environment/medievalEnvironment_06"], [57, "Environment/medievalEnvironment_01"]],
	"mountain": [[15, "Environment/medievalEnvironment_09"], [15, "Environment/medievalEnvironment_08"], [15, "Environment/medievalEnvironment_11"]],
	"ruins": [[16, "Environment/medievalEnvironment_08"], [16, "Environment/medievalEnvironment_14"], [16, "Environment/medievalEnvironment_07"]],
	"snow": [[29, "Environment/medievalEnvironment_03"], [29, "Environment/medievalEnvironment_04"], [29, "Environment/medievalEnvironment_07"]]}
# Share of cells that use a decorated variant, per terrain (out of 10).
const VARIANT_SHARE := {"grass": 1, "forest": 10, "field": 2, "marsh": 5, "mountain": 6, "ruins": 5, "snow": 4}
# Resource sites by what they yield; knights share one armoured figure.
const SITE_ART := {"wood": "Environment/medievalEnvironment_06", "ore": "Environment/medievalEnvironment_10",
	"gold": "Environment/medievalEnvironment_19", "mercury": "Environment/medievalEnvironment_12",
	"sulfur": "Environment/medievalEnvironment_17", "crystal": "Environment/medievalEnvironment_11", "gems": "Environment/medievalEnvironment_18"}
const KNIGHT_ART := "Unit/medievalUnit_21"
const SFX := {"route": "drop_002.ogg", "day": "confirmation_002.ogg", "denied": "error_006.ogg",
	"enter": "doorOpen_2.ogg", "leave": "doorClose_1.ogg"}
var site_textures: Dictionary = {}
var knight_texture: Texture2D
var treasure_texture: Texture2D
var sfx := AudioStreamPlayer.new()
var vignette := ColorRect.new()
const LOCATION_MUSIC := {"inn": "the_old_tower_inn.mp3", "ruin": "dungeon_ambience.ogg", "mine": "dungeon_ambience.ogg",
	"monastery": "../music_talon/plagued_peace.ogg", "archive": "../music_talon/personal_grace.ogg",
	"hospital": "../music_talon/with_eyes_with_hearts.ogg", "university": "../music_talon/with_eyes_with_hearts.ogg",
	"workshop": "../music_talon/clockwile.ogg", "industrial": "../music_talon/clockwile.ogg",
	"town": "../music_talon/cloud_town.ogg", "customs": "../music_talon/cloud_town.ogg", "farm": "../music_talon/cloud_town.ogg"}
var location_textures: Dictionary = {}
var hero_textures: Dictionary = {}
var music := AudioStreamPlayer.new()
var music_track := ""
@export var initial_map_id := "prototype_20x20_v1"
var state: WorldState = WorldState.new()
var persistence_enabled := true
@export var save_path := SaveGame.PATH
var save_locked := false
var save_button := Button.new()
var save_picker = preload("res://src/save/save_picker.gd").new()
var slot_directory := "user://saves"
var load_button := Button.new()
var save_notice := Label.new()
var save_confirm := ConfirmationDialog.new()
var new_button := Button.new()
var menu_button := Button.new()
var new_confirm := ConfirmationDialog.new()
# Shown once per session when saving fails, so lost progress is never a surprise.
var save_failed := AcceptDialog.new()
var leave_unsaved := ConfirmationDialog.new()
var save_failure_warned := false
var notebook = preload("res://src/evidence/evidence_notebook.gd").new()
var notebook_button := Button.new()
var language_button := Button.new()
var campaign_button := Button.new()
var campaign_journal = preload("res://src/world/campaign_panel.gd").new()
var lessons = preload("res://src/spanish/curriculum_panel.gd").new()
var inspect_button := Button.new()
var battle_button := Button.new()
var market_button := Button.new()
var strategy_button := Button.new()
var strategy_panel = preload("res://src/economy/strategy_panel.gd").new()
var equipment_panel = preload("res://src/world/equipment_panel.gd").new()
var equipment_button := Button.new()
var ghost_button := Button.new()
var ghost_panel = preload("res://src/world/ghost_panel.gd").new()
var side_button := Button.new()
var side_panel = preload("res://src/world/side_panel.gd").new()
var market = preload("res://src/economy/market_panel.gd").new()
var army_notice := Label.new()
# Resource bar across the top of the map: icon and amount per resource, then the day.
var resource_labels: Dictionary = {}
var day_label := Label.new()
var arena = preload("res://src/combat/stack_arena.tscn").instantiate()
var hero_buttons: Dictionary = {}
var selected := false
var pointer := Vector2.ZERO
# Right button: a drag moves the map, a click without movement clears the selection.
var right_travel := 0.0
var preview: Array[Vector2i] = []
var hovered := Vector2i(-1, -1)
var tiles := TileMapLayer.new()
var painted_state: WorldState
var painted := 0
# Dimming for explored-but-unseen cells; unknown cells have no tile and show the clear colour.
var fog_tiles := TileMapLayer.new()
var lit: Array[Vector2i] = []
var camera := Camera2D.new()
var zoom_label := Label.new()
var center_button := Button.new()
var camera_logged_at := 0
var hero := Sprite2D.new()
# Last cell and hero the token showed: a move walks the token along its path by
# animating the sprite offset, while its position is already the new cell.
var shown_cell := Vector2i(-1, -1)
var shown_id := ""
var walk: Tween
var status := Label.new()
var route_info := Label.new()
var end_button := Button.new()
var poi_modal := ColorRect.new()
var poi_title := Label.new()
var poi_description := Label.new()
var poi_close := Button.new()
var dialogue = preload("res://src/dialogue/authored_dialogue.gd").new()

func _ready() -> void:
	if state.map_id != initial_map_id:
		state = WorldState.new(initial_map_id)
	_build_tiles()
	camera.position = Vector2(430, 320)
	if state.map_id == "province_160x120_v1":
		camera.position = tiles.map_to_local(state.hero_cell)
		camera.offset = Vector2(160, 0)
	add_child(camera)
	camera.make_current()
	var token := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			if Vector2(x - 11.5, y - 11.5).length() < 10:
				token.set_pixel(x, y, Color("f7df9a") if x > 5 else Color("9b653e"))
	hero.texture = ImageTexture.create_from_image(token)
	add_child(hero)
	hero_textures[""] = hero.texture
	for id: String in HERO_ART:
		var path := ART + "Unit/medievalUnit_%02d.png" % HERO_ART[id]
		var face := "res://assets/third_party/claw_and_blade/portraits/%s.png" % id
		if ResourceLoader.exists(face):
			path = face
		if ResourceLoader.exists(path):
			hero_textures[id] = _map_art(path)
	for kind: String in LOCATION_ART:
		var path := ART + "Structure/medievalStructure_%02d.png" % LOCATION_ART[kind]
		if ResourceLoader.exists(path):
			location_textures[kind] = _map_art(path)
	var painted_places := {"capital":"castle", "town":"houses", "workshop":"blacksmith", "industrial":"blacksmith", "university":"tower", "archive":"tower", "camp":"barracks", "guildhouse":"houses_2", "inn":"houses_1", "farm":"stable"}
	for kind: String in painted_places:
		var path: String = "res://assets/third_party/feudal_wars/" + painted_places[kind] + ".png"
		if ResourceLoader.exists(path):
			location_textures[kind] = _map_art(path)
	if ResourceLoader.exists("res://assets/third_party/ravenmore/backpack.png"):
		treasure_texture = load("res://assets/third_party/ravenmore/backpack.png")
	add_child(music)
	add_child(sfx)
	for resource: String in SITE_ART:
		if ResourceLoader.exists(ART + SITE_ART[resource] + ".png"):
			site_textures[resource] = _map_art(ART + SITE_ART[resource] + ".png")
	if ResourceLoader.exists(ART + KNIGHT_ART + ".png"):
		knight_texture = load(ART + KNIGHT_ART + ".png")
	_build_ui()
	# Optional darkened screen edges between the map and the interface. Off unless configured.
	if dialogue.client.config.get("effects", {}).get("vignette", false) and ResourceLoader.exists("res://assets/third_party/shaders/vignette.gdshader"):
		var under := CanvasLayer.new()
		under.layer = 0
		add_child(under)
		var shade := ShaderMaterial.new()
		shade.shader = load("res://assets/third_party/shaders/vignette.gdshader")
		vignette.material = shade
		vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
		under.add_child(vignette)
	_refresh()
	_update_preview()
	_play_music("minstrel_dance.mp3")
	Settings.apply_effects(Settings.audio(dialogue.client.config))

	preload("res://src/common/copy_text.gd").apply(self, func() -> void: save_notice.text = "Texto copiado.")
	PlayLog.attach(self)
	if persistence_enabled:
		dialogue.talks_path = save_path.get_basename() + ".talks.json"
		_load_game(true)
	# Chosen on the title screen: start over once the existing save has been read.
	if Engine.has_meta("start_new_game"):
		Engine.remove_meta("start_new_game")
		_new_game()

## Trim transparent margins at runtime so map figures use their allotted size.
func _map_art(path: String) -> Texture2D:
	var texture: Texture2D = load(path)
	var bounds := texture.get_image().get_used_rect()
	if not bounds.has_area():
		return texture
	var cropped := AtlasTexture.new()
	cropped.atlas = texture
	cropped.region = bounds
	return cropped

func _build_tiles() -> void:
	var atlas_image := Image.create(CELL_SIZE * COLORS.size(), CELL_SIZE * 4, false, Image.FORMAT_RGBA8)
	var names: Array = COLORS.keys()
	for i in names.size():
		for row in 4:
			atlas_image.fill_rect(Rect2i(i * CELL_SIZE, row * CELL_SIZE, CELL_SIZE, CELL_SIZE), COLORS[names[i]].darkened(0.2))
			atlas_image.fill_rect(Rect2i(i * CELL_SIZE + 1, row * CELL_SIZE + 1, CELL_SIZE - 2, CELL_SIZE - 2), COLORS[names[i]])
			var variant: Array = TERRAIN_VARIANTS.get(names[i], [])
			var art := _terrain_image(names[i]) if row == 0 or variant.is_empty() else _terrain_image(names[i], variant[row - 1][0], variant[row - 1][1])
			if art != null:
				atlas_image.blit_rect(art, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(i * CELL_SIZE, row * CELL_SIZE))
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(atlas_image)
	atlas.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	for i in names.size():
		for row in 4:
			atlas.create_tile(Vector2i(i, row))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_source(atlas, 0)
	# Source 1: road pieces by neighbour mask (N 1, E 2, S 4, W 8) on grass.
	var roads := Image.create(CELL_SIZE * 16, CELL_SIZE, false, Image.FORMAT_RGBA8)
	var road_source := TileSetAtlasSource.new()
	for mask in 16:
		var piece := _road_image(mask)
		if piece == null:
			roads.fill_rect(Rect2i(mask * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE), COLORS.road)
		else:
			roads.blit_rect(piece, Rect2i(0, 0, CELL_SIZE, CELL_SIZE), Vector2i(mask * CELL_SIZE, 0))
	road_source.texture = ImageTexture.create_from_image(roads)
	road_source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	for mask in 16:
		road_source.create_tile(Vector2i(mask, 0))
	tile_set.add_source(road_source, 1)
	tiles.tile_set = tile_set
	tiles.z_index = -1
	add_child(tiles)
	var dim := Image.create(CELL_SIZE, CELL_SIZE, false, Image.FORMAT_RGBA8)
	dim.fill(Color(0, 0, 0, 0.48))
	var dim_source := TileSetAtlasSource.new()
	dim_source.texture = ImageTexture.create_from_image(dim)
	dim_source.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	dim_source.create_tile(Vector2i.ZERO)
	var dim_set := TileSet.new()
	dim_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	dim_set.add_source(dim_source, 0)
	fog_tiles.tile_set = dim_set
	fog_tiles.z_index = -1
	add_child(fog_tiles)
	RenderingServer.set_default_clear_color(Color("171c25"))

# One baked 32 px cell per terrain; null keeps the flat placeholder colour.
func _terrain_image(terrain: String, base := 0, decoration := "") -> Image:
	var art: Array = TERRAIN_ART.get(terrain, []).duplicate()
	if base > 0 and not art.is_empty():
		art[0] = base
		art[1] = decoration
	if art.is_empty() or not ResourceLoader.exists(ART + "Tile/medievalTile_%02d.png" % art[0]):
		return null
	var image: Image = load(ART + "Tile/medievalTile_%02d.png" % art[0]).get_image()
	if image == null or image.is_empty():
		return null
	image.convert(Image.FORMAT_RGBA8)
	var overlay := ART + str(art[1]) + ".png"
	if not str(art[1]).is_empty() and ResourceLoader.exists(overlay):
		var extra: Image = load(overlay).get_image()
		if extra != null and not extra.is_empty():
			extra.convert(Image.FORMAT_RGBA8)
			if base > 0:
				# Variant decorations are small in their canvas: crop and enlarge them.
				extra = extra.get_region(extra.get_used_rect())
				var grow := minf(2.0, 44.0 / maxf(1.0, float(maxi(extra.get_width(), extra.get_height()))))
				extra.resize(maxi(1, roundi(extra.get_width() * grow)), maxi(1, roundi(extra.get_height() * grow)), Image.INTERPOLATE_NEAREST)
			image.blend_rect(extra, Rect2i(Vector2i.ZERO, extra.get_size()), (image.get_size() - extra.get_size()) / 2)
	image.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_BILINEAR)
	var tint: Color = art[2]
	if tint != Color.WHITE:
		for y in CELL_SIZE:
			for x in CELL_SIZE:
				image.set_pixel(x, y, image.get_pixel(x, y) * tint)
	return image

# Kenney road overlays (transparent) by the directions they connect; the rest are
# flips and turns of these. Mask bits: N 1, E 2, S 4, W 8.
const ROAD_PIECES := {5: [8, ""], 10: [9, ""], 15: [10, ""], 14: [11, ""], 11: [12, ""], 6: [22, ""], 12: [23, ""],
	8: [24, ""], 13: [25, ""], 7: [26, ""], 3: [22, "flip_y"], 9: [23, "flip_y"], 2: [24, "flip_x"],
	1: [24, "clockwise"], 4: [24, "counterclockwise"], 0: [24, ""]}

func _road_image(mask: int) -> Image:
	var ground_path := ART + "Tile/medievalTile_57.png"
	var piece: Array = ROAD_PIECES[mask]
	var road_path := ART + "Tile/medievalTile_%02d.png" % piece[0]
	if not ResourceLoader.exists(ground_path) or not ResourceLoader.exists(road_path):
		return null
	var image: Image = load(ground_path).get_image()
	var road: Image = load(road_path).get_image()
	if image == null or road == null:
		return null
	image.convert(Image.FORMAT_RGBA8)
	road.convert(Image.FORMAT_RGBA8)
	match piece[1]:
		"flip_x": road.flip_x()
		"flip_y": road.flip_y()
		"clockwise": road.rotate_90(CLOCKWISE)
		"counterclockwise": road.rotate_90(COUNTERCLOCKWISE)
	image.blend_rect(road, Rect2i(Vector2i.ZERO, road.get_size()), Vector2i.ZERO)
	image.resize(CELL_SIZE, CELL_SIZE, Image.INTERPOLATE_BILINEAR)
	return image

## Which neighbours of a road cell are road too (N 1, E 2, S 4, W 8).
func road_mask(cell: Vector2i) -> int:
	var mask := 0
	var bits := [[Vector2i.UP, 1], [Vector2i.RIGHT, 2], [Vector2i.DOWN, 4], [Vector2i.LEFT, 8]]
	for pair in bits:
		var next: Vector2i = cell + pair[0]
		if state.grid.region.has_point(next) and state.terrain[next.y][next.x] == "road":
			mask |= pair[1]
	return mask

# Loops one track; an unknown or missing file leaves the current one playing.
func _play_music(track: String) -> void:
	var settings: Dictionary = Settings.audio(dialogue.client.config)
	if track == music_track or not settings.get("music", true) or not ResourceLoader.exists(MUSIC + track):
		return
	var stream: AudioStream = load(MUSIC + track)
	stream.loop = true
	music.stream = stream
	music.volume_db = float(settings.get("music_db", -16.0))
	music.play()
	music_track = track

# Short interface sound; missing files and a disabled setting are silent.
func _play_sfx(event: String) -> void:
	var settings: Dictionary = Settings.audio(dialogue.client.config)
	var path := "res://assets/sfx/" + str(SFX.get(event, ""))
	if not settings.get("sfx", true) or not SFX.has(event) or not ResourceLoader.exists(path):
		return
	sfx.stream = load(path)
	sfx.volume_db = float(settings.get("sfx_db", -8.0))
	sfx.play()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(940, 20)
	panel.size = Vector2(320, 680)
	panel.theme = Theme.new()
	panel.theme.default_font_size = 18
	panel.theme.default_font = ThemeDB.fallback_font
	var wood: StyleBox = WoodTheme.frame("panel_brown.png", 12)
	if wood != null:
		panel.add_theme_stylebox_override("panel", wood)
	layer.add_child(panel)
	_build_resource_bar(layer)
	_build_poi_window(layer, panel.theme)
	ghost_panel.theme = panel.theme
	layer.add_child(ghost_panel)
	ghost_panel.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_update_preview())
	ghost_panel.changed.connect(func():
		_refresh()
		_save_game(true))
	ghost_panel.battle_requested.connect(_start_battle)
	side_panel.theme = panel.theme
	layer.add_child(side_panel)
	side_panel.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_update_preview())
	side_panel.progressed.connect(func():
		_refresh()
		_save_game(true))
	side_panel.battle_requested.connect(_start_battle)
	equipment_panel.theme = panel.theme
	layer.add_child(equipment_panel)
	equipment_panel.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_update_preview())
	equipment_panel.changed.connect(func():
		_refresh()
		_save_game(true))
	strategy_panel.theme = panel.theme
	layer.add_child(strategy_panel)
	strategy_panel.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_update_preview())
	strategy_panel.committed.connect(func():
		_refresh_town_button()
		_refresh()
		_save_game(true))
	strategy_panel.battle_requested.connect(_start_battle)
	campaign_journal.theme = panel.theme
	layer.add_child(campaign_journal)
	campaign_journal.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_update_preview())
	campaign_journal.progressed.connect(func():
		_refresh()
		_save_game(true))
	lessons.theme = panel.theme
	layer.add_child(lessons)
	lessons.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_update_preview())
	lessons.progressed.connect(func():
		if poi_modal.visible and not dialogue.location_id.is_empty():
			dialogue._render_history()
		_save_game(true))
	market.theme = panel.theme
	layer.add_child(market)
	market.closed.connect(func():
		end_button.disabled = poi_modal.visible
		_refresh())
	market.purchased.connect(func():
		_refresh()
		_save_game(true))
	layer.add_child(arena)
	arena.z_index = 30
	arena.finished.connect(_on_battle_finished)
	notebook.theme = panel.theme
	layer.add_child(notebook)
	notebook.closed.connect(func():
		end_button.disabled = poi_modal.visible
		if poi_modal.visible and not dialogue.location_id.is_empty():
			dialogue._render_history()
		_update_preview())
	notebook.evidence_recorded.connect(func(): _save_game(true))
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	margin.theme = WoodTheme.build(16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	var title := Label.new()
	title.text = "MAPA DE VIAJE"
	title.add_theme_color_override("font_color", Color("f3d27a"))
	title.add_theme_font_size_override("font_size", 20)
	box.add_child(title)
	var portraits := HBoxContainer.new()
	box.add_child(portraits)
	var hero_index := 0
	for id: String in state.party.heroes:
		var member = state.party.heroes[id]
		var button := Button.new()
		button.text = "F%d %s" % [hero_index + 1, member.definition.short_name]
		button.tooltip_text = "%s — %s" % [member.definition.name, member.definition.role]
		button.add_theme_font_size_override("font_size", 13)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		var portrait := Image.create(20, 24, false, Image.FORMAT_RGBA8)
		var color := Color(member.definition.color)
		for y in 24:
			for x in 20:
				if Vector2(x - 9.5, y - 6).length() < 5 or (y > 12 and absf(x - 9.5) < 8):
					portrait.set_pixel(x, y, color)
		button.icon = ImageTexture.create_from_image(portrait)
		var face := "res://assets/third_party/claw_and_blade/portraits/%s.png" % id
		if ResourceLoader.exists(face):
			button.icon = load(face)
			button.expand_icon = true
			button.add_theme_constant_override("icon_max_width", 30)
		button.pressed.connect(_switch_hero.bind(id))
		portraits.add_child(button)
		hero_buttons[id] = button
		hero_index += 1
	box.add_child(status)
	army_notice.add_theme_font_size_override("font_size", 14)
	army_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(army_notice)
	# Controls and travel costs live in a tooltip, not in the panel.
	var instructions := Button.new()
	instructions.flat = true
	instructions.text = "Controles y costes (?)"
	instructions.alignment = HORIZONTAL_ALIGNMENT_LEFT
	instructions.add_theme_font_size_override("font_size", 14)
	instructions.add_theme_color_override("font_color", WoodTheme.DIM)
	instructions.focus_mode = Control.FOCUS_NONE
	instructions.tooltip_text = "Clic en el héroe: seleccionar\nClic en una casilla: preparar ruta\nArrastrar con el botón derecho (o el central): mover el mapa\nClic derecho sin arrastrar: deseleccionar\nFlechas o WASD: mover el mapa\nRueda: zoom bajo el cursor; + / −: zoom\nHome: volver al héroe\nEspacio + arrastrar: mover el mapa
Copiar texto: selecciona con el ratón y Ctrl+C; clic derecho en una línea la copia entera\n\nCOSTE POR CASILLA\nCamino / pradera / campo: 1\nBosque / ruinas / nieve: 2\nPantano: 3\nAgua / montaña: impasable"
	var navigation := HBoxContainer.new()
	box.add_child(navigation)
	center_button.text = "Al héroe"
	center_button.tooltip_text = "Home: volver al héroe activo y seleccionarlo"
	center_button.focus_mode = Control.FOCUS_NONE
	center_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_button.pressed.connect(_center_hero)
	navigation.add_child(center_button)
	for factor: float in [1.0 / 1.15, 1.15]:
		var button := Button.new()
		button.text = "−" if factor < 1 else "+"
		button.tooltip_text = "Alejar" if factor < 1 else "Acercar"
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size.x = 36
		button.pressed.connect(func(): _zoom_at(factor, get_viewport_rect().size / 2))
		navigation.add_child(button)
	zoom_label.text = "100%"
	zoom_label.add_theme_font_size_override("font_size", 14)
	navigation.add_child(zoom_label)
	box.add_child(instructions)
	box.add_child(route_info)
	route_info.custom_minimum_size = Vector2(260, 60)
	route_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_button.text = "Resolver órdenes" if state.map_id == "province_160x120_v1" else "Terminar turno"
	end_button.pressed.connect(_end_turn)
	var turns := HBoxContainer.new()
	end_button.add_theme_font_size_override("font_size",15)
	end_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turns.add_child(end_button)
	var cancel_route := Button.new()
	cancel_route.text = "Cancelar ruta"
	cancel_route.tooltip_text = "Borra la ruta preparada para el héroe activo; no gasta movimiento.\nClears the route planned for the active hero."
	cancel_route.visible = state.map_id == "province_160x120_v1"
	cancel_route.pressed.connect(func():
		if state.ghosts.plan != null and not arena.visible:
			state.ghosts.plan.cancel_move(state.party.active_id)
			_save_game(true)
			_refresh())
	box.add_child(cancel_route)
	campaign_button.text = "Expedientes"
	campaign_button.add_theme_font_size_override("font_size",15)
	campaign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_button.visible = state.map_id == "province_160x120_v1"
	campaign_button.pressed.connect(func():
		if arena.visible or market.visible or notebook.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible or dialogue.client.busy:
			return
		campaign_journal.open_journal(state)
		end_button.disabled = true
		_update_preview())
	turns.add_child(campaign_button)
	box.add_child(turns)
	equipment_button.text = "Equipo y almas"
	equipment_button.pressed.connect(func():
		if poi_modal.visible or arena.visible or market.visible or notebook.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible or dialogue.client.busy:
			return
		equipment_panel.open_inventory(state)
		end_button.disabled = true
		_update_preview())
	box.add_child(equipment_button)
	side_button.text = "Investigaciones locales"
	side_button.visible = state.map_id == "province_160x120_v1"
	side_button.pressed.connect(func():
		if poi_modal.visible or arena.visible or market.visible or notebook.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible or dialogue.client.busy:
			return
		side_panel.open_cases(state)
		end_button.disabled = true
		_update_preview())
	box.add_child(side_button)
	ghost_button.text = "Caballeros y pruebas"
	ghost_button.visible = state.map_id == "province_160x120_v1"
	ghost_button.pressed.connect(func():
		if poi_modal.visible or arena.visible or market.visible or notebook.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or side_panel.visible or ghost_panel.visible or dialogue.client.busy:
			return
		ghost_panel.open_orders(state)
		end_button.disabled = true
		_update_preview())
	box.add_child(ghost_button)
	var saves := HBoxContainer.new()
	var study := HBoxContainer.new()
	save_button.text = "Guardar partida"
	load_button.text = "Cargar partida"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(func(): _open_save_picker(true))
	load_button.pressed.connect(func(): _open_save_picker(false))
	saves.add_child(save_button)
	saves.add_child(load_button)
	notebook_button.text = "Cuaderno"
	notebook_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notebook_button.add_theme_font_size_override("font_size", 15)
	notebook_button.pressed.connect(func():
		if campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible:
			return
		notebook.open_journal(state)
		end_button.disabled = true
		_update_preview())
	study.add_child(notebook_button)
	language_button.text = "Español · Diccionario"
	language_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	language_button.pressed.connect(func():
		if not arena.visible and not dialogue.client.busy and not market.visible and not notebook.visible and not campaign_journal.visible and not strategy_panel.visible and not equipment_panel.visible and not ghost_panel.visible and not side_panel.visible:
			lessons.open_course(state)
			end_button.disabled = true
			_update_preview())
	study.add_child(language_button)
	for control in [save_button, load_button, notebook_button, language_button]:
		control.add_theme_font_size_override("font_size", 13)
	box.add_child(study)
	box.add_child(saves)
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice.add_theme_font_size_override("font_size", 14)
	box.add_child(save_notice)
	layer.add_child(save_picker)
	save_picker.chosen.connect(_choose_save)
	layer.add_child(save_confirm)
	save_confirm.title = "Reemplazar archivo"
	save_confirm.dialog_text = "El archivo no se puede cargar. ¿Guardar esta partida en su lugar?"
	save_confirm.confirmed.connect(func(): _save_game(false, true))
	new_button.text = "Nueva partida"
	new_button.add_theme_font_size_override("font_size", 13)
	new_button.pressed.connect(func():
		if _can_restart():
			new_confirm.popup_centered())
	var session := HBoxContainer.new()
	box.add_child(session)
	new_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	session.add_child(new_button)
	menu_button.text = "Menú principal"
	menu_button.add_theme_font_size_override("font_size", 13)
	menu_button.pressed.connect(func():
		# Leave only once the session is on disk, or when the player chooses to lose it.
		if _can_restart():
			if _save_game(true):
				_leave_to_menu()
			else:
				leave_unsaved.popup_centered())
	session.add_child(menu_button)
	_explain_buttons()
	layer.add_child(leave_unsaved)
	leave_unsaved.title = "Partida sin guardar"
	leave_unsaved.dialog_text = "La partida no se pudo guardar. Si vuelves al menú, se pierde el progreso no guardado."
	leave_unsaved.ok_button_text = "Salir sin guardar"
	leave_unsaved.cancel_button_text = "Seguir jugando"
	leave_unsaved.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	leave_unsaved.get_label().custom_minimum_size = Vector2(420, 0)
	leave_unsaved.confirmed.connect(_leave_to_menu)
	layer.add_child(new_confirm)
	layer.add_child(save_failed)
	save_failed.title = "No se pudo guardar"
	save_failed.dialog_text = "La partida no se pudo guardar en el disco. Si cierras el juego ahora, puedes perder el progreso de esta sesión. El juego lo intentará de nuevo en el próximo guardado; comprueba el espacio libre y los permisos de la carpeta."
	save_failed.ok_button_text = "Entendido"
	save_failed.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_failed.get_label().custom_minimum_size = Vector2(460, 0)
	save_failed.get_label().add_theme_font_size_override("font_size", 22)
	save_failed.get_ok_button().add_theme_font_size_override("font_size", 22)
	save_failed.add_theme_font_size_override("title_font_size", 24)
	new_confirm.title = "Nueva partida"
	new_confirm.dialog_text = "¿Empezar desde el principio? La partida guardada se reemplaza; se conserva una copia anterior."
	new_confirm.confirmed.connect(_new_game)
	# The inherited demo theme gives dialogs a very large font; keep them readable at 1280x720.
	for dialog: ConfirmationDialog in [save_confirm, new_confirm]:
		dialog.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialog.get_label().custom_minimum_size = Vector2(460, 0)
		for control in [dialog.get_label(), dialog.get_ok_button(), dialog.get_cancel_button()]:
			control.add_theme_font_size_override("font_size", 24)
		dialog.add_theme_font_size_override("title_font_size", 24)
		dialog.ok_button_text = "Sí"
		dialog.cancel_button_text = "No"
	dialogue.request_started.connect(func():
		save_button.disabled = true
		load_button.disabled = true)
	dialogue.turn_finished.connect(_on_dialogue_finished)
	for pair in [[end_button, "hourglass"], [campaign_button, "book_open"], [equipment_button, "pouch"],
			[side_button, "structure_house"], [ghost_button, "skull"]]:
		pair[0].icon = WoodTheme.icon(pair[1])

## Resource bar over the top of the map, in the manner of a strategy game's treasury.
func _build_resource_bar(layer: CanvasLayer) -> void:
	var bar := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.1, 0.07, 0.92)
	style.border_color = Color("b8913f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(4)
	style.content_margin_left = 12
	style.content_margin_right = 14
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	bar.add_theme_stylebox_override("panel", style)
	bar.theme = WoodTheme.build(17)
	bar.position = Vector2(12, 10)
	layer.add_child(bar)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	bar.add_child(row)
	for id: String in ["gold", "wood", "ore", "mercury", "sulfur", "crystal", "gems"]:
		var picture := TextureRect.new()
		var path := "res://assets/third_party/saint11_resources/%s.png" % id
		picture.texture = load(path) if ResourceLoader.exists(path) else null
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(28, 28)
		var name_text := str(state.economy.catalog.resource_names.get(id, id))
		picture.tooltip_text = name_text.substr(0, 1).to_upper() + name_text.substr(1)
		row.add_child(picture)
		var amount := Label.new()
		amount.custom_minimum_size.x = 44 if id == "gold" else 26
		amount.tooltip_text = picture.tooltip_text
		amount.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(amount)
		resource_labels[id] = amount
	var gap := VSeparator.new()
	row.add_child(gap)
	day_label.add_theme_color_override("font_color", Color("f3d27a"))
	row.add_child(day_label)

func _build_poi_window(layer: CanvasLayer, ui_theme: Theme) -> void:
	poi_modal.color = Color(0, 0, 0, 0.78)
	layer.add_child(poi_modal)
	poi_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poi_modal.theme = ui_theme
	poi_modal.z_index = 10
	var panel := PanelContainer.new()
	panel.position = Vector2(260, 70)
	panel.size = Vector2(760, 580)
	# Parchment page like the journal; its frame is thicker, so it starts higher.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	if paper:
		panel.position = Vector2(250, 22)
		panel.size = Vector2(780, 676)
	poi_modal.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	poi_title.add_theme_font_size_override("font_size", 24)
	margin.add_child(box)
	poi_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	poi_title.max_lines_visible = 2
	box.add_child(poi_title)
	box.add_child(strategy_button)
	poi_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var details := ScrollContainer.new()
	details.custom_minimum_size.y = 48
	details.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(details)
	poi_description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(poi_description)
	dialogue.world_state = state
	box.add_child(dialogue)
	poi_close.text = "Volver al mapa"
	poi_close.pressed.connect(_close_poi)
	var actions := HFlowContainer.new()
	box.add_child(actions)
	inspect_button.text = "Examinar pertenencias"
	inspect_button.pressed.connect(func(): notebook.inspect(state))
	actions.add_child(inspect_button)
	battle_button.text = "Despejar el camino"
	battle_button.pressed.connect(_start_battle)
	actions.add_child(battle_button)
	market_button.text = "Comprar"
	market_button.pressed.connect(func():
		if not dialogue.client.busy:
			market.open_market(state))
	actions.add_child(market_button)
	strategy_button.text = "Edificios e ingresos"
	strategy_button.pressed.connect(func():
		if not dialogue.client.busy:
			strategy_panel.open_site(state))
	actions.add_child(poi_close)
	poi_modal.hide()

func _refresh_town_button() -> void:
	var town: String = state.location_at(state.hero_cell).get("id", "")
	strategy_button.visible = state.map_id == "province_160x120_v1" and town in state.economy.catalog.towns
	strategy_button.text = "Edificios e ingresos · %d construidos" % state.economy.buildings.get(town, {}).size()
	strategy_button.tooltip_text = "Ver el asentamiento: edificios construidos, ingresos diarios y nuevas obras."

func _open_poi(cell: Vector2i) -> void:
	if cell != state.hero_cell:
		return
	var location := state.location_at(cell)
	if location.is_empty():
		var site := state.resource_at(cell)
		if not site.is_empty():
			strategy_panel.open_site(state,site.id)
			end_button.disabled = true
			_update_preview()
		return
	_refresh_town_button()
	market_button.visible = not state.trade.offers_at(location.id).is_empty()
	market_button.text = {"LOC15": "Pedir al médico", "LOC12": "Establo", "LOC06": "Peaje", "LOC10": "Contrabandista"}.get(location.id, "Comprar")
	inspect_button.visible = location.id == "LOC01"
	battle_button.visible = location.id == "LOC11" and state.evidence.has_evidence("travel_food") and state.encounters.get("opening_road", {}).get("outcome", "") != "victory"
	poi_title.text = location.name
	poi_description.text = location.description
	# The opening starts with an inspection; say so until it is done (play log 2026-10-09).
	if location.id == "LOC01" and state.map_id == "province_160x120_v1" and not state.evidence.has_evidence("travel_food"):
		poi_description.text = "▶ PRIMER PASO: pulsa «Examinar pertenencias» (abajo) y anota en español lo que ves. Después pregunta al abad.\n" + poi_description.text
	# Local consequences of the optional cases concluded here (bible 42).
	var consequences: Array[String] = []
	if state.map_id == "province_160x120_v1":
		consequences = state.side_cases.local_consequences(location.id)
	if not consequences.is_empty():
		poi_description.text += "\n" + "\n".join(consequences)
	dialogue.open_conversation(location.id)
	_play_sfx("enter")
	_play_music(LOCATION_MUSIC.get(location.kind, "kings_feast.mp3"))
	preview.clear()
	end_button.disabled = true
	poi_modal.show()
	PlayLog.write("location_open", {"location":location.id, "name":location.name})
	poi_close.grab_focus()
	queue_redraw()

func _close_poi() -> void:
	if poi_modal.visible:
		PlayLog.write("location_close", {"speaker":dialogue.location_id})
		_play_sfx("leave")
	poi_modal.hide()
	_play_music("minstrel_dance.mp3")
	end_button.disabled = false
	poi_close.release_focus()
	_update_preview()

	_save_game(true)

func _input(event: InputEvent) -> void:
	if ghost_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		ghost_panel.close()
		get_viewport().set_input_as_handled()
		return
	if arena.visible:
		return
	if side_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		side_panel.close()
		get_viewport().set_input_as_handled()
		return
	if equipment_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		equipment_panel.close()
		get_viewport().set_input_as_handled()
		return
	if strategy_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		strategy_panel.close()
		get_viewport().set_input_as_handled()
		return
	if campaign_journal.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		campaign_journal.close()
		get_viewport().set_input_as_handled()
		return
	if lessons.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		lessons.close()
		get_viewport().set_input_as_handled()
		return
	if market.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		market.close()
		get_viewport().set_input_as_handled()
		return
	if notebook.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		notebook.close()
		get_viewport().set_input_as_handled()
		return
	# Handle Escape before LineEdit consumes it to release its keyboard focus.
	if poi_modal.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_poi()
		get_viewport().set_input_as_handled()

func _switch_hero(id: String) -> void:
	if save_picker.visible or poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		_refresh()
		return
	PlayLog.write("hero_select_attempt", {"target":id})
	if not state.select_hero(id):
		_refresh()
		return
	PlayLog.write("hero_selected", {"target":id})
	selected = true
	camera.position = tiles.map_to_local(state.hero_cell)
	_clamp_camera()
	_refresh()
	_update_preview()
	_save_game(true)

## Arrow keys or WASD scroll the map while no panel is open and nothing is being typed.
func _process(delta: float) -> void:
	if save_picker.visible or poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible:
		return
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return
	var push := Vector2(
		float(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)),
		float(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	if push != Vector2.ZERO:
		camera.position += push.normalized() * 700.0 * delta / camera.zoom.x
		_clamp_camera()

func _unhandled_input(event: InputEvent) -> void:
	if save_picker.visible or poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		_switch_hero(["inquisitor", "smuggler", "survivor"][event.keycode - KEY_F1])
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_HOME:
			_center_hero()
			get_viewport().set_input_as_handled()
			return
		if event.keycode in [KEY_PLUS, KEY_EQUAL, KEY_KP_ADD, KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom_at(1.0 / 1.15 if event.keycode in [KEY_MINUS, KEY_KP_SUBTRACT] else 1.15, get_viewport_rect().size / 2)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMouse:
		pointer = event.position
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			right_travel += event.relative.length()
		if event.button_mask & (MOUSE_BUTTON_MASK_MIDDLE | MOUSE_BUTTON_MASK_RIGHT) or (event.button_mask & MOUSE_BUTTON_MASK_LEFT and Input.is_key_pressed(KEY_SPACE)):
			camera.position -= event.relative / camera.zoom
			_clamp_camera()
		# The preview depends only on the hovered cell.
		if tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer) != hovered:
			_update_preview()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			right_travel = 0.0
		elif right_travel < 6.0:
			selected = false
			_update_preview()
			_refresh()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				if Input.is_key_pressed(KEY_SPACE):
					return
				var cell := tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer)
				if cell == state.hero_cell:
					selected = true
				elif selected:
					var before := PlayLog.snapshot(state)
					var intended: Array[Vector2i] = state.path_to(cell, true)
					var route_cost: int = state.path_cost(intended)
					var accepted: bool = state.move_to(cell, true)
					var reason := "accepted" if accepted else "undiscovered" if state.fog_at(cell) == WorldState.Fog.UNKNOWN else "unreachable" if intended.size() < 2 else "movement_budget" if route_cost > state.movement_remaining else "world_rule_or_pending_order"
					PlayLog.write("route_attempt", {"target": [cell.x, cell.y], "accepted":accepted, "before":before, "cost":route_cost, "reason":reason, "path":intended.map(func(step: Vector2i): return [step.x,step.y]), "notice":state.turn_notice, "terrain":state.terrain_cost(cell), "visible":state.fog_at(cell)})
					if accepted:
						_save_game(true)
						_play_sfx("route")
					else:
						_play_sfx("denied")
				_refresh()
				_update_preview()
				_open_poi(cell)
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var factor := 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				_zoom_at(factor, pointer)

func _center_hero() -> void:
	camera.position = tiles.map_to_local(state.hero_cell)
	selected = true
	_clamp_camera()
	_refresh()
	_update_preview()

func _zoom_at(factor: float, anchor: Vector2) -> void:
	var before := get_canvas_transform().affine_inverse() * anchor
	camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.65, 2.5)
	camera.offset = Vector2(160, 0) / camera.zoom if state.map_id == "province_160x120_v1" else Vector2.ZERO
	camera.force_update_scroll()
	camera.position += before - get_canvas_transform().affine_inverse() * anchor
	_clamp_camera()
	zoom_label.text = "%d%%" % roundi(camera.zoom.x * 100)
	_update_preview()

func _clamp_camera() -> void:
	camera.position = camera.position.clamp(Vector2.ZERO, Vector2(state.grid.region.size) * CELL_SIZE)
	camera.force_update_scroll()
	if Time.get_ticks_msec() - camera_logged_at > 500:
		PlayLog.write("camera", {"position": [camera.position.x, camera.position.y], "zoom":camera.zoom.x})
		camera_logged_at = Time.get_ticks_msec()

func _end_turn() -> void:
	if save_picker.visible or poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible:
		return
	var day_before: int = state.day
	var before := PlayLog.snapshot(state)
	PlayLog.write("turn_attempt", {"before":before})
	state.end_turn()
	PlayLog.write("turn", {"day_before": day_before, "day": state.day, "notice": str(state.turn_notice), "before":before, "after":PlayLog.snapshot(state)})
	_play_sfx("day" if state.day > day_before else "denied")
	_save_game(true)
	_refresh()
	_update_preview()
	if not state.turn_notice.is_empty():
		save_notice.text = state.turn_notice
	_resume_contact()

func _resume_contact() -> void:
	if not state.ghosts.pending_encounter.is_empty() and state.active_battle == null:
		camera.position = tiles.map_to_local(state.hero_cell)
		_start_battle(state.ghosts.pending_encounter.knight)

func _walk_hero() -> void:
	var target := tiles.map_to_local(state.hero_cell)
	if shown_id == state.party.active_id and shown_cell.x >= 0 and shown_cell != state.hero_cell and is_inside_tree() and state.grid.region.has_point(shown_cell):
		var path: Array[Vector2i] = state.grid.get_id_path(state.hero_cell, shown_cell)
		if path.size() >= 2 and path.size() <= 60:
			if walk != null:
				walk.kill()
			hero.offset = (tiles.map_to_local(shown_cell) - target) / hero.scale
			walk = create_tween()
			for k in range(path.size() - 2, -1, -1):
				walk.tween_property(hero, "offset", (tiles.map_to_local(path[k]) - target) / hero.scale, 0.07)
	elif shown_id != state.party.active_id or shown_cell == state.hero_cell:
		if walk != null and shown_id != state.party.active_id:
			walk.kill()
			hero.offset = Vector2.ZERO
	hero.position = target
	shown_cell = state.hero_cell
	shown_id = state.party.active_id

## Atlas row for a cell: 0 is the plain tile, 1-3 the decorated variants.
static func variant_row(cell: Vector2i, kind: String) -> int:
	var mixed := hash(cell) & 0x7fffffff
	if mixed % 10 >= int(VARIANT_SHARE.get(kind, 0)):
		return 0
	return 1 + (mixed / 10) % 3

func _refresh() -> void:
	# A tile shows terrain only, and explored cells are only ever added within one state:
	# repaint everything for a new state, otherwise only the cells that have no tile yet.
	if painted_state != state or painted > state.fog.size():
		tiles.clear()
		fog_tiles.clear()
		lit.clear()
		painted_state = state
		painted = 0
	if painted != state.fog.size():
		var names := COLORS.keys()
		for cell: Vector2i in state.fog:
			if painted == 0 or tiles.get_cell_source_id(cell) == -1:
				var kind: String = state.terrain[cell.y][cell.x]
				if kind == "road":
					tiles.set_cell(cell, 1, Vector2i(road_mask(cell), 0))
				else:
					tiles.set_cell(cell, 0, Vector2i(names.find(kind), variant_row(cell, kind)))
				fog_tiles.set_cell(cell, 0, Vector2i.ZERO)
		painted = state.fog.size()
	# Only the cells around unlocked heroes can be visible: re-dim the old ones, clear the new.
	for cell in lit:
		fog_tiles.set_cell(cell, 0, Vector2i.ZERO)
	lit.clear()
	for member in state.party.heroes.values():
		if not member.unlocked:
			continue
		var radius: int = state.VIEW_RADIUS + state.LAMP_RADIUS
		for y in range(member.cell.y - radius, member.cell.y + radius + 1):
			for x in range(member.cell.x - radius, member.cell.x + radius + 1):
				var cell := Vector2i(x, y)
				if state.fog_at(cell) == WorldState.Fog.VISIBLE:
					fog_tiles.erase_cell(cell)
					lit.append(cell)
	army_notice.text = "Ejército: %d/7 destacamentos" % state.army.size()
	for id in resource_labels:
		resource_labels[id].text = str(state.resources.get(id, 0))
	day_label.text = "Día %d · Semana %d" % [state.day, (state.day - 1) / 7 + 1]
	hero.texture = hero_textures.get(state.party.active_id, hero_textures[""])
	hero.scale = Vector2.ONE * (34.0 / maxf(hero.texture.get_width(), hero.texture.get_height()))
	_walk_hero()
	hero.modulate = Color.WHITE if hero_textures.has(state.party.active_id) else Color(state.party.active().definition.color)
	for id in hero_buttons:
		hero_buttons[id].set_pressed_no_signal(id == state.party.active_id)
		hero_buttons[id].disabled = not state.party.heroes[id].unlocked
		hero_buttons[id].tooltip_text = "%s — %s · Salud: %d" % [state.party.heroes[id].definition.name, state.party.heroes[id].definition.role, state.party.heroes[id].health]
	end_button.text = "Resolver órdenes" if state.map_id == "province_160x120_v1" else "Terminar turno"
	status.text = "%s · Día %d · Salud %d\nMovimiento: %d / %d\n%s" % [state.party.active().definition.short_name, state.day, state.party.active().health,
		state.movement_remaining, state.MOVEMENT_MAX + int(state.equipment.bonuses(state.party.active_id).world_movement),
		"Órdenes congeladas:\nresuelve el día primero" if state.ghosts.plan != null else "Héroe seleccionado" if selected else "Selecciona al héroe"]
	queue_redraw()

func _update_preview() -> void:
	hovered = tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer)
	preview.clear()
	if selected and not poi_modal.visible and not notebook.visible and not arena.visible and not market.visible and not lessons.visible and not campaign_journal.visible and not strategy_panel.visible and not equipment_panel.visible and not ghost_panel.visible and not side_panel.visible:
		preview = state.path_to(hovered, true)
	if not selected:
		route_info.text = "Selecciona al héroe para viajar."
	elif state.fog_at(hovered) == WorldState.Fog.UNKNOWN and state.grid.region.has_point(hovered):
		route_info.text = "Zona sin explorar. Acércate para descubrirla."
	elif preview.is_empty():
		route_info.text = "Destino inaccesible."
	else:
		var cost: int = state.path_cost(preview)
		route_info.text = "Ruta: %d puntos.%s" % [cost,
			"\nNo quedan suficientes puntos." if cost > state.movement_remaining else ""]
	var site := state.resource_at(hovered)
	if not site.is_empty() and site.has("items"):
		route_info.text = "%s%s\n%s" % [site.name, " · vigilado" if site.guarded else "", route_info.text]
	elif not site.is_empty():
		route_info.text = "Mina de %s · +%d/día\n%s" % [state.economy.catalog.resource_names[site.resource],site.daily_income,route_info.text]
	var gate := state.gate_at(hovered)
	if not gate.is_empty() and gate.closed and state.fog_at(hovered) != WorldState.Fog.UNKNOWN:
		route_info.text = gate.message
	var location := state.location_at(hovered)
	if not location.is_empty():
		route_info.text = str(location.name) + "\n" + route_info.text
	queue_redraw()

func _draw() -> void:
	for location: Dictionary in state.locations:
		var cell := Vector2i(location.position[0], location.position[1])
		if state.fog_at(cell) == WorldState.Fog.UNKNOWN:
			continue
		var center := tiles.map_to_local(cell)
		var color := Color("d9b875") if location.kind == "inn" else Color("cbd3eb")
		if state.fog_at(cell) == WorldState.Fog.EXPLORED:
			color = color.darkened(0.4)
		if location_textures.has(location.kind):
			var texture: Texture2D = location_textures[location.kind]
			var size: Vector2 = texture.get_size() * (40.0 / maxf(texture.get_width(), texture.get_height()))
			draw_texture_rect(texture, Rect2(center - size / 2, size), false, Color.WHITE if state.fog_at(cell) == WorldState.Fog.VISIBLE else Color(0.55, 0.55, 0.6))
			continue
		draw_rect(Rect2(center - Vector2(12, 12), Vector2(24, 24)), color, false, 2)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), str(location.name).left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	for site: Dictionary in state.map_data.get("resource_sites", []):
		var cell := Vector2i(site.position[0], site.position[1])
		if state.fog_at(cell) == WorldState.Fog.UNKNOWN:
			continue
		var center := tiles.map_to_local(cell)
		var owned: bool = state.economy.mines.has(site.id)
		if site_textures.has(site.resource):
			var texture: Texture2D = site_textures[site.resource]
			var size: Vector2 = texture.get_size() * (28.0 / maxf(texture.get_width(), texture.get_height()))
			draw_texture_rect(texture, Rect2(center - size / 2, size), false, Color.WHITE if state.fog_at(cell) == WorldState.Fog.VISIBLE else Color(0.55, 0.55, 0.6))
			if owned:
				draw_rect(Rect2(center - Vector2(15, 15), Vector2(30, 30)), Color("72c9b0"), false, 2)
			continue
		draw_colored_polygon(PackedVector2Array([center + Vector2(0,-8), center + Vector2(8,0), center + Vector2(0,8), center + Vector2(-8,0)]), Color("72c9b0") if owned else Color("bf9670"))
	for id: String in state.economy.treasures:
		var cache: Dictionary = state.economy.treasure(state, id)
		if cache.is_empty():
			continue
		var cell := Vector2i(cache.position[0], cache.position[1])
		if state.fog_at(cell) == WorldState.Fog.UNKNOWN or state.economy.treasure_claimed(state, id):
			continue
		var center := tiles.map_to_local(cell)
		if treasure_texture != null:
			draw_texture_rect(treasure_texture, Rect2(center - Vector2(15, 15), Vector2(30, 30)), false)
			if cache.guarded:
				draw_circle(center + Vector2(12, -12), 4, Color("df7962"))
			continue
		draw_rect(Rect2(center - Vector2(7, 5), Vector2(14, 10)), Color("d9a441") if not cache.guarded else Color("c26a4a"))
		draw_rect(Rect2(center - Vector2(7, 5), Vector2(14, 10)), Color("3a2a12"), false, 2)
	for gate: Dictionary in state.map_data.get("gates", []):
		var cell := Vector2i(gate.position[0], gate.position[1])
		if state.fog_at(cell) != WorldState.Fog.UNKNOWN and state.gate_at(cell).closed:
			var center := tiles.map_to_local(cell)
			draw_line(center - Vector2(12,0), center + Vector2(12,0), Color("df8571"), 4)
	for id: String in state.ghosts.actors:
		var actor: Dictionary = state.ghosts.actors[id]
		var cell := Vector2i(actor.cell[0],actor.cell[1])
		if not actor.active or actor.return_day > state.day or state.fog_at(cell) != WorldState.Fog.VISIBLE:
			continue
		var center := tiles.map_to_local(cell)
		if knight_texture != null:
			draw_texture_rect(knight_texture, Rect2(center - Vector2(13, 20), knight_texture.get_size() * 1.3), false, Color("b8c6ff"))
			draw_string(ThemeDB.fallback_font,center+Vector2(4,-8),id.right(2),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
			continue
		draw_circle(center,11,Color("a9badf"),false,3)
		draw_string(ThemeDB.fallback_font,center+Vector2(-9,5),id.right(2),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color.WHITE)
	if state.ghosts.plan != null:
		for id: String in state.party.heroes:
			if not state.ghosts.plan.orders.has(id):
				continue
			var points := PackedVector2Array()
			for pair: Array in state.ghosts.plan.orders[id].path:
				points.append(tiles.map_to_local(Vector2i(pair[0],pair[1])))
			if points.size() > 1:
				draw_polyline(points,Color(state.party.heroes[id].definition.color),5)
	var marker_index := 0
	for id in state.party.heroes:
		var member = state.party.heroes[id]
		if id == state.party.active_id or not member.unlocked:
			continue
		var center := tiles.map_to_local(member.cell)
		if member.cell == state.hero_cell:
			center += Vector2(-12 + marker_index * 24, 12)
		var color := Color(member.definition.color)
		draw_circle(center + Vector2(0, 3), 18, Color(0, 0, 0, 0.65))
		draw_arc(center, 17, 0, TAU, 32, color, 2, true)
		if hero_textures.has(id):
			var texture: Texture2D = hero_textures[id]
			var size: Vector2 = texture.get_size() * (32.0 / maxf(texture.get_width(), texture.get_height()))
			draw_texture_rect(texture, Rect2(center - size / 2, size), false)
			marker_index += 1
			continue
		draw_circle(center, 8, color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), str(member.definition.short_name).left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("17202b"))
		marker_index += 1
	var active_center := tiles.map_to_local(state.hero_cell)
	var active_color := Color(state.party.active().definition.color)
	draw_circle(active_center + Vector2(0, 3), 20, Color(0, 0, 0, 0.72))
	draw_arc(active_center, 19, 0, TAU, 48, active_color, 3, true)
	if selected:
		draw_arc(active_center, 22, 0, TAU, 48, Color("fff0bc"), 2, true)
		draw_colored_polygon(PackedVector2Array([active_center + Vector2(-5, -30), active_center + Vector2(5, -30), active_center + Vector2(0, -24)]), Color("fff0bc"))
	if preview.size() > 1:
		var points := PackedVector2Array()
		for cell in preview:
			points.append(tiles.map_to_local(cell))
		var color := Color("f7df9a") if state.path_cost(preview) <= state.movement_remaining else Color("eb7770")
		draw_polyline(points, color, 3)

## One sentence per button, in Spanish and in English, shown when the pointer rests on
## it. Labels stay short; the tooltip says what the button does.
func _explain_buttons() -> void:
	var texts := {
		end_button: ["Termina el día: se cumplen las rutas y órdenes de todos los héroes y empieza el día siguiente.", "Ends the day: planned routes and orders are carried out, then the next day begins."],
		campaign_button: ["Casos de la historia principal: qué investigar ahora, con quién hablar y dónde escribir tus conclusiones.", "Main story cases: what to investigate now, whom to talk to, where to write conclusions."],
		equipment_button: ["Objetos del héroe: equípalos sobre la figura, entrégalos a otro héroe, pacta con las almas, pasa tropas.", "Hero items: equip, hand over, soul pacts, troop transfer."],
		side_button: ["Casos opcionales del lugar donde está el héroe. No son necesarios para terminar la historia.", "Optional cases at the hero's location; not needed to finish the story."],
		ghost_button: ["Caballeros fantasma que recorren la provincia y las órdenes para detenerlos.", "Ghost knights roaming the province and your orders against them."],
		notebook_button: ["Cuaderno de pruebas: todo lo que has observado y oído, con su fuente.", "Evidence notebook: everything observed or heard, with its source."],
		language_button: ["Lecciones de español, tu progreso, práctica de vocabulario y el diccionario con tus palabras.", "Spanish lessons, progress, vocabulary practice and the dictionary with your own words."],
		save_button: ["Guarda una copia con nombre: se abre la ventana de archivos con un nombre ya propuesto. Además, el juego se guarda solo después de cada acción.", "Saves a named copy (file window, name prefilled). The game also autosaves after every action."],
		load_button: ["Carga una partida guardada con nombre. El autoguardado se carga solo al entrar en el juego.", "Loads a named save. The autosave loads by itself when the game starts."],
		new_button: ["Empieza la historia desde el día 1. Pide confirmación y conserva una copia de la partida actual.", "Restarts the story from day 1 (asks first; keeps a copy of the current game)."],
		menu_button: ["Guarda y vuelve a la pantalla inicial.", "Saves and returns to the title screen."],
		poi_close: ["Cierra este lugar y vuelve al mapa.", "Closes this place and returns to the map."],
		inspect_button: ["Examina las pertenencias de Tomás y anota en español lo que ves. Es el primer paso de la investigación.", "Examine Tomás's belongings and note what you see; the first step of the investigation."],
		battle_button: ["Combate contra quienes cortan el camino. Necesitas ejército y dos puntos de movimiento.", "Fight those blocking the road; needs an army and two movement points."],
		market_button: ["Compra o pide algo escribiéndolo en español.", "Buy or ask for something by typing it in Spanish."],
		strategy_button: ["Ver el asentamiento: edificios construidos, ingresos diarios y nuevas obras.", "The settlement: buildings, daily income and new construction."],
	}
	for button: Button in texts:
		button.tooltip_text = "%s\n%s" % texts[button]

func _open_save_picker(saving: bool) -> void:
	if not persistence_enabled or arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		save_notice.text = "Espera a que termine la acción actual."
		return
	save_picker.open(state, save_path, slot_directory, saving)

func _choose_save(path: String, saving: bool) -> void:
	if not persistence_enabled or arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		return
	if saving and not save_picker.accepts(path):
		save_notice.text = "Escribe un nombre para la partida."
		PlayLog.write("slot_rejected", {"saving":saving, "reason":"path"})
		return
	if not saving:
		_load_game(false, path)
		return
	var error: String = SaveGame.write_save(state, path)
	PlayLog.write("named_save", {"name":path.get_file(), "error":error})
	if not error.is_empty():
		save_notice.text = "No se pudo guardar: " + error
		return
	var original: String = dialogue.talks_path
	dialogue.talks_path = path.get_basename() + ".talks.json"
	dialogue.store_talks()
	dialogue.talks_path = original
	save_notice.text = "Partida guardada: " + path.get_file()
	save_notice.remove_theme_color_override("font_color")

## True when the session is on disk (or persistence is off for this map).
func _save_game(automatic := false, replace_invalid := false) -> bool:
	if not persistence_enabled:
		return true
	if arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		if not automatic:
			save_notice.text = "Espera a que termine la respuesta."
		return false
	if save_locked and not replace_invalid:
		if not automatic:
			save_confirm.popup_centered()
		return false
	var error: String = SaveGame.write_save(state, save_path)
	PlayLog.write("save", {"day": state.day, "automatic": automatic, "error": error})
	if error.is_empty():
		dialogue.store_talks()
		save_locked = false
		# A manual save shows the time, so pressing the button visibly changes the line.
		save_notice.text = "Partida guardada." if automatic else "Partida guardada. Día %d · %s" % [state.day, Time.get_time_string_from_system()]
		save_notice.remove_theme_color_override("font_color")
		return true
	else:
		save_notice.text = "No se pudo guardar. Inténtalo de nuevo."
		save_notice.add_theme_color_override("font_color", Color("ff8a70"))
		if not save_failure_warned:
			save_failure_warned = true
			save_failed.popup_centered()
		return false

func _load_game(startup := false, selected_path := "") -> void:
	if not persistence_enabled or arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		return
	var source: String = save_path if selected_path.is_empty() else selected_path
	var result: Dictionary = SaveGame.read_save(source)
	PlayLog.write("load_result", {"ok":result.has("state"), "reason":result.get("error", ""), "startup":startup, "name":source.get_file()})
	if not result.has("state"):
		if result.error != "missing":
			if source == save_path:
				save_locked = true
			save_notice.text = "Archivo no válido. Guardado automático pausado." if source == save_path else "No se puede cargar ese archivo. La partida actual se conserva."
			save_notice.add_theme_color_override("font_color", Color("ff8a70"))
		elif not startup:
			save_notice.text = "Todavía no hay una partida guardada."
		return
	var previous_lock := save_locked
	_adopt(result.state)
	if source != save_path:
		save_locked = previous_lock
	PlayLog.write("load_applied", {"name":source.get_file()})
	var original: String = dialogue.talks_path
	dialogue.talks_path = source.get_basename() + ".talks.json"
	dialogue.load_talks()
	dialogue.talks_path = original
	save_notice.text = "Partida cargada: " + source.get_file()
	if not state.campaign.reopened.is_empty():
		# The file still holds the old decision: keep a copy before the next save replaces it.
		var copy := source + ".reabierta.bak"
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(source), ProjectSettings.globalize_path(copy)) == OK:
			save_notice.text = "La resolución del Consejo se reabrió: la propuesta no cumplía las condiciones de su opción. El resto del progreso se conserva; el archivo anterior queda en %s." % copy.get_file()
		else:
			save_locked = true
			save_notice.text = "La resolución del Consejo se reabrió, pero no se pudo copiar el archivo anterior. Guardado automático pausado."
		save_notice.add_theme_color_override("font_color", Color("ff8a70"))
	_resume_contact()

func _leave_to_menu() -> void:
	PlayLog.write("session_end", {"reason":"menu"})
	get_tree().change_scene_to_file("res://src/ui/title_menu.tscn")

func _can_restart() -> bool:
	return not (save_picker.visible or arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty() or poi_modal.visible or notebook.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible)

func _new_game() -> void:
	if not _can_restart():
		return
	# Keep the replaced save beside the slot; without that copy the old game stays.
	if persistence_enabled and FileAccess.file_exists(save_path):
		if DirAccess.copy_absolute(ProjectSettings.globalize_path(save_path), ProjectSettings.globalize_path(save_path + ".bak")) != OK:
			save_notice.text = "No se pudo copiar la partida anterior; no se empezó una nueva."
			save_notice.add_theme_color_override("font_color", Color("ff8a70"))
			return
	_adopt(WorldState.new(state.map_id))
	PlayLog.write("new_game", {})
	_save_game(false, true)
	save_notice.text = "Partida nueva."

func _adopt(next: WorldState) -> void:
	state = next
	painted_state = null
	camera.offset = Vector2(160, 0) / camera.zoom if state.map_id == "province_160x120_v1" else Vector2.ZERO
	dialogue.world_state = state
	notebook.hide()
	market.hide()
	lessons.hide()
	campaign_journal.hide()
	ghost_panel.hide()
	ghost_panel.world_state = state
	ghost_button.visible = state.map_id == "province_160x120_v1"
	side_panel.hide()
	side_panel.world_state = state
	side_button.visible = state.map_id == "province_160x120_v1"
	equipment_panel.hide()
	equipment_panel.world_state = state
	strategy_panel.hide()
	strategy_panel.world_state = state
	campaign_journal.world_state = state
	campaign_button.visible = state.map_id == "province_160x120_v1"
	lessons.world_state = state
	market.world_state = state
	notebook.world_state = state
	notebook.active_id = ""
	dialogue.histories.clear()
	dialogue.last_feedback.clear()
	dialogue.location_id = ""
	dialogue.input.clear()
	poi_modal.hide()
	end_button.disabled = false
	selected = false
	preview.clear()
	save_locked = false
	camera.position = tiles.map_to_local(state.hero_cell)
	_clamp_camera()
	_refresh()
	_update_preview()

func _on_dialogue_finished() -> void:
	save_button.disabled = false
	load_button.disabled = false
	_save_game(true)

func _start_battle(id := "opening_road") -> void:
	PlayLog.write("battle_attempt", {"encounter":id})
	if dialogue.client.busy or notebook.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or ghost_panel.visible or side_panel.visible or not state.begin_encounter(id):
		save_notice.text = "Necesitas un ejército, dos puntos de movimiento y acceso al encuentro."
		return
	poi_modal.hide()
	save_button.disabled = true
	load_button.disabled = true
	notebook_button.disabled = true
	language_button.disabled = true
	end_button.disabled = true
	# The battlefield shows the terrain the hero stands on.
	if state.grid.region.has_point(state.hero_cell):
		arena.terrain = str(state.terrain[state.hero_cell.y][state.hero_cell.x])
	arena.present(state.active_battle, str(state.active_battle.data.opening.name))
	_update_preview()

func _on_battle_finished(_outcome: String, _survivors: Array) -> void:
	PlayLog.write("battle_finished", {"outcome":_outcome, "survivors":_survivors})
	var encounter_id: String = state.active_encounter
	if not state.settle_encounter():
		return
	arena.hide()
	save_button.disabled = false
	load_button.disabled = false
	notebook_button.disabled = false
	language_button.disabled = false
	end_button.disabled = false
	_refresh()
	_update_preview()
	_save_game(true)
	if state.side_cases.battles.has(encounter_id):
		side_panel.open_cases(state,state.side_cases.battles[encounter_id].quest_id)
		end_button.disabled = true
		return
	var site := state.resource_at(state.hero_cell)
	if not site.is_empty():
		strategy_panel.open_site(state,site.id)
		end_button.disabled = true
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		PlayLog.write("session_end", {"reason":"window_closed"})
