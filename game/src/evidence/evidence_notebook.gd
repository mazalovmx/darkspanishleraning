extends ColorRect
signal closed
signal evidence_recorded
var world_state: RefCounted
var active_id := ""
var inspection_mode := false
var reasoning_mode := false
var compare_button := Button.new()
var support_row := HBoxContainer.new()
var support_a := OptionButton.new()
var support_b := OptionButton.new()
var prompt := Label.new()
var entries := OptionButton.new()
var body := RichTextLabel.new()
var note := LineEdit.new()
var category := OptionButton.new()
var record_button := Button.new()
var feedback := Label.new()
var exercise := VBoxContainer.new()
var close_button := Button.new()

func _ready() -> void:
	color = Color(0, 0, 0, 0.8)
	z_index = 20
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(180, 35)
	panel.size = Vector2(920, 650)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel", background)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)
	var title := Label.new()
	title.text = "CUADERNO DE INVESTIGACIÓN"
	box.add_child(title)
	box.add_child(entries)
	compare_button.text = "Comparar pruebas"
	compare_button.pressed.connect(open_reasoning)
	box.add_child(compare_button)
	entries.item_selected.connect(func(index: int):
		active_id = str(entries.get_item_metadata(index))
		_render())
	body.bbcode_enabled = false
	body.add_theme_font_size_override("normal_font_size", 16)
	body.custom_minimum_size = Vector2(880, 340)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	box.add_child(exercise)
	prompt.text = "Describe lo que ves: Hay… / Veo… / Tomás tiene…\nPalabras: comida · comida para un viaje"
	prompt.add_theme_font_size_override("font_size", 16)
	exercise.add_child(prompt)
	note.placeholder_text = "Escribe una frase en español."
	note.max_length = 300
	exercise.add_child(note)
	exercise.add_child(support_row)
	for selector in [support_a, support_b]:
		selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		selector.clip_text = true
		support_row.add_child(selector)
	var row := HBoxContainer.new()
	exercise.add_child(row)
	category.add_item("Esta frase es…")
	category.add_item("Una observación")
	category.add_item("Una interpretación")
	category.add_item("Una acusación")
	category.add_item("Una declaración institucional")
	row.add_child(category)
	record_button.text = "Anotar la prueba"
	record_button.pressed.connect(_record)
	row.add_child(record_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 16)
	box.add_child(feedback)
	close_button.text = "Volver"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_journal(state: RefCounted) -> void:
	inspection_mode = false
	reasoning_mode = false
	world_state = state
	active_id = "travel_food" if state.evidence.has_evidence("travel_food") else ""
	if state.evidence.has_evidence("monastery_claim"):
		active_id = "monastery_claim"
	_render()
	show()
	close_button.grab_focus()

func inspect(state: RefCounted) -> bool:
	var location: Dictionary = state.location_at(state.hero_cell)
	if location.get("id", "") != "LOC01":
		return false
	world_state = state
	inspection_mode = true
	reasoning_mode = false
	active_id = "travel_food"
	_render()
	show()
	if exercise.visible:
		note.grab_focus()
	return true

func close() -> void:
	hide()
	closed.emit()

func _render() -> void:
	entries.clear()
	var ids: Array = world_state.evidence.progress().keys()
	if reasoning_mode:
		ids = world_state.evidence.reviewable_ids(world_state.day)
	if inspection_mode:
		var location: Dictionary = world_state.location_at(world_state.hero_cell)
		for id in world_state.evidence.inspectable_ids(location.get("id", "")):
			if id not in ids:
				ids.append(id)
	if not active_id.is_empty() and active_id not in ids:
		ids.append(active_id)
	for id: String in ids:
		entries.add_item(world_state.evidence.node(id).title)
		entries.set_item_metadata(entries.item_count - 1, id)
		if id == active_id:
			entries.select(entries.item_count - 1)
	entries.visible = entries.item_count > 1
	note.clear()
	category.clear()
	for label in ["Esta frase es…", "Una observación", "Una interpretación", "Una acusación", "Una declaración institucional"]:
		category.add_item(label)
	category.select(0)
	support_row.hide()
	compare_button.visible = not reasoning_mode
	body.custom_minimum_size.y = 340
	feedback.text = ""
	exercise.hide()
	if active_id.is_empty():
		body.text = "Todavía no hay pruebas anotadas. Examina las pertenencias de Tomás en Santa Lucerna."
		return
	var clue: Dictionary = world_state.evidence.node(active_id)
	if clue.source_type == "reasoning" and not world_state.evidence.has_evidence(active_id):
		_render_assessment(clue)
		return
	prompt.text = "Modelo: %s\nPalabras: %s" % [
		clue.language.get("sample", ""), clue.language.get("vocabulary", "")]
	body.text = "%s\nOBSERVACIÓN\n%s\nFuente: %s\nAFIRMACIÓN\n%s\nFuente: %s\nINTERPRETACIONES POSIBLES\n• %s\nESTADO INSTITUCIONAL\n%s\nVÍNCULO CAUSAL\n%s" % [
		clue.title, clue.observation, clue.source, clue.claim, clue.claim_source,
		"\n• ".join(clue.interpretations), clue.institutional_status, clue.causal_link]
	body.scroll_to_line(0)
	if world_state.evidence.has_evidence(active_id):
		feedback.text = ("Tu pregunta: " if clue.source_type == "testimony" else "Tu anotación: ") + str(world_state.evidence.progress()[active_id].spanish_note) + "\nLas interpretaciones siguen abiertas."
	else:
		exercise.show()
		feedback.text = "Clasifica la frase: observar algo y recibir una orden son actos distintos."

