extends Node2D

const WorldState = preload("res://src/world/world_state.gd")
const SaveGame = preload("res://src/save/save_game.gd")
const CELL_SIZE := 32
const COLORS := {"road": Color("bda474"), "grass": Color("69764b"),
	"forest": Color("304a37"), "marsh": Color("64716b"), "mountain": Color("555660"),
	"water": Color("365f80"), "field": Color("a29446"), "ruins": Color("80716a"),
	"snow": Color("ccd7d7")}
@export var initial_map_id := "prototype_20x20_v1"
var state: WorldState = WorldState.new()
var persistence_enabled := true
@export var save_path := SaveGame.PATH
var save_locked := false
var save_button := Button.new()
var load_button := Button.new()
var save_notice := Label.new()
var save_confirm := ConfirmationDialog.new()
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
var market = preload("res://src/economy/market_panel.gd").new()
var army_notice := Label.new()
var arena = preload("res://src/combat/stack_arena.tscn").instantiate()
var hero_buttons: Dictionary = {}
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
	_build_ui()
	_refresh()
	_update_preview()

	if persistence_enabled:
		_load_game(true)

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
	for cell: Vector2i in state.fog:
		tiles.set_cell(cell, 0, Vector2i(names.find(state.terrain[cell.y][cell.x]), 0))

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
		margin.add_theme_constant_override("margin_" + side, 16)
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
		button.pressed.connect(_switch_hero.bind(id))
		portraits.add_child(button)
		hero_buttons[id] = button
		hero_index += 1
	box.add_child(status)
	army_notice.add_theme_font_size_override("font_size", 14)
	army_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(army_notice)
	var instructions := Label.new()
	instructions.text = "Clic en el héroe: seleccionar\nClic en una casilla: mover\nBotón derecho: deseleccionar\nArrastrar botón central: cámara\nRueda: acercar / alejar"
	instructions.add_theme_font_size_override("font_size", 15)
	box.add_child(instructions)
	box.add_child(route_info)
	route_info.custom_minimum_size = Vector2(260, 60)
	route_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_button.text = "Terminar turno"
	end_button.pressed.connect(_end_turn)
	var turns := HBoxContainer.new()
	end_button.add_theme_font_size_override("font_size",15)
	end_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	turns.add_child(end_button)
	campaign_button.text = "Expedientes"
	campaign_button.add_theme_font_size_override("font_size",15)
	campaign_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	campaign_button.visible = state.map_id == "province_160x120_v1"
	campaign_button.pressed.connect(func():
		if arena.visible or market.visible or notebook.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or dialogue.client.busy:
			return
		campaign_journal.open_journal(state)
		end_button.disabled = true
		_update_preview())
	turns.add_child(campaign_button)
	box.add_child(turns)
	equipment_button.text = "Equipo y almas"
	equipment_button.pressed.connect(func():
		if poi_modal.visible or arena.visible or market.visible or notebook.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or dialogue.client.busy:
			return
		equipment_panel.open_inventory(state)
		end_button.disabled = true
		_update_preview())
	box.add_child(equipment_button)
	var saves := HBoxContainer.new()
	save_button.text = "Guardar"
	load_button.text = "Cargar"
	save_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	load_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_button.pressed.connect(func(): _save_game())
	load_button.pressed.connect(func(): _load_game())
	saves.add_child(save_button)
	saves.add_child(load_button)
	notebook_button.text = "Cuaderno"
	notebook_button.add_theme_font_size_override("font_size", 15)
	notebook_button.pressed.connect(func():
		if campaign_journal.visible or strategy_panel.visible or equipment_panel.visible:
			return
		notebook.open_journal(state)
		end_button.disabled = true
		_update_preview())
	saves.add_child(notebook_button)
	language_button.text = "Español"
	language_button.pressed.connect(func():
		if not arena.visible and not dialogue.client.busy and not market.visible and not notebook.visible and not campaign_journal.visible and not strategy_panel.visible and not equipment_panel.visible:
			lessons.open_course(state)
			end_button.disabled = true
			_update_preview())
	saves.add_child(language_button)
	for control in [save_button, load_button, notebook_button, language_button]:
		control.add_theme_font_size_override("font_size", 13)
	box.add_child(saves)
	save_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	save_notice.add_theme_font_size_override("font_size", 14)
	box.add_child(save_notice)
	layer.add_child(save_confirm)
	save_confirm.title = "Reemplazar archivo"
	save_confirm.dialog_text = "El archivo no se puede cargar. ¿Guardar esta partida en su lugar?"
	save_confirm.confirmed.connect(func(): _save_game(false, true))
	dialogue.request_started.connect(func():
		save_button.disabled = true
		load_button.disabled = true)
	dialogue.turn_finished.connect(_on_dialogue_finished)
	var legend := Label.new()
	legend.text = "COSTE POR CASILLA\nCamino / pradera / campo: 1\nBosque / ruinas / nieve: 2\nPantano: 3\nAgua / montaña: impasable"
	legend.add_theme_font_size_override("font_size", 14)
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
	var actions := HBoxContainer.new()
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
	strategy_button.text = "Asentamiento"
	strategy_button.pressed.connect(func():
		if not dialogue.client.busy:
			strategy_panel.open_site(state))
	actions.add_child(strategy_button)
	actions.add_child(poi_close)
	poi_modal.hide()

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
	strategy_button.visible = state.map_id == "province_160x120_v1" and location.id in state.economy.catalog.towns
	market_button.visible = location.id == "LOC11"
	inspect_button.visible = location.id == "LOC01"
	battle_button.visible = location.id == "LOC11" and state.evidence.has_evidence("travel_food") and state.encounters.get("opening_road", {}).get("outcome", "") != "victory"
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

	_save_game(true)

