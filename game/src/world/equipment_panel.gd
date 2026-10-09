extends ColorRect
signal closed
signal changed
const SLOT_NAMES := {"head":"Cabeza","neck":"Cuello","torso":"Torso","cloak":"Capa","feet":"Pies","weapon":"Arma","shield":"Escudo","ring_1":"Anillo 1","ring_2":"Anillo 2","misc_1":"Accesorio 1","misc_2":"Accesorio 2","misc_3":"Accesorio 3","misc_4":"Accesorio 4","misc_5":"Accesorio 5"}
const EFFECT_NAMES := {"army_attack":"Ataque","army_defense":"Defensa","army_hp_percent":"Salud (%)","army_initiative":"Iniciativa","army_luck":"Suerte","army_morale":"Moral","world_movement":"Movimiento","ranged_damage_percent":"Daño a distancia (%)"}
var world_state: RefCounted
var title := Label.new()
var tabs := TabContainer.new()
var inventory := ItemList.new()
var body = preload("res://src/world/equipment_body.gd").new()
var backpack_title := Label.new()
var selected_instance := ""
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
var cargo := ItemList.new()
var amount := SpinBox.new()
var give_button := Button.new()
var units: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/combat/stacks.json")).units
var feedback := Label.new()
var close_button := Button.new()

func _ready() -> void:
	color = Color(0,0,0,0.85)
	z_index = 29
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(30,22)
	panel.size = Vector2(1220,676)
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
	pack.add_child(body)
	body.slot_selected.connect(_body_slot_selected)
	var backpack := VBoxContainer.new()
	backpack.custom_minimum_size.x = 250
	pack.add_child(backpack)
	backpack.add_child(backpack_title)
	inventory.custom_minimum_size.x = 250
	inventory.fixed_column_width = 240
	inventory.fixed_icon_size = Vector2i(32, 32)
	inventory.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory.item_selected.connect(func(index: int): selected_instance = str(inventory.get_item_metadata(index)); _item_details())
	backpack.add_child(inventory)
	var controls := VBoxContainer.new()
	controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pack.add_child(controls)
	details.custom_minimum_size.y = 130
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	controls.add_child(details)
	slot.clip_text = true
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
	var troops := VBoxContainer.new()
	troops.name = "Tropas"
	tabs.add_child(troops)
	cargo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cargo.item_selected.connect(func(_index: int): _cargo_limit())
	troops.add_child(cargo)
	var giving := HBoxContainer.new()
	var count_label := Label.new()
	count_label.text = "Cantidad:"
	giving.add_child(count_label)
	amount.min_value = 1
	giving.add_child(amount)
	troops.add_child(giving)
	_button(troops,give_button,"Entregar al destinatario",_give)
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
		if entry.owner != owner or not entry.slot.is_empty():
			continue
		var where: String = "Mochila" if entry.slot.is_empty() else SLOT_NAMES.get(entry.slot,entry.slot)
		inventory.add_item("%s · %s" % [where,gear.items[entry.item].name], _item_icon(gear.items[entry.item]))
		inventory.set_item_metadata(inventory.item_count-1,id)
		if id == selected:
			inventory.select(inventory.item_count-1)
	if inventory.item_count > 0 and selected.is_empty():
		inventory.select(0)
	if selected.is_empty() and inventory.item_count > 0:
		selected_instance = str(inventory.get_item_metadata(0))
	backpack_title.text = "MOCHILA · %d objetos" % inventory.item_count
	_item_details()
	_refresh_souls()
	_soul_details()
	var chosen := cargo.get_selected_items()
	cargo.clear()
	for index in world_state.army.size():
		var stack: Dictionary = world_state.army[index]
		cargo.add_item("Tropa · %s · %d" % [units[stack.type].name,stack.count])
		cargo.set_item_metadata(cargo.item_count-1,{"kind":"stack","key":index,"count":int(stack.count)})
	var goods: Dictionary = world_state.trade.goods
	for item: String in goods:
		var held := int(world_state.party.active().inventory.get(item,0))
		if goods[item].kind == "supply" and held > 0:
			cargo.add_item("Provisión · %s · %d" % [goods[item].name,held])
			cargo.set_item_metadata(cargo.item_count-1,{"kind":"supply","key":item,"count":held})
	if cargo.item_count > 0:
		cargo.select(mini(chosen[0],cargo.item_count-1) if not chosen.is_empty() else 0)
	_cargo_limit()

func _cargo_limit() -> void:
	var chosen := cargo.get_selected_items()
	give_button.disabled = chosen.is_empty() or target.item_count == 0
	if not chosen.is_empty():
		amount.max_value = cargo.get_item_metadata(chosen[0]).count

func _give() -> void:
	var chosen := cargo.get_selected_items()
	if not visible or chosen.is_empty() or target.item_count == 0:
		return
	var entry: Dictionary = cargo.get_item_metadata(chosen[0])
	var ok: bool = world_state.transfer(entry.kind,str(target.get_selected_metadata()),entry.key,int(amount.value))
	feedback.text = "Entrega hecha." if ok else "No se puede entregar: los héroes deben estar en la misma casilla, sin órdenes preparadas, y con espacio en el ejército."
	if ok:
		refresh()
		changed.emit()

func _instance() -> String:
	if world_state != null and world_state.equipment.instances.has(selected_instance) and world_state.equipment.instances[selected_instance].owner == world_state.party.active_id:
		return selected_instance
	selected_instance = ""
	return ""

