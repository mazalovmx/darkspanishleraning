extends ColorRect
signal closed
signal progressed
signal battle_requested(id: String)
var world_state: RefCounted
var entries := OptionButton.new()
var body := RichTextLabel.new()
var choice := OptionButton.new()
var rejected := OptionButton.new()
var cipher := LineEdit.new()
var prompt := Label.new()
var input := LineEdit.new()
var send_button := Button.new()
var battle_button := Button.new()
var feedback := Label.new()
var close_button := Button.new()

func _ready() -> void:
	color = Color(0,0,0,0.85)
	z_index = 28
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(150,30)
	panel.size = Vector2(980,660)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel",style)
	# Parchment like the journal; its frame is thicker, so the inner margin shrinks.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "INVESTIGACIONES · Pruebas, versiones y memoria"
	box.add_child(title)
	entries.clip_text = true
	entries.item_selected.connect(func(_index: int): feedback.text = ""; refresh())
	box.add_child(entries)
	body.custom_minimum_size.y = 190
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var comparisons := HBoxContainer.new()
	for control in [choice,rejected]:
		control.clip_text = true
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		comparisons.add_child(control)
	box.add_child(comparisons)
	choice.item_selected.connect(func(_index: int):
		if entries.item_count > 0 and world_state.side_cases.stage(entries.get_selected_metadata()) == "choice":
			prompt.text = "Formula tu propuesta: " + world_state.side_cases.choice_model(choice.get_selected_metadata()))
	cipher.max_length = 40
	cipher.placeholder_text = "Escribe la clave del escondite."
	box.add_child(cipher)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt)
	input.max_length = 300
	input.placeholder_text = "Escribe tu respuesta en español."
	input.text_submitted.connect(func(_text: String): _submit())
	box.add_child(input)
	send_button.pressed.connect(_submit)
	box.add_child(send_button)
	battle_button.text = "Disputar el acceso en combate"
	battle_button.pressed.connect(func():
		var id: String = world_state.side_cases.quests[entries.get_selected_metadata()].encounter_id
		close()
		battle_requested.emit(id))
	box.add_child(battle_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 42
	box.add_child(feedback)
	close_button.text = "Volver al mapa"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_cases(state: RefCounted,selected_id := "") -> void:
	world_state = state
	feedback.text = ""
	_fill(selected_id)
	refresh()
	show()

func _fill(selected_id: String) -> void:
	entries.clear()
	var cases = world_state.side_cases
	var location: String = world_state.location_at(world_state.hero_cell).get("id","")
	for id: String in cases.available(world_state):
		if cases.quests[id].location_id != location:
			continue
		entries.add_item(("✓ " if cases.complete(id,cases.records) else "") + str(cases.quests[id].title))
		entries.set_item_metadata(entries.item_count-1,id)
		if id == selected_id:
			entries.select(entries.item_count-1)

func refresh() -> void:
	for control in [choice,rejected,cipher,input,send_button,battle_button]:
		control.hide()
	prompt.text = ""
	input.clear()
	cipher.clear()
	if entries.item_count == 0:
		body.text = "No hay expedientes disponibles aquí. Visita otra localidad o termina las investigaciones anteriores."
		return
	var cases = world_state.side_cases
	var id: String = entries.get_selected_metadata()
	var node: Dictionary = cases.quests[id]
	var step: String = cases.stage(id)
	body.text = str(cases.branches[node.branch_id].title) + "\n" + str(node.title)
	if step == "complete":
		body.text += "\n\nPRUEBA · " + str(cases.artifacts[node.artifact_id].name)
		body.text += "\n" + str(node.investigation.observation)
		body.text += "\n\nCONCLUSIÓN APOYADA · " + str(node.investigation.supported_interpretation)
		var record: Dictionary = cases.records[id]
		body.text += "\n\n" + str(cases.battles[node.encounter_id].consequence.violent_route if record.progress.access.route == "battle" else cases.battles[node.encounter_id].consequence.peaceful_route)
		if not record.reward.is_empty():
			body.text += "\nComponente recibido: " + str(world_state.equipment.items[world_state.equipment.instances[record.reward].item].name)
		if record.progress.has("choice"):
			for outcome: Dictionary in cases.branches[node.branch_id].outcomes:
				if outcome.id == record.progress.choice.choice:
					body.text += "\n\n" + str(outcome.label) + "\n" + str(outcome.effect)
		return
	var denied: String = cases.reason(world_state,id)
	if not denied.is_empty():
		body.text += "\n\n" + denied
		return
	var models: Dictionary = cases.models(id)
	var won: bool = world_state.encounters.get(node.encounter_id,{}).get("outcome","") == "victory"
	# The aside is tone only (bible 38.1): shown after the hook, never a key or a case word.
	body.text += "\n\n" + str(node.hook) + ("\n" + str(node.aside) if node.has("aside") else "")
	if step != "access":
		body.text += "\n\nPIEZA · " + str(cases.artifacts[node.artifact_id].name)
	if step not in ["access","inspect","puzzle"]:
		body.text += "\n\n" + str(node.investigation.supported_interpretation)
	send_button.show()
	send_button.disabled = false
	input.visible = step not in ["inspect","puzzle"]
	match step:
		"access":
			body.text += "\n\n" + str(cases.battles[node.encounter_id].peaceful_route.action)
			if node.has("access_puzzle"):
				body.text += "\n\n" + str(node.access_puzzle.clue)
				cipher.show()
			prompt.text = "Solicita en español una inspección de la pieza «%s»." % cases.artifacts[node.artifact_id].name
			send_button.text = "Registrar acceso" if won else "Solicitar acceso pacífico"
			battle_button.visible = cases.can_battle(world_state,node.encounter_id)
		"inspect":
			body.text += "\n\n" + str(node.investigation.verification_action)
			send_button.text = "Examinar y conservar la prueba"
		"puzzle":
			prompt.text = "Primero elige la interpretación apoyada; después, la que excede la prueba."
			for control in [choice,rejected]:
				control.clear()
				for option: Dictionary in node.puzzle.options:
					control.add_item(str(option.text))
					control.set_item_metadata(control.item_count-1,option.id)
				control.show()
			send_button.text = "Comparar interpretaciones"
		"supported":
			prompt.text = "Practica una frase completa. Modelo: " + str(models.supported)
			send_button.text = "Registrar frase"
		"independent":
			prompt.text = str(node.language.independent_task) + "\nMarco: " + str(node.language.model_frame)
			send_button.text = "Registrar reformulación"
		"recall":
			prompt.text = str(node.language.recall_task)
			send_button.text = "Recordar la frase"
			if world_state.day <= cases.records[id].progress.independent.day:
				send_button.disabled = true
				prompt.text = "Vuelve en un día posterior. La conversación no hace avanzar el mundo."
		"choice":
			choice.clear()
			for outcome: Dictionary in cases.branches[node.branch_id].outcomes:
				choice.add_item(str(outcome.label))
				choice.set_item_metadata(choice.item_count-1,outcome.id)
			choice.show()
			prompt.text = "Elige una salida y formula tu propuesta con un condicional (propondría…)."
			send_button.text = "Cerrar el expediente"

func _submit() -> void:
	if not visible or not send_button.visible or send_button.disabled or entries.item_count == 0:
		return
	var cases = world_state.side_cases
	var id: String = entries.get_selected_metadata()
	var step: String = cases.stage(id)
	var route := ""
	if step == "access":
		route = "battle" if world_state.encounters.get(cases.quests[id].encounter_id,{}).get("outcome","") == "victory" else "peaceful"
	var result: Dictionary = cases.submit(world_state,id,input.text if input.visible else "",
		str(choice.get_selected_metadata()) if choice.visible else "",str(rejected.get_selected_metadata()) if rejected.visible else "",
		route,cipher.text if cipher.visible else "")
	feedback.text = result.message
	if result.ok:
		_fill(id)
		refresh()
		progressed.emit()

func close() -> void:
	hide()
	closed.emit()
