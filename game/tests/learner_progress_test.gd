extends SceneTree
## Learner progress tab (section 29): block progress, frequent errors and review of
## lessons already studied, which never changes progress.
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
	root.size = Vector2i(1280, 720)
	var state := World.new("province_160x120_v1")
	var course = state.learner.curriculum
	var first: Dictionary = course.blocks[0].cards[0]
	check(course.card_status(first.id) == "pendiente", "A lesson not yet introduced is pending")
	check(not course.review_check(first.id, 0, first.exercises[0].answers[0]), "No review before the lesson is introduced")
	check(course.introduce(first.id, 1), "Lesson introduced")
	check(course.card_status(first.id) == "presentada", "Introduced lesson status")
	var before := JSON.stringify(course.snapshot())
	check(course.review_check(first.id, 0, first.exercises[0].answers[0]), "Review accepts an authored answer")
	check(not course.review_check(first.id, 1, "Hola."), "Review rejects an unrelated answer")
	check(JSON.stringify(course.snapshot()) == before, "Review gives no credit")
	check(course.explain("preterite").begins_with("pretérito indefinido · Pretérito"), "Explanation names the grammar and the lesson rule")
	check(course.explain("invented|ser_estar").begins_with("ser / estar · "), "Combined tags use the first known one")
	check(course.explain("invented").is_empty(), "Unknown tags get no explanation")
	state.learner.errors["ser_estar"] = {"count": 3, "last_seen_day": 1, "examples": ["El abad está médico."]}
	state.learner.errors["hay"] = {"count": 1, "last_seen_day": 1, "examples": ["Hay los libros."], "mastery_after": 0.42}
	var loaded: Dictionary = Save.decode(Save.snapshot(state))
	check(loaded.has("state") and is_equal_approx(float(loaded.state.learner.errors.hay.mastery_after), 0.42) and loaded.state.learner.errors.ser_estar.has("mastery_after"), "mastery_after survives a save; older records get the current mastery")
	state.learner.errors.erase("hay")
	state.learner.vocabulary.assign(["la vela", "el sello"])
	var panel = load("res://src/spanish/curriculum_panel.gd").new()
	root.add_child(panel)
	await process_frame
	panel.open_course(state)
	check(panel.practice_box.visible and not panel.progress_box.visible, "The panel opens on practice")
	panel.progress_tab.pressed.emit()
	check(panel.progress_box.visible and not panel.practice_box.visible, "The progress tab shows progress")
	check(panel.report.text.contains("Bloque 1") and panel.report.text.contains("0 de %d" % course.blocks[0].cards.size()), "Block progress listed")
	check(panel.report.text.contains("dominio 0 %") and panel.report.text.contains("ser / estar: 3 veces") and panel.report.text.contains("El abad está médico."), "Frequent errors listed by name with an example")
	check(panel.report.text.contains("VOCABULARIO NUEVO DE LAS CONVERSACIONES: la vela, el sello"), "New vocabulary listed")
	check(panel.review_select.item_count == 1 and str(panel.review_select.get_selected_metadata()) == first.id, "Only studied lessons can be reviewed")
	panel.review_answer.text = first.exercises[0].answers[0]
	panel.review_check.pressed.emit()
	check(panel.review_feedback.text.begins_with("Bien"), "Correct review answer praised")
	panel.review_answer.text = "No sé."
	panel.review_check.pressed.emit()
	check(panel.review_feedback.text.contains(first.exercises[0].answers[0]), "A wrong review answer shows a possible answer")
	panel.review_next.pressed.emit()
	check(panel.review_text.text.contains("Ejercicio 2 de 3"), "Another exercise of the same lesson")
	check(JSON.stringify(course.snapshot()) == before, "The review tab gives no credit")
	panel.practice_tab.pressed.emit()
	check(panel.practice_box.visible, "Back to practice")
	panel.queue_free()
	await process_frame
	print("Learner progress checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