func _body_slot_selected(key: String) -> void:
	var worn: String = world_state.equipment.at_slot(world_state.party.active_id,key)
	if not worn.is_empty():
		selected_instance = worn
		inventory.deselect_all()
		_item_details()
	for index in slot.item_count:
		if slot.get_item_metadata(index) == key:
			slot.select(index)
			break
	body.refresh(world_state,SLOT_NAMES,_item_icon,key)

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
		details.text = _describe_item(item, id)
		if gear._assembled(id):
			details.text += "Parte de un conjunto reunido. Sepáralo en Almas antes de cambiar sus piezas.\n"
		for effect: Dictionary in item.effects:
			details.text += "%s +%d\n" % [EFFECT_NAMES[effect.effect],effect.amount]
		for i in slot.item_count:
			if slot.get_item_metadata(i) == (gear.instances[id].slot if not gear.instances[id].slot.is_empty() else item.default_slot):
				slot.select(i)
	details.text += "\nBONIFICACIONES DEL HÉROE\n"
	var bonuses: Dictionary = gear.bonuses(owner)
	for effect: String in bonuses:
		if bonuses[effect] > 0:
			details.text += "%s +%d\n" % [EFFECT_NAMES[effect],bonuses[effect]]
	for button in [equip_button,remove_button,transfer_button]:
		button.disabled = id.is_empty() or gear._assembled(id)
	if not id.is_empty():
		remove_button.disabled = remove_button.disabled or gear.instances[id].slot.is_empty()
	body.refresh(world_state,SLOT_NAMES,_item_icon,str(slot.get_selected_metadata()) if slot.item_count > 0 else "")

func _soul_details() -> void:
	for control in [memory_a,memory_b,input,send_button,assemble_button,disassemble_button,transfer_set_button]:
		control.visible = sets.item_count > 0
	if sets.item_count == 0:
		soul_text.text = "Todavía no hay un conjunto completo. Las almas no se reciben al empezar.\n\nBusca sus cuatro componentes como recompensas de investigaciones y equípalos en el mismo héroe. Cada pieza indica su conjunto en Equipo."
		prompt.text = "Reúne y equipa las cuatro partes para escuchar al alma; después acuerda el pacto y activa el conjunto."
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
	var set_id: String = str(sets.get_selected_metadata()) if sets.item_count > 0 else ""
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

func _item_icon(item: Dictionary) -> Texture2D:
	var symbols := {"boots":"boots", "sandals":"boots", "amulet":"pearl-necklace", "necklace":"pearl-necklace"}
	if symbols.has(str(item.get("type", ""))):
		return load("res://assets/third_party/game_icons/" + symbols[item.type] + ".svg")
	var names := {"helmet":"helmet", "crown":"helmet", "hood":"helmet", "cuirass":"armor", "chainmail":"armor", "robe":"armor", "shield":"shield", "buckler":"shieldSmall", "sword":"sword", "dagger":"dagger", "axe":"axe", "mace":"hammer", "staff":"wand", "bow":"bow", "crossbow":"bow", "quiver":"bow", "reliquary":"scroll"}
	var path: String = "res://assets/third_party/ravenmore/" + names.get(str(item.get("type", "")), "backpack") + ".png"
	return load(path) if ResourceLoader.exists(path) else null

func _set_progress(set_id: String) -> Dictionary:
	var gear = world_state.equipment
	var owner: String = world_state.party.active_id
	var held := 0
	var worn := 0
	for part: Dictionary in gear.sets[set_id].components:
		for entry: Dictionary in gear.instances.values():
			if entry.owner == owner and entry.item == part.item_id:
				held += 1
				if entry.slot == part.slot:
					worn += 1
				break
	return {"held":held,"worn":worn}

func _refresh_souls() -> void:
	var selected: String = str(sets.get_selected_metadata()) if sets.item_count > 0 else ""
	sets.clear()
	for id: String in world_state.equipment.sets:
		if _set_progress(id).worn < 4:
			continue
		sets.add_item(str(world_state.equipment.sets[id].name))
		sets.set_item_metadata(sets.item_count-1,id)
		if id == selected:
			sets.select(sets.item_count-1)
	sets.visible = sets.item_count > 0

func _describe_item(item: Dictionary, instance: String) -> String:
	var gear = world_state.equipment
	var rarity := ""
	for entry: Dictionary in gear.catalog.rarities:
		if entry.id == item.rarity:
			rarity = str(entry.name)
	var location: String = gear.instances[instance].slot
	var result := "%s\n%s · %s\n%s\n%s\n" % [item.name,gear.types[item.type].get("name",item.type),rarity,"En la mochila (bonos inactivos)" if location.is_empty() else "Equipado · " + SLOT_NAMES[location],item.lore]
	var component := false
	for id: String in gear.sets:
		for part: Dictionary in gear.sets[id].components:
			if part.item_id != item.id:
				continue
			component = true
			var progress := _set_progress(id)
			result += "\nCONJUNTO: %s\nAlma: %s\nComponentes: %d/4 encontrados · %d/4 equipados\n" % [gear.sets[id].name,gear.sets[id].soul.name,progress.held,progress.worn]
			result += "Conjunto activado.\n" if gear._assembled(instance) else "Alma latente: reúne y equipa las cuatro partes; después completa el pacto en Almas.\n"
	if not component:
		result += "Sin conjunto · sin alma vinculada.\n"
	return result + "\nESTADÍSTICAS DE LA PIEZA\n"
