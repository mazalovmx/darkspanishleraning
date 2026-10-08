extends ColorRect
signal closed
signal changed
signal battle_requested(id: String)
var world_state: RefCounted
var entries := OptionButton.new()
var body := RichTextLabel.new()
var first := OptionButton.new()
var second := OptionButton.new()
var soul := CheckBox.new()
var prompt := Label.new()
var input := LineEdit.new()
var feedback := Label.new()
var send_button := Button.new()
var prepare_button := Button.new()
var battle_button := Button.new()
var target := ""

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
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 6 if paper and edge in ["top", "bottom"] else 18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	margin.add_child(box)
	var title := Label.new()
	title.text = "CABALLEROS DEL ÍNDICE · Órdenes y pruebas"
	box.add_child(title)
	entries.clip_text = true
	entries.item_selected.connect(func(_index: int): input.clear(); feedback.text = ""; refresh())
	box.add_child(entries)
	body.custom_minimum_size.y = 180
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	prepare_button.text = "Preparar las órdenes del día"
	prepare_button.pressed.connect(func():
		if world_state.ghosts.prepare(world_state):
			changed.emit()
			open_orders(world_state))
	box.add_child(prepare_button)
	for source in [first,second]:
		source.clip_text = true
		box.add_child(source)
		source.item_selected.connect(func(_index: int): _prompt())
	soul.text = "Pedir ayuda al alma del conjunto (un uso diario)"
	soul.toggled.connect(func(_pressed: bool): _prompt())
	box.add_child(soul)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt)
	input.max_length = 300
	input.placeholder_text = "Escribe la respuesta en español y cita tu prueba."
	input.text_submitted.connect(func(_text: String): _submit())
	box.add_child(input)
	send_button.text = "Presentar la refutación"
	send_button.pressed.connect(_submit)
	box.add_child(send_button)
	battle_button.text = "Enfrentarse al caballero cercano"
	battle_button.pressed.connect(func():
		var id: String = entries.get_selected_metadata()
		close()
		battle_requested.emit(id))
	box.add_child(battle_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(feedback)
	var back := Button.new()
	back.text = "Volver al mapa"
	back.pressed.connect(close)
	box.add_child(back)
	hide()

func open_orders(world: RefCounted) -> void:
	world_state = world
	entries.clear()
	for id: String in world.ghosts.actors:
		var actor: Dictionary = world.ghosts.actors[id]
		var cell := Vector2i(actor.cell[0],actor.cell[1])
		var traced := false
		for effect: Dictionary in world.ghosts.effects.values():
			traced = traced or effect.knight == id
		if not actor.active or (world.fog_at(cell) != world.Fog.VISIBLE and not traced):
			continue
		entries.add_item(world.ghosts.definitions[id].name)
		entries.set_item_metadata(entries.item_count-1,id)
	input.clear()
	feedback.text = ""
	show()
	refresh()

func refresh() -> void:
	target = ""
	first.clear()
	second.clear()
	prepare_button.disabled = world_state.ghosts.plan != null or world_state.planning_active() or not world_state.trade.pending.is_empty() or not world_state.economy.pending.is_empty()
	body.text = "Prepara las órdenes para fijar los planes del día. Después puedes cambiar las rutas de tus héroes. Resolver órdenes mueve a todos a la vez.\n"
	if entries.item_count == 0:
		body.text += "No hay caballeros visibles ni intervenciones activas."
	else:
		var id: String = entries.get_selected_metadata()
		var ghosts = world_state.ghosts
		var actor: Dictionary = ghosts.actors[id]
		if actor.return_day > world_state.day:
			body.text += "Dispersado hasta el día %d.\n" % actor.return_day
		for effect: Dictionary in ghosts.effects.values():
			if effect.knight == id:
				target = effect.target
				body.text += "Intervención en %s · termina el día %d.\n" % [target,effect.expiry]
		if ghosts.plan != null and ghosts.plan.orders.has(id):
			var order: Dictionary = ghosts.plan.orders[id]
			body.text += "Orden fijada: %s.\n" % {"move":"viajar","guard":"guardar posición","recover":"recuperarse","intervene":"intervenir"}.get(order.kind,order.kind)
			if id in ghosts.countered:
				body.text += "Orden interrumpida por una refutación o derrota.\n"
			if order.kind == "intervene" and id not in ghosts.countered:
				target = order.target
		if not target.is_empty():
			var quest: Dictionary = world_state.side_cases.quests[target]
			body.text += "Expediente: %s · lugar: %s. Compara fuentes; la fuerza no demuestra una afirmación.\n" % [target,quest.location_id]
			for evidence: String in ghosts.sources(world_state,target):
				for source in [first,second]:
					source.add_item(world_state.side_cases.artifacts[evidence].name)
					source.set_item_metadata(source.item_count-1,evidence)
			if second.item_count > 1:
				second.select(1)
		var cell := Vector2i(actor.cell[0],actor.cell[1])
		battle_button.disabled = world_state.planning_active() or actor.return_day > world_state.day or world_state.hero_cell.distance_squared_to(cell) > 4 or world_state.army.is_empty() or world_state.movement_remaining < 2
	battle_button.visible = entries.item_count > 0
	for control in [first,second,soul,prompt,input,send_button]:
		control.visible = not target.is_empty()
	_prompt()

func _prompt() -> void:
	if target.is_empty():
		return
	var id: String = entries.get_selected_metadata()
	var requires_two := id in ["NK02","NK03","NK04","NK08"] and not soul.button_pressed
	second.visible = requires_two
	send_button.disabled = first.item_count == 0 or (requires_two and second.item_count < 2)
	prompt.text = "Necesitas pruebas inspeccionadas de esta investigación."
	if first.item_count > 0:
		prompt.text = "Práctica guiada: " + world_state.ghosts.counter_model(world_state,id,first.get_selected_metadata())
		prompt.text += "\nCita dos fuentes distintas." if requires_two else "\nCita una fuente."

func _submit() -> void:
	if target.is_empty() or first.item_count == 0:
		return
	var id: String = entries.get_selected_metadata()
	var proof := [first.get_selected_metadata()]
	if second.visible and second.item_count > 0:
		proof.append(second.get_selected_metadata())
	if world_state.ghosts.counter(world_state,id,target,input.text,proof,soul.button_pressed):
		input.clear()
		changed.emit()
		refresh()
		feedback.text = "La prueba y tu respuesta han detenido la intervención."
	else:
		feedback.text = "Revisa la frase, las fuentes distintas y el lugar. El alma necesita un conjunto reunido, consentimiento y su uso diario disponible."

func close() -> void:
	hide()
	closed.emit()