extends ColorRect
signal closed
signal progressed
var world_state: RefCounted
var active_id := ""
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
var reviewed_id := ""
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
	active_id = ""
	feedback.text = ""
	refresh()
	show()

func _location_name(id: String) -> String:
	for location: Dictionary in world_state.locations:
		if location.id == id:
			return location.name
	return id

func refresh() -> void:
	_refresh_body()
	var acts: Array = world_state.campaign.acts(world_state)
	if not acts.is_empty():
		body.text += "\n\nACTOS INSTITUCIONALES EN VIGOR"
		for act: Dictionary in acts:
			body.text += "\n· " + world_state.campaign.Institutions.describe(act)

func _refresh_body() -> void:
	var campaign = world_state.campaign
	title.text = "EXPEDIENTES · ACTO %d" % campaign.chapter(world_state)
	var available: Array = campaign.available(world_state)
	var ids: Array = available + campaign.records.keys()
	entries.clear()
	for id: String in ids:
		var node: Dictionary = campaign.definitions[id]
		entries.add_item(("%s · " % "Anotado" if campaign.records.has(id) else "") + str(node.title) + " — " + _location_name(node.location))
		entries.set_item_metadata(entries.item_count - 1,id)
	if active_id not in ids:
		active_id = "" if ids.is_empty() else str(ids[0])
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
	if active_id.is_empty():
		body.text = "Investiga la muerte de Tomás en Santa Lucerna. Examina sus pertenencias, escucha a los testigos y compara las pruebas en el cuaderno."
		return
	var node: Dictionary = campaign.definitions[active_id]
	if campaign.records.has(active_id):
		var record: Dictionary = campaign.records[active_id]
		var kind: String = "Decisión" if node.get("decision",false) else "Categoría: " + LABELS[campaign.CLASSIFICATIONS.find(record.classification)]
		body.text = "%s\n\n%s\n\nAnotación · día %d\n%s\n%s" % [node.speaker,node.source,record.day,record.answer,kind]
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
	feedback.text = result.message
	if result.ok:
		refresh()
		progressed.emit()
		if not reviewer.busy:
			reviewed_id = submitted
			reviewer.request_review(typed,str(campaign.definitions[submitted].prompt),world_state.learner.context())

func _on_review(language: Dictionary) -> void:
	if not visible or reviewed_id.is_empty() or not world_state.campaign.records.has(reviewed_id):
		return
	var strict: bool = world_state.learner.curriculum.is_last_block(int(world_state.campaign.definitions[reviewed_id].min_block))
	var text: String = reviewer.review_text(language,strict)
	reviewed_id = ""
	if not text.is_empty():
		feedback.text += "\n" + text

func close() -> void:
	hide()
	closed.emit()