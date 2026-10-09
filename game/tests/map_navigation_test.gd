extends SceneTree
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var cell: Vector2i = map.state.hero_cell
	var day: int = map.state.day
	var movement: int = map.state.movement_remaining
	map.camera.position = Vector2(2000, 1600)
	map._clamp_camera()
	var anchor := Vector2(410, 310)
	var before: Vector2 = map.get_canvas_transform().affine_inverse() * anchor
	var wheel := InputEventMouseButton.new()
	wheel.position = anchor
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	root.push_input(wheel, true)
	check(is_equal_approx(map.camera.zoom.x, 1.15), "Wheel zooms map")
	check(before.distance_to(map.get_canvas_transform().affine_inverse() * anchor) < 0.1, "Cursor keeps the same world point during zoom")
	var camera_before: Vector2 = map.camera.position
	var drag := InputEventMouseMotion.new()
	drag.position = anchor
	drag.relative = Vector2(46, -23)
	drag.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	root.push_input(drag, true)
	check(map.camera.position.distance_to(camera_before - drag.relative / map.camera.zoom) < 0.1, "Middle drag pans in screen units")
	var key := InputEventKey.new()
	key.keycode = KEY_HOME
	key.pressed = true
	root.push_input(key, true)
	check(map.camera.position == map.tiles.map_to_local(cell) and map.selected, "Home returns to and selects the hero")
	key.keycode = KEY_SPACE
	Input.parse_input_event(key)
	await process_frame
	var click := InputEventMouseButton.new()
	click.position = anchor
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	map._unhandled_input(click)
	camera_before = map.camera.position
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	map._unhandled_input(drag)
	check(map.camera.position.distance_to(camera_before - drag.relative / map.camera.zoom) < 0.1, "Space-left drag pans")
	key.pressed = false
	Input.parse_input_event(key)
	await process_frame
	check(map.state.hero_cell == cell and map.state.day == day and map.state.movement_remaining == movement and map.state.ghosts.plan == null, "Navigation neither moves heroes nor spends turns nor creates orders")
	map._zoom_at(100, anchor)
	check(map.camera.zoom.x == 2.5, "Zoom has an upper bound")
	map._zoom_at(0.001, anchor)
	check(is_equal_approx(map.camera.zoom.x, 0.65), "Zoom has a lower bound")
	map._open_poi(cell)
	camera_before = map.camera.position
	root.push_input(wheel, true)
	key.keycode = KEY_HOME
	key.pressed = true
	root.push_input(key, true)
	check(map.camera.position == camera_before and is_equal_approx(map.camera.zoom.x, 0.65), "Conversation blocks map navigation")
	map._close_poi()
	map._zoom_at(1.75 / map.camera.zoom.x, anchor)
	map.center_button.pressed.emit()
	check(map.camera.position == map.tiles.map_to_local(cell), "Visible center button returns to hero")
	check(is_equal_approx(maxf(map.hero.texture.get_width(), map.hero.texture.get_height()) * map.hero.scale.x, 34), "Hero silhouette uses a readable map size")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://map-navigation-preview.png")
	map.queue_free()
	await process_frame
	print("Map navigation checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)