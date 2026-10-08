extends SceneTree
## Optional case results reach the notebook, comparisons open when both cases are
## concluded, and the chosen outcome shows as a local consequence and a dialogue flag.
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func conclude(cases: RefCounted, branch: String, choice: String) -> void:
	for id: String in cases.branches[branch].quest_ids:
		var progress := {}
		for step: String in cases.stages(id):
			progress[step] = {"day": 1, "hero": "inquisitor", "answer": "", "choice": choice if step == "choice" else "", "rejected": "", "route": "", "cipher": ""}
		cases.records[id] = {"progress": progress, "reward": ""}
func run() -> void:
	root.size = Vector2i(1280, 720)
	var map = load("res://src/world/province_map.tscn").instantiate()
	map.persistence_enabled = false
	root.add_child(map)
	await process_frame
	var state = map.state
	var cases = state.side_cases
	check(cases.started_branches().is_empty() and cases.open_links().is_empty() and cases.outcome_flags().is_empty(), "Nothing before any case")
	conclude(cases, "SB01", "SB01_protected")
	check(cases.outcome("SB01").id == "SB01_protected", "Chosen outcome read from the final quest")
	check(cases.outcome_flags() == {"SB01_protected": "confirmed"}, "Outcome flag recorded")
	check(map.dialogue.context_flags().has("SB01_protected"), "Dialogue context knows the outcome")
	check(map.dialogue.reply_for("LOC01", "¿Qué pasó con el censo?").begins_with("Presentó el censo con los domicilios tapados"), "The abbot reacts to the protected copy")
	check(not map.dialogue.reply_for("LOC01", "¿Y el reloj?").contains("reloj se corrigió"), "No reaction to a case not yet concluded")
	check(cases.local_consequences("LOC01").size() == 1 and cases.local_consequences("LOC01")[0].contains("Se preservan datos privados"), "Local consequence at the case's place")
	check(cases.local_consequences("LOC02").is_empty(), "No consequence elsewhere")
	for branch: String in cases.branches:
		for outcome: Dictionary in cases.branches[branch].outcomes:
			var found := false
			for id: String in map.dialogue.conversations:
				var conversation: Dictionary = map.dialogue.conversations[id]
				if str(conversation.get("location_id", id)) == cases.branches[branch].location_id:
					found = found or conversation.branches.any(func(entry: Dictionary) -> bool: return entry.get("requires_flag", "") == outcome.flag)
			check(found, "A character at the case's place reacts to " + str(outcome.flag))
	var summary: String = cases.case_summary("SB01")
	check(summary.contains("CONCLUSIONES APOYADAS") and summary.contains("Hay un texto anterior bajo la oración.") and summary.contains("DECISIÓN: Presentar una copia con datos protegidos"), "Case summary lists conclusions and the decision")
	check(cases.open_links().is_empty(), "A comparison needs both cases")
	conclude(cases, "SB02", "SB02_public")
	check(cases.open_links().size() == 1 and cases.open_links()[0].id == "LINK1", "The comparison between the two cases opens")
	# Notebook pages.
	map.notebook.open_journal(state)
	var labels: Array = []
	for i in map.notebook.entries.item_count:
		labels.append(map.notebook.entries.get_item_text(i))
	check(labels.has("Investigación local · El censo bajo la oración") and labels.any(func(label: String) -> bool: return label.begins_with("Comparación · ")), "Cases and comparison listed in the notebook")
	check(map.notebook.entries.visible, "The notebook list is shown")
	for i in map.notebook.entries.item_count:
		if str(map.notebook.entries.get_item_metadata(i)) == "case:SB01":
			map.notebook.entries.select(i)
			map.notebook.entries.item_selected.emit(i)
	check(map.notebook.body.text.contains("DECISIÓN: Presentar una copia") and not map.notebook.exercise.visible, "A case page shows its summary without an exercise")
	for i in map.notebook.entries.item_count:
		if str(map.notebook.entries.get_item_metadata(i)) == "link:LINK1":
			map.notebook.entries.item_selected.emit(i)
	check(map.notebook.body.text.begins_with("COMPARACIÓN ENTRE EXPEDIENTES"), "A comparison page shows its prompt")
	check(map.notebook.exercise.visible and not map.notebook.category.visible, "The comparison page asks for the player's comparison")
	map.notebook.note.text = "El censo y el reloj."
	map.notebook.record_button.pressed.emit()
	check(map.notebook.feedback.text.contains("una palabra que compare") and not cases.comparisons.has("LINK1"), "A comparison needs a comparing word and a full sentence")
	map.notebook.note.text = "En el censo se raspó una fecha, pero en el caso del reloj solo se ajustaron las horas."
	map.notebook.record_button.pressed.emit()
	check(cases.comparisons.has("LINK1") and map.notebook.feedback.text.begins_with("Tu comparación"), "The comparison is recorded and shown")
	var saved: Dictionary = cases.snapshot()
	check(saved.has("comparisons") and cases.valid_comparisons(saved.comparisons, cases.records, state) != null, "Saved comparisons validate against the cases")
	var forged: Dictionary = saved.comparisons.duplicate(true)
	forged.LINK1.answer = "Nada."
	check(cases.valid_comparisons(forged, cases.records, state) == null, "A saved comparison must meet its keys")
	var unopened: Dictionary = cases.records.duplicate(true)
	unopened.erase("SX018")
	check(cases.valid_comparisons(saved.comparisons, unopened, state) == null, "A comparison needs both cases concluded")
	map.notebook.close()
	# The place shows the consequence.
	for location: Dictionary in state.locations:
		if location.id == "LOC01":
			state.hero_cell = Vector2i(location.position[0], location.position[1])
	state._reveal_from(state.hero_cell)
	map._refresh()
	map._open_poi(state.hero_cell)
	check(map.poi_description.text.contains("Presentar una copia con datos protegidos"), "The location window shows the local consequence")
	map._close_poi()
	map.queue_free()
	await process_frame
	print("Side outcome checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