func _input(event: InputEvent) -> void:
	if arena.visible:
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
	if poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		_refresh()
		return
	if not state.select_hero(id):
		_refresh()
		return
	selected = true
	camera.position = tiles.map_to_local(state.hero_cell)
	_clamp_camera()
	_refresh()
	_update_preview()
	_save_game(true)

func _unhandled_input(event: InputEvent) -> void:
	if poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_F1, KEY_F2, KEY_F3]:
		_switch_hero(["inquisitor", "smuggler", "survivor"][event.keycode - KEY_F1])
		get_viewport().set_input_as_handled()
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
	camera.position = camera.position.clamp(Vector2.ZERO, Vector2(state.grid.region.size) * CELL_SIZE)
	camera.force_update_scroll()

func _end_turn() -> void:
	if poi_modal.visible or notebook.visible or arena.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible:
		return
	state.end_turn()
	_save_game(true)
	_refresh()
	_update_preview()

func _refresh() -> void:
	var names := COLORS.keys()
	for cell: Vector2i in state.fog:
		tiles.set_cell(cell, 0, Vector2i(names.find(state.terrain[cell.y][cell.x]), 0))
	army_notice.text = "Oro: %d · Madera: %d · Mineral: %d\nMercurio: %d · Azufre: %d\nCristal: %d · Gemas: %d · Ejército: %d/7" % [state.resources.gold,state.resources.wood,state.resources.ore,state.resources.mercury,state.resources.sulfur,state.resources.crystal,state.resources.gems,state.army.size()]
	hero.position = tiles.map_to_local(state.hero_cell)
	hero.modulate = Color(state.party.active().definition.color)
	for id in hero_buttons:
		hero_buttons[id].set_pressed_no_signal(id == state.party.active_id)
		hero_buttons[id].disabled = not state.party.heroes[id].unlocked
	status.text = "%s · Día %d\nMovimiento: %d / %d\n%s" % [state.party.active().definition.short_name, state.day,
		state.movement_remaining, state.MOVEMENT_MAX + int(state.equipment.bonuses(state.party.active_id).world_movement),
		"Héroe seleccionado" if selected else "Selecciona al héroe"]
	queue_redraw()

func _update_preview() -> void:
	hovered = tiles.local_to_map(tiles.get_global_transform_with_canvas().affine_inverse() * pointer)
	preview.clear()
	if selected and not poi_modal.visible and not notebook.visible and not arena.visible and not market.visible and not lessons.visible and not campaign_journal.visible and not strategy_panel.visible and not equipment_panel.visible:
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
	if not site.is_empty():
		route_info.text = "Mina de %s · +%d/día\n%s" % [state.economy.catalog.resource_names[site.resource],site.daily_income,route_info.text]
	var gate := state.gate_at(hovered)
	if not gate.is_empty() and gate.closed and state.fog_at(hovered) != WorldState.Fog.UNKNOWN:
		route_info.text = gate.message
	var location := state.location_at(hovered)
	if not location.is_empty():
		route_info.text = str(location.name) + "\n" + route_info.text
	queue_redraw()

