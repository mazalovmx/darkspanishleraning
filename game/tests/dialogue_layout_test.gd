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
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.state.move_to(Vector2i(6, 11), true)
	map._refresh()
	map._open_poi(Vector2i(6, 11))
	var d = map.dialogue
	d.client.config.dev_flags.offline_mode = true
	var long_text := "Una historia muy larga con palabras, pistas y explicaciones. ".repeat(250)
	d.transcript.text = long_text
	d.hint.text = long_text
	d.feedback.text = long_text
	map.poi_description.text = long_text
	for frame in 8:
		await process_frame
	var screen := Rect2(Vector2.ZERO, Vector2(1280, 720))
	for control: Control in [d.input, d.send_button, map.poi_close]:
		check(screen.encloses(control.get_global_rect()), "Long text keeps reply and close controls on screen: " + str(control.get_global_rect()))
	check(d.transcript.get_v_scroll_bar().max_value > d.transcript.get_v_scroll_bar().page, "History can scroll")
	var help: TabContainer = d.feedback.get_parent().get_parent()
	help.current_tab = 1
	for frame in 4:
		await process_frame
	check(screen.encloses(d.send_button.get_global_rect()), "Long correction page keeps send visible")
	check(d.feedback.get_parent().get_v_scroll_bar().max_value > d.feedback.get_parent().get_v_scroll_bar().page, "Corrections can scroll")
	d.input.text = "Gracias"
	d.send_button.disabled = false
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = d.send_button.get_global_rect().get_center()
		click.pressed = pressed
		root.push_input(click, true)
	check(d.histories.LOC11.size() == 1, "Send is mouse-clickable after long content")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://dialogue-layout-preview.png")
	map.queue_free()
	await process_frame
	print("Dialogue layout checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)