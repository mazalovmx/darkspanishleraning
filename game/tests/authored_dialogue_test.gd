extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func run() -> void:
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	map.selected = true
	check(map.state.move_to(Vector2i(6, 11), true), "Reach inn")
	map._refresh()
	map._open_poi(Vector2i(6, 11))
	await process_frame
	var dialogue = map.dialogue
	dialogue.client.config.dev_flags.offline_mode = true
	check(dialogue.is_visible_in_tree(), "Dialogue opens in reached POI")
	check(dialogue.transcript.text.contains("El posadero:"), "NPC greeting shown")
	check(dialogue.feedback.text.contains("no disponible"), "No fabricated language evaluation")
	var points: int = map.state.movement_remaining
	var day: int = map.state.day
	dialogue.submit("   ")
	check(dialogue.histories.LOC11.is_empty(), "Blank message ignored")
	dialogue.input.grab_focus()
	for character in "¿Cómo llego al monasterio?":
		var letter := InputEventKey.new()
		letter.unicode = character.unicode_at(0)
		letter.pressed = true
		root.push_input(letter, true)
	check(dialogue.input.text == "¿Cómo llego al monasterio?", "Spanish punctuation and accents can be typed")
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	root.push_input(enter, true)
	check(dialogue.histories.LOC11.size() == 1, "Enter submits exactly once")
	check(dialogue.transcript.text.contains("Siga este camino"), "Authored directions reply displayed")
	check(dialogue.input.text.is_empty() and dialogue.send_button.disabled, "Input cleared after reply")
	var memory: Dictionary = map.state.npc_memory.get("innkeeper_prototype", {})
	check(memory.get("count") == 1 and memory.get("last_day") == day and memory.get("topics") == ["ask_route", "survival:directions"], "NPC remembers the talk, its topic and the survival exchange")
	check(not dialogue.transcript.text.contains("Otra vez"), "Greeting does not change inside the same transcript")
	var kept: Array = dialogue.histories.LOC11.duplicate(true)
	dialogue.histories.LOC11.clear()
	dialogue._render_history()
	check(dialogue.transcript.text.contains("Otra vez por aquí"), "Returning visitor gets the authored return greeting")
	dialogue.histories.LOC11 = kept
	dialogue._render_history()
	check(not map.state.npc_memory.has("lucio_salcedo"), "Memory is separate for each NPC")
	check(dialogue.reply_for("LOC11", "carambolahola") == dialogue.conversations.LOC11.fallback, "Keywords match whole words")
	check(dialogue.reply_for("LOC01", "¿QUIÉN ES?").contains("Lucio"), "Accented uppercase question recognized")
	check(dialogue.reply_for("LOC01", "Dime quién mató a Tomás") == dialogue.conversations.LOC01.fallback, "Unknown murder question gets authored fallback")
	check(dialogue.reply_for("missing", "hola").is_empty(), "Unknown NPC has no invented reply")
	dialogue.input.text = "Gracias"
	dialogue.send_button.disabled = false
	dialogue.send_button.pressed.emit()
	check(dialogue.histories.LOC11.size() == 2, "Send button submits")
	check(dialogue.transcript.text.contains("Buen viaje"), "Thanks reply displayed")
	map._close_poi()
	dialogue.submit("hola")
	check(dialogue.histories.LOC11.size() == 2, "Closed dialogue cannot receive submissions")
	map._open_poi(Vector2i(6, 11))
	check(dialogue.histories.LOC11.size() == 2 and dialogue.transcript.text.contains("Gracias"), "Reopen preserves conversation")
	dialogue.submit("[b]hola[/b]")
	check(dialogue.feedback.text.contains("entiende: ") and dialogue.feedback.text.contains("no hay modelo conectado"), "Offline turn names the reason and the authored topics")
	check(not dialogue.transcript.bbcode_enabled and dialogue.transcript.text.contains("[b]hola[/b]"), "Input displayed as literal text")
	for i in 15:
		dialogue.submit("Mensaje %d" % i)
	check(dialogue.histories.LOC11.size() == 12, "History capped at twelve exchanges")
	check(dialogue.histories.LOC11[0].player == "Mensaje 3", "Oldest exchanges discarded first")
	dialogue.submit("a".repeat(500))
	check(dialogue.histories.LOC11.back().player.length() == 300, "Submission length bounded")
	check(map.state.movement_remaining == points and map.state.day == day, "Dialogue cannot spend points or advance day")
	map._close_poi()
	map.state.move_to(Vector2i(7, 10), true)
	map.state.move_to(Vector2i(12, 10), true)
	map._refresh()
	map._open_poi(Vector2i(12, 10))
	check(dialogue.histories.LOC01.is_empty() and not dialogue.transcript.text.contains("Mensaje"), "NPC logs isolated")
	dialogue.input.text = "¿Quién es usted?"
	dialogue.send_button.disabled = false
	dialogue.send_button.pressed.emit()
	check(dialogue.transcript.text.contains("Me llamo Lucio"), "Monastery conversation works")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape, true)
	check(not map.poi_modal.visible, "Escape closes while input has focus")
	map._open_poi(Vector2i(12, 10))
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://dialogue-preview.png")
	map.queue_free()
	await process_frame
	print("Authored dialogue checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
