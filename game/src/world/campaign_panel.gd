extends ColorRect
signal closed
signal progressed
var world_state: RefCounted
var active_id := ""
const SUMMARY := "@resumen"
var title := Label.new()
var entries := OptionButton.new()
var body := RichTextLabel.new()
var question := Label.new()
var answer := LineEdit.new()
var category := OptionButton.new()
var support_a := OptionButton.new()
var support_b := OptionButton.new()
var supports_row := HBoxContainer.new()
var submit_button := Button.new()
var hint_button := Button.new()
var close_button := Button.new()
var feedback := Label.new()
## Optional Claude review of an accepted conclusion: feedback only, never progress.
var reviewer: Node = preload("res://src/claude/claude_client.gd").new()
## The submission a pending review belongs to: card, game, recorded sentence, and the
## feedback line it was shown on. A review that arrives later than that line is kept
## beside its record instead (this session, this game).
var review := {}
var review_notes := {}
var notes_world: RefCounted = null
var feedback_serial := 0
const LABELS := ["Observado", "Referido por una fuente", "Inferido", "Declarado por una institución", "No resuelto"]
func _ready() -> void:
	add_child(reviewer)
	reviewer.reviewed.connect(_on_review)
	color = Color(0,0,0,0.85)
	z_index = 27
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(180,40)
	panel.size = Vector2(920,640)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel", style)
	preload("res://src/common/parchment_theme.gd").apply(panel)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","top","right","bottom"]:
		margin.add_theme_constant_override("margin_" + side,20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",10)
	margin.add_child(box)
	box.add_child(title)
	entries.clip_text = true
	entries.item_selected.connect(func(index: int):
		active_id = str(entries.get_item_metadata(index))
		feedback_serial += 1
		refresh())
	box.add_child(entries)
	body.bbcode_enabled = false
	body.custom_minimum_size.y = 170
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(question)
	answer.max_length = 300
	answer.placeholder_text = "Escribe una frase completa en español."
	answer.text_submitted.connect(func(_message: String): _submit())
	box.add_child(answer)
	box.add_child(category)
	box.add_child(supports_row)
	for selector in [support_a,support_b]:
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.clip_text = true
		supports_row.add_child(selector)
	var actions := HBoxContainer.new()
	box.add_child(actions)
	submit_button.text = "Anotar conclusión"
	submit_button.pressed.connect(_submit)
	actions.add_child(submit_button)
	hint_button.text = "¿Qué debe decir?"
	hint_button.pressed.connect(func():
		if not active_id.is_empty() and not submit_button.disabled:
			feedback_serial += 1
			var parts: Array[String] = world_state.campaign.needs(world_state.campaign.definitions[active_id])
			feedback.text = "Escribe una de las propuestas." if parts.is_empty() else "Tu frase necesita: " + "; ".join(parts) + ".")
	actions.add_child(hint_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 52
	box.add_child(feedback)
	close_button.text = "Volver"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_journal(state: RefCounted) -> void:
	world_state = state
	active_id = SUMMARY
	feedback.text = ""
	feedback_serial += 1
	refresh()
	show()

## The first page: every task grouped as main story, optional story tasks and local
## investigations, each marked in progress (▶), finished (✓) or not started (○).
## Tasks that are not open yet are counted, never named.
func summary() -> String:
	var campaign = world_state.campaign
	var groups := {false: {"now": [], "done": [], "later": 0, "closed": 0}, true: {"now": [], "done": [], "later": 0, "closed": 0}}
	var available: Array = campaign.available(world_state)
	for id: String in campaign.definitions:
		var node: Dictionary = campaign.definitions[id]
		var group: Dictionary = groups[bool(node.get("optional",false))]
		if campaign.records.has(id):
			group.done.append("✓ %s — %s (día %d)" % [node.title,_location_name(node.location),campaign.records[id].day])
		elif campaign.closed(world_state,node,campaign.records):
			group.closed += 1
		elif id in available:
			var reason: String = campaign.reason(world_state,id)
			group.now.append("▶ %s — %s. %s" % [node.title,_location_name(node.location),reason if not reason.is_empty() else "Puedes anotarla ahora: elígela en la lista de arriba."])
		else:
			group.later += 1
	var lines: Array[String] = ["TAREAS · día %d        ▶ en curso    ✓ terminada    ○ sin empezar" % world_state.day,"",
		"HISTORIA PRINCIPAL · acto %d de 7" % campaign.chapter(world_state)]
	var evidence = world_state.evidence
	var found: int = evidence.progress().size()
	var total: int = evidence.definitions.size()
	if evidence.has_evidence("opening_conclusion"):
		lines.append("✓ La muerte de Tomás — Santa Lucerna (%d de %d pruebas anotadas)" % [found,total])
	else:
		var step := "Siguiente paso: pregunta a los testigos del monasterio sobre lo que has visto y pulsa «Comparar pruebas» en el Cuaderno."
		if not evidence.has_evidence("travel_food"):
			step = "Siguiente paso: entra en el monasterio de Santa Lucerna y pulsa «Examinar pertenencias»."
		else:
			var waiting := 0
			for id: String in evidence.inspectable_ids("LOC01"):
				waiting += int(not evidence.has_evidence(id))
			if waiting > 0:
				step = "Siguiente paso: quedan %d hallazgos por examinar en el monasterio («Examinar pertenencias»)." % waiting
		lines.append("▶ La muerte de Tomás — Santa Lucerna: %d de %d pruebas anotadas. %s" % [found,total,step])
	lines.append_array(groups[false].now)
	if groups[false].later > 0:
		lines.append("○ %d tareas de la historia todavía sin abrir: aparecen al terminar las anteriores." % groups[false].later)
	lines.append_array(groups[false].done)
	if world_state.map_id != "province_160x120_v1":
		return "\n".join(lines)
	lines.append_array(["","TAREAS SECUNDARIAS (opcionales, no hacen falta para terminar la historia)"])
	lines.append_array(groups[true].now)
	if groups[true].later > 0:
		lines.append("○ %d tareas secundarias todavía sin abrir." % groups[true].later)
	if groups[true].closed + groups[false].closed > 0:
		lines.append("✗ %d tareas cerradas por una decisión anterior." % (groups[true].closed + groups[false].closed))
	lines.append_array(groups[true].done)
	lines.append_array(["","INVESTIGACIONES LOCALES (opcionales; botón «Investigaciones locales» en cada lugar)"])
	var cases = world_state.side_cases
	var untouched := 0
	for branch: Dictionary in cases.branches.values():
		var solved := 0
		for id: String in branch.quest_ids:
			solved += int(cases.complete(id,cases.records))
		var begun: bool = branch.quest_ids.any(func(id: String) -> bool: return cases.records.has(id))
		if solved == branch.quest_ids.size():
			lines.append("✓ %s — %s" % [branch.title,_location_name(branch.location_id)])
		elif begun:
			lines.append("▶ %s — %s: %d de %d casos resueltos." % [branch.title,_location_name(branch.location_id),solved,branch.quest_ids.size()])
		else:
			untouched += 1
	if untouched > 0:
		lines.append("○ %d investigaciones sin empezar." % untouched)
	return "\n".join(lines)

func _location_name(id: String) -> String:
	for location: Dictionary in world_state.locations:
		if location.id == id:
			return location.name
	return id

func refresh() -> void:
	_refresh_body()
	var pending: Array[String] = world_state.campaign.pending_consultations(world_state)
	if not pending.is_empty():
		body.text += "\n\nCONSULTAS PENDIENTES\n· " + "\n· ".join(pending)
	var acts: Array = world_state.campaign.acts(world_state)
	if not acts.is_empty():
		body.text += "\n\nACTOS INSTITUCIONALES EN VIGOR"
		for act: Dictionary in acts:
			body.text += "\n· " + world_state.campaign.Institutions.describe(act)

func _refresh_body() -> void:
	var campaign = world_state.campaign
	title.text = "DIARIO DE TAREAS · ACTO %d" % campaign.chapter(world_state)
	var available: Array = campaign.available(world_state)
	var ids: Array = available + campaign.records.keys()
	entries.clear()
	entries.add_item("Resumen de tareas: en curso, terminadas y sin empezar")
	entries.set_item_metadata(0,SUMMARY)
	for id: String in ids:
		var node: Dictionary = campaign.definitions[id]
		entries.add_item(("✓ Anotado · " if campaign.records.has(id) else "▶ ") + ("(opcional) " if node.get("optional",false) else "") + str(node.title) + " — " + _location_name(node.location))
		entries.set_item_metadata(entries.item_count - 1,id)
	if active_id not in ids:
		active_id = SUMMARY
	for i in entries.item_count:
		if entries.get_item_metadata(i) == active_id:
			entries.select(i)
	answer.clear()
	category.clear()
	category.add_item("Clasifica la afirmación…")
	for label in LABELS:
		category.add_item(label)
	supports_row.hide()
	question.text = ""
	answer.hide()
	category.hide()
	submit_button.disabled = true
	hint_button.disabled = true
	for button: Button in [submit_button,hint_button]:
		button.visible = active_id != SUMMARY
	body.custom_minimum_size.y = 285 if active_id == SUMMARY else 170
	if active_id == SUMMARY:
		body.text = summary()
		body.scroll_to_line(0)
		return
	var node: Dictionary = campaign.definitions[active_id]
	if campaign.records.has(active_id):
		var record: Dictionary = campaign.records[active_id]
		var kind: String = "Decisión" if node.get("decision",false) else "Categoría: " + LABELS[campaign.CLASSIFICATIONS.find(record.classification)]
		body.text = "%s\n\n%s\n\nAnotación · día %d\n%s\n%s" % [node.speaker,node.source,record.day,record.answer,kind]
		if notes_world == world_state and review_notes.has(active_id):
			body.text += "\n" + str(review_notes[active_id])
		var decided: Dictionary = campaign.outcome_for(world_state,node,str(record.answer))
		if active_id != "council_resolution" and not decided.is_empty():
			body.text += "\n\n" + str(decided.title) + "\n" + str(decided.text)
		if active_id == "council_resolution":
			var outcome: Dictionary = campaign.ending(world_state)
			body.text = "FINAL · " + str(outcome.title) + "\n\n" + str(outcome.text) + "\n\n" + str(outcome.characters) + "\n\nDeclaración registrada:\n" + str(record.answer)
		return
	var reason: String = campaign.reason(world_state,active_id)
	if not reason.is_empty():
		body.text = "%s\n\nLugar: %s\n\n%s" % [node.title,_location_name(node.location),reason]
		return
	body.text = "%s\n\n%s" % [node.speaker,node.source]
	if node.has("decision_keys"):
		# The council takes the player's own proposal: show the options, not sentences.
		body.text += "\n\nOPCIONES"
		for outcome: Dictionary in node.outcomes:
			body.text += "\n· %s: %s" % [outcome.title, outcome.keys[0].need]
		body.text += "\n\nEscribe tu propia propuesta en una frase: propongo que… y su límite (aunque…)."
	else:
		for outcome: Dictionary in node.get("outcomes", []):
			body.text += "\n\nPropuesta: " + str(outcome.answer)
	question.text = node.prompt
	answer.show()
	category.visible = not node.get("decision",false)
	submit_button.disabled = false
	hint_button.disabled = false
	if not node.get("supports",[]).is_empty():
		supports_row.show()
		for selector in [support_a,support_b]:
			selector.clear()
			selector.add_item("Elige una prueba distinta…")
			selector.set_item_metadata(0,"")
			for id: String in world_state.evidence.progress():
				selector.add_item(world_state.evidence.node(id).title)
				selector.set_item_metadata(selector.item_count - 1,"e:" + id)
			for id: String in campaign.records:
				selector.add_item(campaign.definitions[id].title)
				selector.set_item_metadata(selector.item_count - 1,id)
	answer.grab_focus()

func _submit() -> void:
	if not visible or submit_button.disabled or active_id.is_empty():
		return
	var campaign = world_state.campaign
	var classification := "" if category.selected < 1 or not category.visible else str(campaign.CLASSIFICATIONS[category.selected - 1])
	var supports := []
	if supports_row.visible:
		supports = [support_a.get_selected_metadata(),support_b.get_selected_metadata()]
	var typed := answer.text
	var submitted := active_id
	var result: Dictionary = campaign.submit(world_state,active_id,typed,classification,supports)
	feedback_serial += 1
	feedback.text = result.message
	if result.ok:
		refresh()
		progressed.emit()
		if not reviewer.busy:
			review = {"id": submitted, "world": world_state, "answer": campaign.records[submitted].answer, "serial": feedback_serial}
			reviewer.request_review(typed,str(campaign.definitions[submitted].prompt),world_state.learner.context())

func _on_review(language: Dictionary) -> void:
	var pending := review
	review = {}
	# Another game, or a record that no longer holds the reviewed sentence: dropped.
	if pending.is_empty() or pending.world != world_state or str(world_state.campaign.records.get(pending.id, {}).get("answer", "")) != pending.answer:
		return
	var strict: bool = world_state.learner.curriculum.is_last_block(int(world_state.campaign.definitions[pending.id].min_block))
	var text: String = reviewer.review_text(language,strict,world_state.learner.curriculum)
	if text.is_empty():
		return
	if visible and pending.serial == feedback_serial:
		feedback.text += "\n" + text
		return
	if notes_world != world_state:
		review_notes.clear()
		notes_world = world_state
	review_notes[pending.id] = text
	if visible and active_id == pending.id:
		refresh()

func close() -> void:
	hide()
	closed.emit()