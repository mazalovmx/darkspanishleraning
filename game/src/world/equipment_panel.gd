extends ColorRect
signal closed
signal changed
const SLOT_NAMES := {"head":"Cabeza","neck":"Cuello","torso":"Torso","cloak":"Capa","feet":"Pies","weapon":"Arma","shield":"Escudo","ring_1":"Anillo 1","ring_2":"Anillo 2","misc_1":"Accesorio 1","misc_2":"Accesorio 2","misc_3":"Accesorio 3","misc_4":"Accesorio 4","misc_5":"Accesorio 5"}
const EFFECT_NAMES := {"army_attack":"Ataque","army_defense":"Defensa","army_hp_percent":"Salud (%)","army_initiative":"Iniciativa","army_luck":"Suerte","army_morale":"Moral","world_movement":"Movimiento","ranged_damage_percent":"Daño a distancia (%)"}
var world_state: RefCounted
var title := Label.new()
var tabs := TabContainer.new()
var inventory := ItemList.new()
var slot := OptionButton.new()
var target := OptionButton.new()
var details := RichTextLabel.new()
var equip_button := Button.new()
var remove_button := Button.new()
var transfer_button := Button.new()
var sets := OptionButton.new()
var soul_text := RichTextLabel.new()
var memory_a := OptionButton.new()
var memory_b := OptionButton.new()
var prompt := Label.new()
var input := LineEdit.new()
var send_button := Button.new()
var assemble_button := Button.new()
var disassemble_button := Button.new()
var transfer_set_button := Button.new()
var feedback := Label.new()
var close_button := Button.new()

func _ready() -> void:
	color = Color(0,0,0,0.85)
	z_index = 29
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(150,30)
	panel.size = Vector2(980,660)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel",style)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left","right","top","bottom"]:
		margin.add_theme_constant_override("margin_"+side,18)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8)
	margin.add_child(box)
	box.add_child(title)
	var recipients := HBoxContainer.new()
	var label := Label.new()
	label.text = "Destinatario de entrega (misma casilla):"
	recipients.add_child(label)
	target.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recipients.add_child(target)
	box.add_child(recipients)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(tabs)
	var pack := HBoxContainer.new()
	pack.name = "Equipo"
	tabs.add_child(pack)
	inventory.custom_minimum_size.x = 360
	inventory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory.item_selected.connect(func(_index: int): _item_details())
	pack.add_child(inventory)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack.add_child(controls)
	details.custom_minimum_size.y = 130
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(details)
	controls.add_child(slot)
	_button(controls,equip_button,"Equipar en este espacio",func(): _action("equip"))
	_button(controls,remove_button,"Guardar en la mochila",func(): _action("remove"))
	_button(controls,transfer_button,"Entregar esta pieza",func(): _action("transfer"))
	var souls := VBoxContainer.new()
	souls.name = "Almas"
	tabs.add_child(souls)
	sets.item_selected.connect(func(_index: int): feedback.text = ""; _soul_details())
	souls.add_child(sets)
	soul_text.custom_minimum_size.y = 155
	soul_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	souls.add_child(soul_text)
	var memories := HBoxContainer.new()
	for control in [memory_a,memory_b]:
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.clip_text = true
		memories.add_child(control)
	souls.add_child(memories)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	souls.add_child(prompt)
	input.max_length = 300
	input.placeholder_text = "Escribe tu argumento en español."
	input.text_submitted.connect(func(_answer: String): _speak())
	souls.add_child(input)
	_button(souls,send_button,"Responder al alma",_speak)
	var actions := HBoxContainer.new()
	souls.add_child(actions)
	_button(actions,assemble_button,"Reunir las cuatro partes",func(): _action("assemble"))
	_button(actions,disassemble_button,"Separar el conjunto",func(): _action("disassemble"))
	_button(actions,transfer_set_button,"Entregar el conjunto",func(): _action("transfer_set"))
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 42
	box.add_child(feedback)
	_button(box,close_button,"Volver al mapa",close)
	hide()