func _draw() -> void:
	var inverse := get_global_transform_with_canvas().affine_inverse()
	var first := Vector2i((inverse * Vector2.ZERO / CELL_SIZE).floor())
	var last := Vector2i((inverse * get_viewport_rect().size / CELL_SIZE).ceil()) + Vector2i.ONE
	var visible_region := Rect2i(first, last - first).intersection(state.grid.region)
	for y in range(visible_region.position.y, visible_region.end.y):
		for x in range(visible_region.position.x, visible_region.end.x):
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
		draw_string(ThemeDB.fallback_font, center + Vector2(-6, 6), str(location.name).left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 16, color)
	for site: Dictionary in state.map_data.get("resource_sites", []):
		var cell := Vector2i(site.position[0], site.position[1])
		if state.fog_at(cell) == WorldState.Fog.UNKNOWN:
			continue
		var center := tiles.map_to_local(cell)
		draw_colored_polygon(PackedVector2Array([center + Vector2(0,-8), center + Vector2(8,0), center + Vector2(0,8), center + Vector2(-8,0)]), Color("72c9b0") if state.economy.mines.has(site.id) else Color("bf9670"))
	for gate: Dictionary in state.map_data.get("gates", []):
		var cell := Vector2i(gate.position[0], gate.position[1])
		if state.fog_at(cell) != WorldState.Fog.UNKNOWN and state.gate_at(cell).closed:
			var center := tiles.map_to_local(cell)
			draw_line(center - Vector2(12,0), center + Vector2(12,0), Color("df8571"), 4)
	var marker_index := 0
	for id in state.party.heroes:
		var member = state.party.heroes[id]
		if id == state.party.active_id or not member.unlocked:
			continue
		var center := tiles.map_to_local(member.cell)
		if member.cell == state.hero_cell:
			center += Vector2(-12 + marker_index * 24, 12)
		var color := Color(member.definition.color)
		draw_circle(center, 8, color)
		draw_string(ThemeDB.fallback_font, center + Vector2(-5, 5), str(member.definition.short_name).left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("17202b"))
		marker_index += 1
	if selected:
		draw_arc(tiles.map_to_local(state.hero_cell), 14, 0, TAU, 32, Color.WHITE, 2)
	if preview.size() > 1:
		var points := PackedVector2Array()
		for cell in preview:
			points.append(tiles.map_to_local(cell))
		var color := Color("f7df9a") if state.path_cost(preview) <= state.movement_remaining else Color("eb7770")
		draw_polyline(points, color, 3)

func _save_game(automatic := false, replace_invalid := false) -> void:
	if not persistence_enabled:
		return
	if arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		if not automatic:
			save_notice.text = "Espera a que termine la respuesta."
		return
	if save_locked and not replace_invalid:
		if not automatic:
			save_confirm.popup_centered()
		return
	var error: String = SaveGame.write_save(state, save_path)
	if error.is_empty():
		save_locked = false
		save_notice.text = "Partida guardada."
	else:
		save_notice.text = "No se pudo guardar. Inténtalo de nuevo."

func _load_game(startup := false) -> void:
	if not persistence_enabled or arena.visible or dialogue.client.busy or not dialogue.pending_location.is_empty():
		return
	var result: Dictionary = SaveGame.read_save(save_path)
	if not result.has("state"):
		if result.error != "missing":
			save_locked = true
			save_notice.text = "Archivo no válido. Guardado automático pausado."
		elif not startup:
			save_notice.text = "Todavía no hay una partida guardada."
		return
	state = result.state
	tiles.clear()
	camera.offset = Vector2(160, 0) if state.map_id == "province_160x120_v1" else Vector2.ZERO
	dialogue.world_state = state
	notebook.hide()
	market.hide()
	lessons.hide()
	campaign_journal.hide()
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
	save_notice.text = "Partida cargada."

func _on_dialogue_finished() -> void:
	save_button.disabled = false
	load_button.disabled = false
	_save_game(true)

func _start_battle(id := "opening_road") -> void:
	if dialogue.client.busy or notebook.visible or market.visible or lessons.visible or campaign_journal.visible or strategy_panel.visible or equipment_panel.visible or not state.begin_encounter(id):
		save_notice.text = "Necesitas un ejército, dos puntos de movimiento y acceso al encuentro."
		return
	poi_modal.hide()
	save_button.disabled = true
	load_button.disabled = true
	notebook_button.disabled = true
	language_button.disabled = true
	end_button.disabled = true
	arena.present(state.active_battle, str(state.active_battle.data.opening.name))
	_update_preview()

func _on_battle_finished(_outcome: String, _survivors: Array) -> void:
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
	var site := state.resource_at(state.hero_cell)
	if not site.is_empty():
		strategy_panel.open_site(state,site.id)
		end_button.disabled = true