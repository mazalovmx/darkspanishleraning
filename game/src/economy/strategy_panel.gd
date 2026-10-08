extends ColorRect
signal closed
signal committed
signal battle_requested(id: String)
var world_state: RefCounted
var site_id := ""
var title := Label.new()
var resources := Label.new()
var entries := OptionButton.new()
var quantity := SpinBox.new()
var description := RichTextLabel.new()
var prompt := Label.new()
var input := LineEdit.new()
var send_button := Button.new()
var battle_button := Button.new()
var close_button := Button.new()
var feedback := Label.new()
func _ready() -> void:
	color = Color(0,0,0,0.85)
	z_index = 28
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(200,50)
	panel.size = Vector2(880,620)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel",style)
	# Parchment like the journal; its frame is thicker, so the inner margin shrinks.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	if paper:
		panel.position.y = 8
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8 if paper else 12)
	margin.add_child(box)
	box.add_child(title)
	resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resources.add_theme_font_size_override("font_size",15)
	box.add_child(resources)
	var offers := HBoxContainer.new()
	box.add_child(offers)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.clip_text = true
	entries.item_selected.connect(func(_index: int): world_state.economy.cancel(); feedback.text = ""; refresh())
	offers.add_child(entries)
	quantity.min_value = 1
	quantity.max_value = 20
	quantity.value_changed.connect(func(_value: float): refresh())
	offers.add_child(quantity)
	description.custom_minimum_size.y = 110 if paper else 150
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.bbcode_enabled = false
	box.add_child(description)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt)
	input.max_length = 300
	input.placeholder_text = "Escribe el pedido en español."
	input.text_submitted.connect(func(_message: String): _submit())
	box.add_child(input)
	send_button.pressed.connect(_submit)
	box.add_child(send_button)
	battle_button.text = "Combatir a los guardianes"
	battle_button.pressed.connect(func():
		var id := site_id
		if world_state.economy.mines.has(id) and world_state.economy.contested(world_state,id):
			id = world_state.economy.raid_id(id)
		close()
		battle_requested.emit(id))
	box.add_child(battle_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 48
	box.add_child(feedback)
	close_button.text = "Volver"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

func open_site(state: RefCounted, id := "") -> void:
	world_state = state
	site_id = id
	feedback.text = ""
	entries.clear()
	if site_id.is_empty():
		for kind: String in ["build","recruit","upgrade","artifact"]:
			var collection: Dictionary = state.economy.catalog.buildings if kind == "build" else state.economy.catalog.recruits if kind == "recruit" else state.economy.catalog.upgrades if kind == "upgrade" else state.economy.artifact_offers
			for item: String in collection:
				# Only the buildings this town can hold are offered.
				if kind == "build" and item not in state.economy.catalog.town_buildings.get(state.location_at(state.hero_cell).get("id",""),[]):
					continue
				var verb: String = {"build":"Construir","recruit":"Contratar","upgrade":"Mejorar","artifact":"Comprar"}[kind]
				entries.add_item(verb + " · " + str(collection[item].name))
				entries.set_item_metadata(entries.item_count - 1,{"kind":kind,"id":item})
	refresh()
	show()

func refresh() -> void:
	var economy = world_state.economy
	resources.text = "RECURSOS · " + economy.cost_text(world_state.resources)
	input.clear()
	battle_button.hide()
	input.show()
	send_button.show()
	entries.visible = site_id.is_empty()
	quantity.visible = site_id.is_empty()
	var cache: Dictionary = economy.treasure(world_state,site_id)
	resources.visible = cache.is_empty()
	if not cache.is_empty():
		title.text = str(cache.name).to_upper()
		var names: PackedStringArray = []
		for item: String in cache.items:
			names.append(str(world_state.equipment.items[item].name))
		description.text = "Contiene: " + ", ".join(names) + "."
		send_button.text = "Abrir"
		send_button.disabled = false
		if economy.treasure_claimed(world_state,site_id):
			description.text += "\n\nYa has recogido este tesoro."
			prompt.text = ""
			input.hide()
			send_button.hide()
			return
		var watched: bool = cache.guarded and world_state.encounters.get(site_id,{}).get("outcome","") != "victory"
		battle_button.visible = watched
		input.visible = not watched
		send_button.visible = not watched
		prompt.text = "Unos bandidos vigilan el tesoro." if watched else "Da la orden.\n" + economy.treasure_cue(world_state,site_id)
		return
	if not site_id.is_empty():
		var site: Dictionary = economy.site(world_state,site_id)
		title.text = "MINA DE " + str(economy.catalog.resource_names[site.resource]).to_upper()
		description.text = "Ingreso diario: %d de %s.\n\nEl ingreso empieza en el siguiente día de viaje." % [site.daily_income,economy.catalog.resource_names[site.resource]]
		if economy.mines.has(site_id):
			description.text += "\n\nLa mina está bajo tu control."
			prompt.text = ""
			input.hide()
			send_button.hide()
			if economy.contested(world_state,site_id):
				description.text += "\n\nUnos salteadores la disputan: no produce hasta que los expulses."
				battle_button.show()
			return
		var guarded: bool = site.guarded and world_state.encounters.get(site_id,{}).get("outcome","") != "victory"
		battle_button.visible = guarded
		input.visible = not guarded
		send_button.visible = not guarded
		prompt.text = "Los guardianes controlan el acceso." if guarded else "Da la orden.\n" + economy.claim_cue(world_state,site_id)
		send_button.text = "Asegurar la mina"
		send_button.disabled = false
		return
	title.text = "ASENTAMIENTO · " + str(world_state.location_at(world_state.hero_cell).get("name",""))
	var selected: Dictionary = entries.get_selected_metadata()
	var definition: Dictionary = economy.offer(selected.kind,selected.id)
	if selected.kind in ["build","artifact"]:
		quantity.set_value_no_signal(1)
	quantity.editable = selected.kind not in ["build","artifact"] and economy.pending.is_empty()
	entries.disabled = not economy.pending.is_empty()
	var amount := int(quantity.value)
	var denied: String = economy.reason(world_state,selected.kind,selected.id,amount)
	description.text = str(definition.get("description",""))
	if selected.kind == "recruit":
		description.text = "Disponibles esta semana: %d.\nCada ejército tiene un máximo de siete destacamentos." % economy.stock(world_state.location_at(world_state.hero_cell).id,selected.id,world_state.day)
	elif selected.kind == "artifact":
		description.text += "\n\nUna pieza por mercado. La compra se guarda en la mochila del héroe activo."
	elif selected.kind == "upgrade":
		description.text = "La mejora conserva el número de soldados y ocupa un destacamento del nuevo tipo."
	description.text += "\n\nCoste: " + economy.cost_text(economy.cost(selected.kind,selected.id,amount))
	if not denied.is_empty():
		description.text += "\n\n" + denied
	prompt.text = economy.cue(world_state,selected.kind,selected.id,amount)
	send_button.text = {"request":"Pedir","price":"Comprobar el coste","confirm":"Confirmar operación"}[economy.phase]
	send_button.disabled = not denied.is_empty()

func _submit() -> void:
	if not visible or send_button.disabled:
		return
	var economy = world_state.economy
	if not economy.treasure(world_state,site_id).is_empty():
		var result: Dictionary = economy.claim_treasure(world_state,site_id,input.text)
		feedback.text = result.message
		if result.ok:
			refresh()
			committed.emit()
		return
	if not site_id.is_empty():
		if economy.claim(world_state,site_id,input.text):
			feedback.text = "La mina está asegurada."
			refresh()
			committed.emit()
		else:
			feedback.text = economy.claim_feedback(world_state,site_id,input.text)
		return
	var selected: Dictionary = entries.get_selected_metadata()
	var result: Dictionary = economy.submit(world_state,selected.kind,selected.id,int(quantity.value),input.text)
	feedback.text = result.message
	if result.ok:
		refresh()
		if result.get("committed",false):
			committed.emit()

func close() -> void:
	if world_state != null:
		world_state.economy.cancel()
	hide()
	closed.emit()