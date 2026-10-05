extends Node2D

const WorldState = preload("res://src/world/world_state.gd")
const CELL_SIZE := 32
const COLORS := {"road": Color("bda474"), "grass": Color("69764b"),
	"forest": Color("304a37"), "marsh": Color("64716b"), "mountain": Color("555660"),
	"water": Color("365f80"), "field": Color("a29446"), "ruins": Color("80716a"),
	"snow": Color("ccd7d7")}
var state: WorldState = WorldState.new()
var selected := false
var pointer := Vector2.ZERO
var preview: Array[Vector2i] = []
var hovered := Vector2i(-1, -1)
var tiles := TileMapLayer.new()
var camera := Camera2D.new()
var hero := Sprite2D.new()
var status := Label.new()
var route_info := Label.new()
var end_button := Button.new()

func _ready() -> void:
	_build_tiles()
	camera.position = Vector2(430, 320)
	add_child(camera)
	camera.make_current()
	var token := Image.create(24, 24, false, Image.FORMAT_RGBA8)
	for y in 24:
		for x in 24:
			if Vector2(x - 11.5, y - 11.5).length() < 10:
				token.set_pixel(x, y, Color("f7df9a") if x > 5 else Color("9b653e"))
	hero.texture = ImageTexture.create_from_image(token)
	add_child(hero)
	_build_ui()
	_refresh()
	_update_preview()

func _build_tiles() -> void:
	var atlas_image := Image.create(CELL_SIZE * COLORS.size(), CELL_SIZE, false, Image.FORMAT_RGBA8)
	var names: Array = COLORS.keys()
	for i in names.size():
		atlas_image.fill_rect(Rect2i(i * CELL_SIZE, 0, CELL_SIZE, CELL_SIZE), COLORS[names[i]].darkened(0.2))
		atlas_image.fill_rect(Rect2i(i * CELL_SIZE + 1, 1, CELL_SIZE - 2, CELL_SIZE - 2), COLORS[names[i]])
	var atlas := TileSetAtlasSource.new()
	atlas.texture = ImageTexture.create_from_image(atlas_image)
	atlas.texture_region_size = Vector2i(CELL_SIZE, CELL_SIZE)
	for i in names.size():
		atlas.create_tile(Vector2i(i, 0))
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(CELL_SIZE, CELL_SIZE)
	tile_set.add_source(atlas, 0)
	tiles.tile_set = tile_set
	tiles.z_index = -1
	add_child(tiles)
	for y in state.grid.region.size.y:
		for x in state.grid.region.size.x:
			tiles.set_cell(Vector2i(x, y), 0, Vector2i(names.find(state.terrain[y][x]), 0))

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(960, 20)
	panel.size = Vector2(300, 680)
	panel.theme = Theme.new()
	panel.theme.default_font_size = 18
	panel.theme.default_font = ThemeDB.fallback_font
	layer.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "MAPA DE VIAJE"
	box.add_child(title)
	box.add_child(status)
	var instructions := Label.new()
	instructions.text = "Clic en el héroe: seleccionar\nClic en una casilla: mover\nBotón derecho: deseleccionar\nArrastrar botón central: cámara\nRueda: acercar / alejar"
	instructions.add_theme_font_size_override("font_size", 15)
	box.add_child(instructions)
	box.add_child(route_info)
	route_info.custom_minimum_size = Vector2(260, 72)
	route_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_button.text = "Terminar turno"
	end_button.pressed.connect(_end_turn)
	box.add_child(end_button)
	var legend := Label.new()
	legend.text = "COSTE POR CASILLA\n\nCamino / pradera / campo: 1\nBosque / ruinas / nieve: 2\nPantano: 3\nAgua / montaña: impasable"
	legend.add_theme_font_size_override("font_size", 15)
	box.add_child(legend)
	var labels := ["Camino", "Pradera", "Bosque", "Pantano", "Montaña", "Agua", "Campo", "Ruinas", "Nieve"]
	var swatches := HFlowContainer.new()
	box.add_child(swatches)
	for i in COLORS.size():
		var swatch := Label.new()
		swatch.text = "■ " + labels[i] + "  "
		swatch.add_theme_color_override("font_color", COLORS.values()[i].lightened(0.2))
		swatch.add_theme_font_size_override("font_size", 14)
		swatches.add_child(swatch)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		pointer = event.position
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			camera.position -= event.relative / camera.zoom
			_clamp_camera()
		_update_preview()
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var cell := tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer)
				if cell == state.hero_cell:
					selected = true
				elif selected:
					state.move_to(cell)
				_refresh()
				_update_preview()
			MOUSE_BUTTON_RIGHT:
				selected = false
				_update_preview()
				_refresh()
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				var factor := 1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15
				camera.zoom = Vector2.ONE * clampf(camera.zoom.x * factor, 0.65, 2.5)
				_clamp_camera()
				_update_preview()

func _clamp_camera() -> void:
	camera.position = camera.position.clamp(Vector2.ZERO, Vector2(640, 640))
	camera.force_update_scroll()

func _end_turn() -> void:
	state.end_turn()
	_refresh()
	_update_preview()

func _refresh() -> void:
	hero.position = tiles.map_to_local(state.hero_cell)
	status.text = "Día %d\nMovimiento: %d / %d\n%s" % [state.day,
		state.movement_remaining, state.MOVEMENT_MAX,
		"Héroe seleccionado" if selected else "Selecciona al héroe"]
	queue_redraw()

func _update_preview() -> void:
	hovered = tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer)
	preview.clear()
	if selected:
		preview = state.path_to(hovered)
	if not selected:
		route_info.text = "Selecciona al héroe para viajar."
	elif preview.is_empty():
		route_info.text = "Destino inaccesible."
	else:
		var cost: int = state.path_cost(preview)
		route_info.text = "Ruta: %d puntos.%s" % [cost,
			"\nNo quedan suficientes puntos." if cost > state.movement_remaining else ""]
	queue_redraw()

func _draw() -> void:
	if selected:
		draw_arc(tiles.map_to_local(state.hero_cell), 14, 0, TAU, 32, Color.WHITE, 2)
	if preview.size() > 1:
		var points := PackedVector2Array()
		for cell in preview:
			points.append(tiles.map_to_local(cell))
		var color := Color("f7df9a") if state.path_cost(preview) <= state.movement_remaining else Color("eb7770")
		draw_polyline(points, color, 3)