func _button(parent: Control,button: Button,text: String,action: Callable) -> void:
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)

func open_inventory(state: RefCounted) -> void:
	world_state = state
	feedback.text = ""
	target.clear()
	for id: String in state.party.heroes:
		if id == state.party.active_id:
			continue
		target.add_item(str(state.party.heroes[id].definition.short_name))
		target.set_item_metadata(target.item_count-1,id)
		target.set_item_disabled(target.item_count-1,not state.party.heroes[id].unlocked)
	sets.clear()
	for id: String in state.equipment.sets:
		sets.add_item(str(state.equipment.sets[id].name))
		sets.set_item_metadata(sets.item_count-1,id)
	refresh()
	show()

func refresh() -> void:
	var selected := _instance()
	var gear = world_state.equipment
	var owner: String = world_state.party.active_id
	title.text = "EQUIPO · " + str(world_state.party.active().definition.name)
	inventory.clear()
	for id: String in gear.instances:
		var entry: Dictionary = gear.instances[id]
		if entry.owner != owner:
			continue
		var where: String = "Mochila" if entry.slot.is_empty() else SLOT_NAMES.get(entry.slot,entry.slot)
		inventory.add_item("%s · %s" % [where,gear.items[entry.item].name])
		inventory.set_item_metadata(inventory.item_count-1,id)
		if id == selected:
			inventory.select(inventory.item_count-1)
	if inventory.item_count > 0 and inventory.get_selected_items().is_empty():
		inventory.select(0)
	_item_details()
	_soul_details()

func _instance() -> String:
	var selection := inventory.get_selected_items()
	return "" if selection.is_empty() else str(inventory.get_item_metadata(selection[0]))

func _item_details() -> void:
	var gear = world_state.equipment
	var owner: String = world_state.party.active_id
	var id := _instance()
	slot.clear()
	for key: String in gear.catalog.slots:
		var worn: String = gear.at_slot(owner,key)
		var name: String = "vacío" if worn.is_empty() else str(gear.items[gear.instances[worn].item].name)
		slot.add_item("%s · %s" % [SLOT_NAMES.get(key,key),name])
		slot.set_item_metadata(slot.item_count-1,key)
		var allowed: bool = not id.is_empty() and gear._slot_allowed(gear.instances[id].item,key)
		slot.set_item_disabled(slot.item_count-1,not allowed)
	details.text = "La mochila no concede bonificaciones.\n"
	if not id.is_empty():
		var item: Dictionary = gear.items[gear.instances[id].item]
		details.text = str(item.name) + "\n" + str(item.lore) + "\n"
		if gear._assembled(id):
			details.text += "Parte de un conjunto reunido. Sepáralo en Almas antes de cambiar sus piezas.\n"
		for effect: Dictionary in item.effects:
			details.text += "%s +%d\n" % [EFFECT_NAMES[effect.effect],effect.amount]
		for i in slot.item_count:
			if slot.get_item_metadata(i) == item.default_slot:
				slot.select(i)
	details.text += "\nBONIFICACIONES DEL HÉROE\n"
	var bonuses: Dictionary = gear.bonuses(owner)
	for effect: String in bonuses:
		if bonuses[effect] > 0:
			details.text += "%s +%d\n" % [EFFECT_NAMES[effect],bonuses[effect]]
	for button in [equip_button,remove_button,transfer_button]:
		button.disabled = id.is_empty() or gear._assembled(id)

