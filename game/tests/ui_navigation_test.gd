extends SceneTree
## Keyboard reach of the map windows and the shared UI tokens (docs/UI_PLAN.md, stages 1-2).
const Tokens = preload("res://src/common/ui_tokens.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func press(code: Key, ctrl := false) -> void:
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.ctrl_pressed = ctrl
		event.pressed = down
		root.push_input(event, true)
func run() -> void:
	root.size = Vector2i(1280, 720)
	# Tokens: text colours must be readable on the page they are used on.
	var paper := Color("d6b684")
	var wood := Color("93693f")
	for pair in [["ink", Tokens.INK], ["faded ink", Tokens.INK_FADED], ["ok", Tokens.OK], ["warning", Tokens.WARN], ["error", Tokens.ERROR], ["focus", Tokens.FOCUS]]:
		check(Tokens.contrast(pair[1], paper) >= 4.5, "Readable on parchment (4.5:1): %s = %.2f" % [pair[0], Tokens.contrast(pair[1], paper)])
	check(Tokens.contrast(Tokens.FOCUS_ON_WOOD, wood) >= 3.0, "Focus frame stands out on wood: %.2f" % Tokens.contrast(Tokens.FOCUS_ON_WOOD, wood))
	check(Tokens.BODY >= 18 and Tokens.CAPTION >= 16 and Tokens.PAD % Tokens.UNIT == 0 and Tokens.GAP_GROUP % Tokens.UNIT == 0, "Sizes follow the 8 px unit and the 18 px body text")
	check(is_equal_approx(Tokens.contrast(Color.WHITE, Color.BLACK), 21.0), "Contrast formula matches the WCAG extremes")
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var focus: StyleBox = null
	for child in map.campaign_journal.get_children():
		if child is PanelContainer:
			focus = child.theme.get_stylebox("focus", "Button")
	check(focus is StyleBoxFlat and focus.border_width_left >= 2 and not focus.draw_center, "Buttons on parchment show a keyboard focus frame")
	check(map.end_button.get_theme_stylebox("focus") is StyleBoxFlat, "Buttons on the map panel show a keyboard focus frame")
	# Each window opens with its key, blocks the others, and closes with Esc.
	var day: int = map.state.day
	for pair in [[KEY_J, map.campaign_journal], [KEY_C, map.notebook], [KEY_L, map.lessons], [KEY_I, map.equipment_panel], [KEY_H, map.help_panel]]:
		var window: CanvasItem = pair[1]
		press(pair[0])
		check(window.visible and map._modal_open(), "Key opens its window: " + OS.get_keycode_string(pair[0]))
		press(KEY_J)
		press(KEY_H)
		press(KEY_E)
		var open := 0
		for other in [map.campaign_journal, map.notebook, map.lessons, map.equipment_panel, map.help_panel]:
			open += int(other.visible)
		check(open == 1 and map.state.day == day, "An open window ignores the map keys: " + OS.get_keycode_string(pair[0]))
		press(KEY_ESCAPE)
		check(not window.visible and not map._modal_open(), "Esc closes exactly that window: " + OS.get_keycode_string(pair[0]))
	check(not map.end_button.disabled, "The map is usable again after the last window closes")
	# The help page says in plain text what the tooltips say on hover.
	map.help_button.pressed.emit()
	var help: String = map.help_text.text
	check(map.help_panel.visible and help.contains("BOTONES DEL MAPA") and help.contains("· Tareas [J] — ") and help.contains("· Guardar partida [Ctrl+S] — ") and help.contains("Pantano: 3"), "Help lists buttons with their keys and the terrain costs")
	check(not help.contains("· Caballeros"), "Help does not describe a button that is not offered yet")
	check(map.end_button.tooltip_text.ends_with("Tecla: E") and map.save_button.tooltip_text.ends_with("Tecla: Ctrl+S"), "Tooltips name the same keys")
	map._end_turn()
	check(map.state.day == day, "The day cannot end behind the help page")
	press(KEY_ESCAPE)
	# The map panel says what the hovered cell is and what is still open here.
	map.selected = false
	map.pointer = map.get_canvas_transform() * map.tiles.map_to_local(map.state.hero_cell + Vector2i(1, 0))
	map._update_preview()
	check(map.route_info.text.contains(" por casilla") or map.route_info.text.contains("no se puede cruzar"), "Hovering a known cell names its terrain and cost: " + map.route_info.text)
	map._refresh()
	check(map.objective_button.text == "▶ AHORA: Santa Lucerna: pulsa «Examinar pertenencias»." and map._unfinished_here().is_empty(), "The objective line is one short sentence at the start")
	map.selected = true
	map.pointer = map.get_canvas_transform() * map.tiles.map_to_local(map.state.hero_cell + Vector2i(2, 0))
	map._update_preview()
	check(map.route_info.text.begins_with("Ruta: ") and map.route_info.text.contains("te quedan %d" % map.state.movement_remaining), "A planned route shows its cost beside the points left")
	map.selected = false
	# The end-of-day button can never scroll away, whatever the panel has to show.
	var scroller: Node = map.objective_button.get_parent().get_parent()
	check(scroller is ScrollContainer and not scroller.is_ancestor_of(map.end_button), "End of day sits outside the scrolling part of the panel")
	map.objective_button.text = "▶ AHORA: " + "texto muy largo ".repeat(40)
	await process_frame
	await process_frame
	check(Rect2(Vector2.ZERO, Vector2(root.size)).encloses(map.end_button.get_global_rect()) and map.end_button.is_visible_in_tree(), "End of day stays on screen under a very long objective")
	map._refresh()
	# Keys reach the text field, not the map, while the player is typing.
	map._open_poi(map.state.hero_cell)
	map.dialogue.input.grab_focus()
	press(KEY_J)
	press(KEY_E)
	check(not map.campaign_journal.visible and map.state.day == day, "Typing in a conversation never triggers a map key")
	map._close_poi()
	# Plain S pans the map; Ctrl+S is the save key and must not pan.
	check(InputMap.action_get_events("map_save")[0].ctrl_pressed and not InputMap.action_get_events("map_end_day")[0].ctrl_pressed, "Save needs Ctrl; the other keys do not")
	map.queue_free()
	await process_frame
	print("UI navigation checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