func _record() -> void:
	if active_id.is_empty() or world_state == null:
		return
	if reasoning_mode:
		_record_assessment()
		return
	var location: Dictionary = world_state.location_at(world_state.hero_cell)
	var classes := ["", "observation", "interpretation", "accusation", "institutional_declaration"]
	var clue: Dictionary = world_state.evidence.node(active_id)
	if category.selected < 0 or classes[category.selected] != clue.classification:
		feedback.text = "Distingue una observación de una interpretación, una acusación o una orden."
		return
	if not world_state.evidence.valid_note(active_id, note.text):
		feedback.text = "Prueba con: " + str(clue.language.get("sample", ""))
		return
	if world_state.evidence.record(active_id, location.get("id", ""), note.text, classes[category.selected], world_state.day):
		_render()
		evidence_recorded.emit()

func open_reasoning() -> void:
	var ids: Array = world_state.evidence.reviewable_ids(world_state.day)
	if ids.is_empty():
		feedback.text = "Anota la comida y pregunta al abad antes de comparar las versiones."
		return
	reasoning_mode = true
	inspection_mode = false
	active_id = str(ids.back())
	for id: String in ids:
		if not world_state.evidence.has_evidence(id):
			active_id = id
			break
	_render()

func _render_assessment(clue: Dictionary) -> void:
	body.custom_minimum_size.y = 230
	body.text = str(clue.assessment.question) + "\n\nPRUEBAS DISPONIBLES"
	for id in world_state.evidence.progress():
		var item: Dictionary = world_state.evidence.node(id)
		if item.source_type != "reasoning":
			body.text += "\n• " + str(item.title) + ": " + str(item.observation)
	body.scroll_to_line(0)
	prompt.text = "Formula una conclusión limitada. Modelo: " + str(clue.language.sample)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	category.clear()
	category.add_item("Selecciona una hipótesis…")
	category.set_item_metadata(0, "")
	for option: Dictionary in clue.assessment.options:
		category.add_item(option.text)
		category.set_item_metadata(category.item_count - 1, option.id)
	category.clip_text = true
	category.custom_minimum_size.x = 570
	for selector in [support_a, support_b]:
		selector.clear()
		selector.add_item("Selecciona una prueba de apoyo…")
		selector.set_item_metadata(0, "")
		for id in world_state.evidence.progress():
			var item: Dictionary = world_state.evidence.node(id)
			if item.source_type != "reasoning":
				selector.add_item(item.title)
				selector.set_item_metadata(selector.item_count - 1, id)
	support_row.show()
	exercise.show()
	feedback.text = "Elige una hipótesis, dos pruebas distintas y escribe tu conclusión."

func _record_assessment() -> void:
	var clue: Dictionary = world_state.evidence.node(active_id)
	var supports: Array = [support_a.get_item_metadata(support_a.selected),
		support_b.get_item_metadata(support_b.selected)]
	var choice: String = str(category.get_item_metadata(category.selected))
	if world_state.evidence.record_reasoning(active_id, note.text, choice, supports, world_state.day):
		_render()
		evidence_recorded.emit()
	else:
		feedback.text = str(clue.assessment.feedback) + " Revisa también los apoyos y la frase."