func _soul_details() -> void:
	if sets.item_count == 0:
		return
	var gear = world_state.equipment
	var id: String = sets.get_selected_metadata()
	var owner: String = world_state.party.active_id
	var definition: Dictionary = gear.sets[id]
	var stage: String = gear.ritual_stage(owner,id)
	soul_text.text = "%s\nBloque de español: %d\n" % [definition.soul.name,definition.ritual.required_block]
	for part: Dictionary in definition.components:
		var worn: String = gear.at_slot(owner,part.slot)
		var found: bool = not worn.is_empty() and gear.instances[worn].item == part.item_id
		soul_text.text += "%s %s\n" % ["✓" if found else "○",gear.items[part.item_id].name]
	var language_ready: bool = gear._language_ready(world_state,id,world_state.day)
	if language_ready:
		soul_text.text += "\nTemor: " + str(gear.language[id].fear)
	memory_a.clear()
	memory_b.clear()
	if language_ready and stage in ["listen","compare_memories","supported_production"]:
		for memory: Dictionary in definition.soul.memories:
			soul_text.text += "\n" + str(memory.text)
			for control in [memory_a,memory_b]:
				control.add_item(str(memory.text))
				control.set_item_metadata(control.item_count-1,memory.id)
	memory_a.visible = stage == "compare_memories"
	memory_b.visible = stage == "compare_memories"
	prompt.text = ""
	match stage:
		"listen": prompt.text = "Pide escuchar los recuerdos. Modelo: " + gear.expected(id,stage)
		"compare_memories": prompt.text = "Elige dos recuerdos distintos y compáralos. Modelo: " + gear.expected(id,stage)
		"supported_production": prompt.text = "Explica tu propósito. Modelo: " + gear.expected(id,stage)
		"independent_argument": prompt.text = definition.ritual.independent_reformulation
		"answer_objection": prompt.text = "Responde al temor del alma sin usar su poder como prueba."
		"delayed_recall": prompt.text = definition.ritual.delayed_recall
		"consent": prompt.text = "Confirma tu compromiso: Acepto este pacto."
		"complete": prompt.text = "El alma reconoce tu pacto. Puedes reunir las partes."
	var ready: bool = not gear.components(owner,id).is_empty() and gear._language_ready(world_state,id,world_state.day)
	if not gear._language_ready(world_state,id,world_state.day):
		prompt.text = "Consolida los bloques anteriores y practica las formas de esta conversación."
	if stage == "delayed_recall" and world_state.day <= gear.rituals[owner][id].answer_objection.day:
		ready = false
		prompt.text = "Vuelve en un día posterior para recordar sin el modelo."
	input.clear()
	input.visible = stage != "complete"
	send_button.visible = stage != "complete"
	send_button.disabled = not ready
	assemble_button.disabled = not gear.consent(owner,id) or gear.components(owner,id).is_empty() or gear.assemblies.has(id)
	var owned: bool = gear.assemblies.has(id) and gear.assemblies[id].owner == owner
	disassemble_button.disabled = not owned
	transfer_set_button.disabled = not owned

func _speak() -> void:
	if not visible or send_button.disabled:
		return
	var memories: Array = []
	if memory_a.visible:
		memories = [memory_a.get_selected_metadata(),memory_b.get_selected_metadata()]
	var result: Dictionary = world_state.equipment.persuade(world_state,sets.get_selected_metadata(),input.text,memories)
	feedback.text = result.message
	if result.ok:
		refresh()
		changed.emit()

func _action(action: String) -> void:
	if not visible:
		return
	var gear = world_state.equipment
	var id := _instance()
	var set_id: String = sets.get_selected_metadata()
	var recipient: String = target.get_selected_metadata()
	var ok := false
	match action:
		"equip":
			if not id.is_empty(): ok = gear.equip(world_state,id,slot.get_selected_metadata())
		"remove": ok = gear.unequip(world_state,id)
		"transfer": ok = gear.transfer(world_state,id,recipient)
		"assemble": ok = gear.assemble(world_state,set_id)
		"disassemble": ok = gear.disassemble(world_state,set_id)
		"transfer_set": ok = gear.transfer_set(world_state,set_id,recipient)
	feedback.text = "Equipo actualizado." if ok else "Revisa los espacios, el pacto y la posición de los héroes."
	if ok:
		refresh()
		changed.emit()

func close() -> void:
	hide()
	closed.emit()
