extends SceneTree

const WorldState = preload("res://src/world/world_state.gd")
var failures := 0
var checks := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func click_map(map: Node2D, cell: Vector2i) -> void:
	var screen: Vector2 = map.get_canvas_transform() * map.tiles.map_to_local(cell)
	var motion := InputEventMouseMotion.new()
	motion.position = screen
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.position = screen
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)

func run() -> void:
	var state = WorldState.new()
	check(state.grid.region.size == Vector2i(20, 20), "Prototype dimensions")
	check(state.terrain_cost(Vector2i(3, 10)) == 1, "Road costs one")
	check(state.terrain_cost(Vector2i(4, 9)) == 2, "Forest costs two")
	check(state.terrain_cost(Vector2i(10, 14)) == 3, "Marsh costs three")
	check(state.terrain_cost(Vector2i(5, 5)) == 1, "Field costs one")
	check(state.terrain_cost(Vector2i(2, 14)) == 2, "Ruins costs two")
	check(state.terrain_cost(Vector2i(14, 1)) == 2, "Snow costs two")
	check(state.move_to(Vector2i(3, 10)), "Road move accepted")
	check(state.movement_remaining == 17, "Road movement deducted")
	check(state.move_to(Vector2i(4, 10)), "Move below forest")
	check(state.move_to(Vector2i(4, 9)), "Forest move accepted")
	check(state.movement_remaining == 14, "Forest movement deducted")
	var before: Vector2i = state.hero_cell
	for cell in [Vector2i(11, 2), Vector2i(13, 6), Vector2i(-1, 5), Vector2i(20, 5)]:
		check(not state.move_to(cell), "Blocked/out-of-bounds move rejected")
	check(state.hero_cell == before and state.movement_remaining == 14, "Rejected moves leave state unchanged")
	var detour: Array[Vector2i] = state.path_to(Vector2i(8, 9))
	check(state.path_cost(detour) == 6, "Weighted path prefers cheaper road over forest")
	for i in range(1, detour.size()):
		var delta: Vector2i = detour[i] - detour[i - 1]
		check(absi(delta.x) + absi(delta.y) == 1, "No diagonal steps")
	state.movement_remaining = 1
	check(not state.move_to(Vector2i(8, 9)), "Over-budget route rejected")
	check(state.movement_remaining == 1 and state.hero_cell == before, "Over-budget move is atomic")
	check(not state.move_to(before), "Same-cell move is a no-op")
	state.end_turn()
	check(state.day == 2 and state.movement_remaining == 18 and state.hero_cell == before, "New day restores movement, preserves location")
	var fresh = WorldState.new()
	check(fresh.move_to(Vector2i(19, 10)), "Long road move accepted")
	check(fresh.move_to(Vector2i(19, 11)) and fresh.movement_remaining == 0, "Exact budget can be spent")
	check(not fresh.move_to(Vector2i(19, 12)), "Exhausted hero cannot move")
	var around_water: Array[Vector2i] = fresh.path_to(Vector2i(12, 7))
	check(not around_water.is_empty(), "Route around water exists")
	for cell in around_water:
		check(fresh.terrain_cost(cell) > 0, "Route never enters blocked terrain")
	# Block every neighbor to check unreachable destinations.
	for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
		state.grid.set_point_solid(state.hero_cell + offset, true)
	check(state.path_to(Vector2i(0, 0)).is_empty(), "Unreachable destination has no path")

	var map = load("res://src/world/world_map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	await process_frame
	check(map.tiles.get_used_cells().size() == 400, "All map cells rendered")
	check(map.camera.is_current(), "Prototype camera active")
	click_map(map, Vector2i(3, 10))
	check(map.state.hero_cell == Vector2i(2, 10), "Movement requires hero selection")
	click_map(map, Vector2i(2, 10))
	check(map.selected, "Mouse click selects hero")
	click_map(map, Vector2i(5, 10))
	check(map.state.hero_cell == Vector2i(5, 10) and map.state.movement_remaining == 15, "Mouse click moves and spends points")
	check(map.hero.position == map.tiles.map_to_local(map.state.hero_cell), "Sprite reflects state")
	check(map.preview.size() == 1, "Preview refreshed after move")
	map.end_button.pressed.emit()
	check(map.state.day == 2 and map.state.movement_remaining == 18, "End-turn button wired")
	var zoom := InputEventMouseButton.new()
	zoom.position = Vector2(300, 300)
	zoom.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom.pressed = true
	root.push_input(zoom, true)
	check(map.camera.zoom.x > 1, "Mouse wheel zooms")
	var pan := InputEventMouseMotion.new()
	pan.position = Vector2(300, 300)
	pan.relative = Vector2(32, 0)
	pan.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	var camera_before: Vector2 = map.camera.position
	root.push_input(pan, true)
	check(map.camera.position.x < camera_before.x, "Middle drag pans camera")
	click_map(map, Vector2i(6, 10))
	check(map.state.hero_cell == Vector2i(6, 10), "Picking remains correct after pan and zoom")
	var deselect := InputEventMouseButton.new()
	deselect.position = Vector2(300, 300)
	deselect.button_index = MOUSE_BUTTON_RIGHT
	deselect.pressed = true
	root.push_input(deselect, true)
	check(not map.selected and map.preview.is_empty(), "Right click clears selection and route")
	click_map(map, map.state.hero_cell)
	var hover := InputEventMouseMotion.new()
	hover.position = map.get_canvas_transform() * map.tiles.map_to_local(Vector2i(8, 9))
	root.push_input(hover, true)
	check(map.preview.size() > 1 and map.route_info.text.contains("Ruta:"), "Hover shows route and cost")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/world-preview.png")
	map.queue_free()
	await process_frame
	print("World map checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
