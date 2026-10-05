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
var poi_modal := ColorRect.new()
var poi_title := Label.new()
var poi_description := Label.new()
var poi_close := Button.new()
var dialogue = preload("res://src/dialogue/authored_dialogue.gd").new()

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
	_build_poi_window(layer, panel.theme)
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

func _build_poi_window(layer: CanvasLayer, ui_theme: Theme) -> void:
	poi_modal.color = Color(0, 0, 0, 0.7)
	layer.add_child(poi_modal)
	poi_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	poi_modal.theme = ui_theme
	poi_modal.z_index = 10
	var panel := PanelContainer.new()
	panel.position = Vector2(260, 70)
	panel.size = Vector2(760, 580)
	poi_modal.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	margin.add_child(box)
	poi_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	poi_title.custom_minimum_size.x = 712
	box.add_child(poi_title)
	poi_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(poi_description)
	dialogue.world_state = state
	box.add_child(dialogue)
	poi_close.text = "Volver al mapa"
	poi_close.pressed.connect(_close_poi)
	box.add_child(poi_close)
	poi_modal.hide()

func _open_poi(cell: Vector2i) -> void:
	if cell != state.hero_cell:
		return
	var location := state.location_at(cell)
	if location.is_empty():
		return
	poi_title.text = location.name
	poi_description.text = location.description
	dialogue.open_conversation(location.id)
	preview.clear()
	end_button.disabled = true
	poi_modal.show()
	poi_close.grab_focus()
	queue_redraw()

func _close_poi() -> void:
	poi_modal.hide()
	end_button.disabled = false
	poi_close.release_focus()
	_update_preview()

func _input(event: InputEvent) -> void:
	# Handle Escape before LineEdit consumes it to release its keyboard focus.
	if poi_modal.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_poi()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if poi_modal.visible:
		return
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
					state.move_to(cell, true)
				_refresh()
				_update_preview()
				_open_poi(cell)
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
	if poi_modal.visible:
		return
	state.end_turn()
	_refresh()
	_update_preview()

func _refresh() -> void:
	var names := COLORS.keys()
	for y in state.grid.region.size.y:
		for x in state.grid.region.size.x:
			var cell := Vector2i(x, y)
			if state.fog_at(cell) == WorldState.Fog.UNKNOWN:
				tiles.erase_cell(cell)
			else:
				tiles.set_cell(cell, 0, Vector2i(names.find(state.terrain[y][x]), 0))
	hero.position = tiles.map_to_local(state.hero_cell)
	status.text = "Día %d\nMovimiento: %d / %d\n%s" % [state.day,
		state.movement_remaining, state.MOVEMENT_MAX,
		"Héroe seleccionado" if selected else "Selecciona al héroe"]
	queue_redraw()

func _update_preview() -> void:
	hovered = tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer)
	preview.clear()
	if selected and not poi_modal.visible:
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
	var location := state.location_at(hovered)
	if not location.is_empty():
		route_info.text = str(location.name) + "\n" + route_info.text
	queue_redraw()

func _draw() -> void:
	for y in state.grid.region.size.y:
		for x in state.grid.region.size.x:
			var cell := Vector2i(x, y)
			var visibility := state.fog_at(cell)
			if visibility != WorldState.Fog.VISIBLE:
				var shade := Color("171c25") if visibility == WorldState.Fog.UNKNOWN else Color(0, 0, 0, 0.48)
				draw_rect(Rect2(Vector2(cell) * CELL_SIZE, Vector2.ONE * CELL_SIZE), shade)
	for location: Dictionary in state.locations:
		var cell := Vector2i(location.position[0], location.position[1])
		if state.fog_at(cell) == WorldState.Fog.UNKNOWN:
			continue
		var center := tiles.map_to_local(cell)
		var color := Color("d9b875") if location.kind == "inn" else Color("cbd3eb")
		if state.fog_at(cell) == WorldState.Fog.EXPLORED:
			color = color.darkened(0.4)
		draw_rect(Rect2(center - Vector2(12, 12), Vector2(24, 24)), color, false, 2)
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), "P" if location.kind == "inn" else "M", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	if selected:
		draw_arc(tiles.map_to_local(state.hero_cell), 14, 0, TAU, 32, Color.WHITE, 2)
	if preview.size() > 1:
		var points := PackedVector2Array()
		for cell in preview:
			points.append(tiles.map_to_local(cell))
		var color := Color("f7df9a") if state.path_cost(preview) <= state.movement_remaining else Color("eb7770")
		draw_polyline(points, color, 3)
