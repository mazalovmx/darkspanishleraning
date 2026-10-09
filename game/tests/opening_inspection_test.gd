extends SceneTree
const World = preload("res://src/world/world_state.gd")
const Save = preload("res://src/save/save_game.gd")
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
	var state := World.new()
	var graph = state.evidence
	check(graph.inspectable_ids("LOC01") == ["travel_food"], "Opening inspection teaches one observation first")
	check(graph.inspectable_ids("LOC11").is_empty(), "No remote clues")
	for id in ["brass_tube", "tower_blood", "scraped_boot", "missing_notebook", "preservation_order"]:
		var clue: Dictionary = graph.node(id)
		check(not graph.record(id, "LOC01", clue.language.sample, clue.classification, 1), "Prerequisite cannot be bypassed")
	check(graph.record("travel_food", "LOC01", "Hay comida.", "observation", 2), "First guided observation")
	check(graph.inspectable_ids("LOC01").size() == 5, "Four more physical observations available")
	for id in ["brass_tube", "tower_blood", "scraped_boot", "missing_notebook"]:
		var clue: Dictionary = graph.node(id)
		check(not graph.record(id, "LOC01", clue.language.sample, clue.classification, 1), "Cannot predate prerequisite")
		check(not graph.record(id, "LOC11", clue.language.sample, clue.classification, 2), "Cannot inspect at inn")
		check(not graph.record(id, "LOC01", "objeto", clue.classification, 2), "Vocabulary alone is insufficient")
		check(graph.record(id, "LOC01", clue.language.sample, clue.classification, 2), "Supported present-tense observation recorded")
	check(not graph.has_evidence("horse_sound"), "Physical inspection cannot award witness testimony")
	check(graph.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", "¿Qué dice la comunidad?", 2), "Existing dialogue still works")
	var order: Dictionary = graph.node("preservation_order")
	check(not graph.record("preservation_order", "LOC01", order.language.sample, "observation", 2), "An order is not a physical observation")
	check(graph.record("preservation_order", "LOC01", order.language.sample, order.classification, 2), "Custody order classified separately")
	state.day = 2
	var saved := Save.snapshot(state)
	var decoded := Save.decode(saved)
	check(decoded.has("state") and decoded.state.evidence.progress() == graph.progress(), "All accessible evidence survives save/load")
	for removed in ["travel_food", "monastery_claim"]:
		var bad := saved.duplicate(true)
		bad.evidence.erase(removed)
		check(not Save.decode(bad).has("state"), "Missing prerequisite rejected")
	var bad := saved.duplicate(true)
	bad.evidence.brass_tube.found_day = 1
	check(not Save.decode(bad).has("state"), "Bad chronology rejected")
	check(not graph.restore(bad.evidence, 2) and graph.progress() == saved.evidence, "Rejected restore preserves state")
	var map = load("res://src/world/world_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	check(map.state.move_to(Vector2i(6, 11), true), "Reach inn")
	map.state.end_turn()
	check(map.state.move_to(Vector2i(7, 10), true), "Reveal monastery")
	check(map.state.move_to(Vector2i(12, 10), true), "Reach monastery")
	var notebook = map.notebook
	notebook.open_journal(map.state)
	check(notebook.entries.item_count == 0, "Journal does not leak unseen evidence")
	check(notebook.guide.text.begins_with("QUÉ HACER") and notebook.guide.text.contains("Examinar pertenencias"), "An empty notebook says where the first evidence is")
	check(notebook.inspect(map.state), "Monastery inspection opens")
	check(notebook.entries.item_count == 1, "Unmet prerequisites hidden")
	check(notebook.guide.text.begins_with("CÓMO ANOTAR") and notebook.entries.get_item_text(0).begins_with("● "), "An unrecorded finding shows the four steps and is marked as pending")
	notebook.note.text = "Hay comida."
	notebook.record_button.pressed.emit()
	check(not map.state.evidence.has_evidence("travel_food") and notebook.feedback.text.contains("Elige en la lista qué clase de frase"), "A missing classification is named, not just refused")
	notebook.note.text = "comida"
	notebook.category.select(1)
	notebook.record_button.pressed.emit()
	check(not map.state.evidence.has_evidence("travel_food") and notebook.feedback.text.contains("un verbo en presente") and notebook.feedback.text.contains("Un ejemplo (cámbialo a tu manera): Hay comida"), "An insufficient sentence is told what it lacks and, the second time, gets an example")
	notebook.note.text = "Hay comida."
	notebook.category.select(1)
	notebook.record_button.pressed.emit()
	check(notebook.entries.item_count == 5, "Recording refreshes available inspections")
	check(notebook.guide.text.begins_with("✓") and notebook.guide.text.contains("Quedan 4 sin anotar") and notebook.entries.get_item_text(notebook.entries.selected).begins_with("✓ "), "After recording, the notebook says how many findings remain")
	var tube_index := -1
	for index in range(notebook.entries.item_count):
		if notebook.entries.get_item_metadata(index) == "brass_tube":
			tube_index = index
	check(tube_index >= 0, "Tube appears in selector")
	notebook.entries.item_selected.emit(tube_index)
	check(notebook.prompt.text.contains("tubo roto") and not notebook.prompt.text.contains("Hay un tubo roto.") and notebook.body.text.contains("latón"), "Selected clue supplies its own scene and useful words, not the sentence")
	notebook.note.text = "Hay un tubo roto."
	notebook.category.select(1)
	notebook.record_button.pressed.emit()
	check(map.state.evidence.has_evidence("brass_tube"), "Selector and recorder are connected")
	notebook.open_journal(map.state)
	check(notebook.entries.item_count == 2, "Journal contains only recorded evidence")
	map.state.evidence.record_dialogue("monastery_claim", "lucio_salcedo", "LOC01", "¿Qué dice la comunidad?", map.state.day)
	notebook.inspect(map.state)
	var order_index := -1
	for index in range(notebook.entries.item_count):
		if notebook.entries.get_item_metadata(index) == "preservation_order":
			order_index = index
	check(order_index >= 0, "Document unlocks after abbot testimony")
	notebook.entries.item_selected.emit(order_index)
	notebook.note.text = order.language.sample
	notebook.category.select(1)
	notebook.record_button.pressed.emit()
	check(not map.state.evidence.has_evidence("preservation_order"), "UI rejects document as observation")
	notebook.category.select(4)
	notebook.record_button.pressed.emit()
	check(map.state.evidence.has_evidence("preservation_order"), "UI accepts institutional classification")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://opening-inspection-preview.png")
	map.queue_free()
	await process_frame
	print("Opening inspection checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
