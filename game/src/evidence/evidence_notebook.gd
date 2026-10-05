extends ColorRect
signal closed
signal evidence_recorded
var world_state: RefCounted
var active_id := ""
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
	body.bbcode_enabled = false
	body.add_theme_font_size_override("normal_font_size", 16)
	body.custom_minimum_size = Vector2(880, 340)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	box.add_child(exercise)
	var prompt := Label.new()
	prompt.text = "Describe lo que ves: Hay… / Veo… / Tomás tiene…\nPalabras: comida · comida para un viaje"
	prompt.add_theme_font_size_override("font_size", 16)
	exercise.add_child(prompt)
	note.placeholder_text = "Escribe una frase en español."
	note.max_length = 300
	exercise.add_child(note)
	var row := HBoxContainer.new()
	exercise.add_child(row)
	category.add_item("Esta frase es…")
	category.add_item("Una observación")
	category.add_item("Una interpretación")
	category.add_item("Una acusación")
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
	world_state = state
	active_id = "travel_food" if state.evidence.has_evidence("travel_food") else ""
	_render()
	show()
	close_button.grab_focus()

func inspect(state: RefCounted) -> bool:
	var location: Dictionary = state.location_at(state.hero_cell)
	if location.get("id", "") != "LOC01":
		return false
	world_state = state
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
	note.clear()
	category.select(0)
	feedback.text = ""
	exercise.hide()
	if active_id.is_empty():
		body.text = "Todavía no hay pruebas anotadas. Examina las pertenencias de Tomás en Santa Lucerna."
		return
	var clue: Dictionary = world_state.evidence.node(active_id)
	body.text = "%s\nOBSERVACIÓN\n%s\nFuente: %s\nAFIRMACIÓN\n%s\nFuente: %s\nINTERPRETACIONES POSIBLES\n• %s\nESTADO INSTITUCIONAL\n%s\nVÍNCULO CAUSAL\n%s" % [
		clue.title, clue.observation, clue.source, clue.claim, clue.claim_source,
		"\n• ".join(clue.interpretations), clue.institutional_status, clue.causal_link]
	body.scroll_to_line(0)
	if world_state.evidence.has_evidence(active_id):
		feedback.text = "Tu observación: " + str(world_state.evidence.progress()[active_id].spanish_note) + "\nLas interpretaciones siguen abiertas."
	else:
		exercise.show()
		feedback.text = "Clasifica la frase sobre la comida. No demuestra la causa de la muerte."

func _record() -> void:
	if active_id.is_empty() or world_state == null:
		return
	var location: Dictionary = world_state.location_at(world_state.hero_cell)
	if category.selected != 1:
		feedback.text = "La comida se puede observar. La intención y la causa necesitan otras pruebas."
		return
	if not world_state.evidence.valid_note(active_id, note.text):
		feedback.text = "Prueba con Hay / Veo / Tomás tiene + comida (para un viaje)."
		return
	if world_state.evidence.record(active_id, location.get("id", ""), note.text, "observation", world_state.day):
		_render()
		evidence_recorded.emit()
