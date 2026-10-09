extends SceneTree
const Log = preload("res://src/common/play_log.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func read_events(path: String) -> Array:
	var result := []
	for line in FileAccess.get_file_as_string(path).split("\n", false):
		var event: Variant = JSON.parse_string(line)
		check(event is Dictionary, "Each event is valid JSON")
		if event is Dictionary:
			result.append(event)
	return result
func run() -> void:
	root.size = Vector2i(1280, 720)
	Log.test_path = "user://play_log_test_%d.jsonl" % OS.get_process_id()
	var path := Log.test_path
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.selected = true
	for cell in [Vector2i(3,10), Vector2i(19,19)]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = map.get_canvas_transform() * map.tiles.map_to_local(cell)
		map._unhandled_input(event)
	map.state.move_to(Vector2i(6,11), true)
	map._refresh()
	map._open_poi(Vector2i(6,11))
	map.dialogue.client.config.dev_flags.offline_mode = true
	map.dialogue.submit("¿Cómo llego al monasterio?")
	Log.write("redaction_test", {"api_key":"never-log-me", "nested":{"authorization":"never-log-me", "prompt":"never-log-me"}, "text":"texto del jugador"})
	var events := read_events(path)
	var routes: Array = events.filter(func(e: Dictionary) -> bool: return e.event == "route_attempt")
	check(routes.size() == 2 and routes[0].data.accepted and not routes[1].data.accepted, "Accepted and rejected routes are logged")
	check(routes[0].data.before.cell == [2.0,10.0] and routes[0].context.cell == [3.0,10.0], "Route has before and after coordinates")
	check(events.any(func(e: Dictionary) -> bool: return e.event == "talk_attempt" and e.data.text == "¿Cómo llego al monasterio?"), "Full player message is retained")
	check(events.any(func(e: Dictionary) -> bool: return e.event == "talk" and not e.data.reply.is_empty() and e.data.source == "authored"), "Reply and fallback source are retained")
	check(not FileAccess.get_file_as_string(path).contains("never-log-me"), "Nested credentials and prompts are redacted")
	for i in events.size():
		check(events[i].seq == i + 1 and events[i].session == events[0].session, "Session has a stable ID and ordered events")
	map.queue_free()
	await process_frame
	Log.test_path = "user://play_log_orders_%d.jsonl" % OS.get_process_id()
	var orders_path := Log.test_path
	map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	for resource in map.state.resources:
		map.state.resources[resource] = 10000
	var panel = map.strategy_panel
	panel.open_site(map.state)
	for i in panel.entries.item_count:
		if panel.entries.get_item_metadata(i).id == "council_hall":
			panel.entries.select(i)
			panel.entries.item_selected.emit(i)
	panel.input.text = "Sí"
	panel.send_button.pressed.emit()
	var models: Dictionary = map.state.economy.current_models(map.state, "build", "council_hall", 1)
	for phase in ["request", "price", "confirm"]:
		panel.input.text = models[phase]
		panel.send_button.pressed.emit()
	events = read_events(orders_path)
	check(events.filter(func(e: Dictionary) -> bool: return e.event == "order_attempt").size() == 4, "Every construction attempt is logged")
	check(events.any(func(e: Dictionary) -> bool: return e.event == "order" and not e.data.ok and not e.data.message.is_empty()), "Construction rejection includes feedback")
	check(events.any(func(e: Dictionary) -> bool: return e.event == "order" and e.data.committed and e.data.before.resources.gold > e.data.after.resources.gold and e.data.after.buildings.LOC01.has("council_hall")), "Committed building records cost and resulting town")
	check(events.any(func(e: Dictionary) -> bool: return e.event == "ui_action"), "Other UI buttons are observable")
	var file := FileAccess.open(orders_path, FileAccess.READ_WRITE)
	file.seek_end()
	file.store_line(JSON.stringify({"padding":"x".repeat(Log.MAX_BYTES)}))
	file.close()
	var old_size := FileAccess.get_file_as_bytes(orders_path).size()
	Log.write("rotation_test", {})
	check(Log.output_path != orders_path and FileAccess.get_file_as_bytes(orders_path).size() == old_size, "Large logs continue in a new part without overwriting history")
	var rotated := Log.output_path
	map.queue_free()
	await process_frame
	Log.owner = null
	Log.output_path = ""
	Log.test_path = ""
	for item in [path, orders_path, rotated]:
		DirAccess.remove_absolute(item)
	print("Play log checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
