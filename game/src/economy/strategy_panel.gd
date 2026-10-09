extends ColorRect
const PlayLog = preload("res://src/common/play_log.gd")
signal closed
signal committed
signal battle_requested(id: String)
var world_state: RefCounted
var site_id := ""
var title := Label.new()
var resources := Label.new()
var entries := OptionButton.new()
var category := OptionButton.new()
var cancel_button := Button.new()
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
	panel.position = Vector2(200,22)
	panel.size = Vector2(880,676)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("22252a")
	panel.add_theme_stylebox_override("panel",style)
	# Parchment like the journal; its frame is thicker, so the inner margin shrinks.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 22)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation",8 if paper else 12)
	margin.add_child(box)
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(title)
	resources.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	resources.max_lines_visible = 2
	resources.add_theme_font_size_override("font_size",15)
	box.add_child(resources)
	var offers := HBoxContainer.new()
	box.add_child(offers)
	for kind: String in ["build", "recruit", "upgrade", "artifact"]:
		category.add_item({"build":"Edificios", "recruit":"Tropas", "upgrade":"Mejoras", "artifact":"Artefactos"}[kind])
		category.set_item_metadata(category.item_count - 1, kind)
	category.item_selected.connect(func(_index: int):
		world_state.economy.cancel()
		feedback.text = ""
		_fill_offers()
		refresh())
	offers.add_child(category)
	entries.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entries.clip_text = true
	entries.item_selected.connect(func(_index: int): world_state.economy.cancel(); feedback.text = ""; refresh())
	offers.add_child(entries)
	quantity.min_value = 1
	quantity.max_value = 20
	quantity.value_changed.connect(func(_value: float): refresh())
	offers.add_child(quantity)
	description.custom_minimum_size.y = 90
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description.bbcode_enabled = false
	box.add_child(description)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_add_scroll(box, prompt, 112)
	input.max_length = 300
	input.placeholder_text = "Escribe el pedido en español."
	input.text_submitted.connect(func(_message: String): _submit())
	var reply := HBoxContainer.new()
	box.add_child(reply)
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reply.add_child(input)
	send_button.pressed.connect(_submit)
	reply.add_child(send_button)
	battle_button.text = "Combatir a los guardianes"
	battle_button.pressed.connect(func():
		var id := site_id
		if world_state.economy.mines.has(id) and world_state.economy.contested(world_state,id):
			id = world_state.economy.raid_id(id)
		close()
		battle_requested.emit(id))
	var actions := HBoxContainer.new()
	actions.add_child(battle_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.add_theme_font_size_override("font_size", 15)
	_add_scroll(box, feedback, 48)
	box.add_child(actions)
	cancel_button.text = "Cambiar pedido"
	cancel_button.pressed.connect(func():
		world_state.economy.cancel()
		feedback.text = "Pedido cancelado. No se han gastado recursos."
		refresh())
	actions.add_child(cancel_button)
	close_button.text = "Volver"
	close_button.pressed.connect(close)
	close_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(close_button)
	hide()

func open_site(state: RefCounted, id := "") -> void:
	world_state = state
	site_id = id
	feedback.text = "Elige una opción y completa los tres pasos. Solo se paga al confirmar el último."
	category.select(0)
	_fill_offers()
	refresh()
	show()

func _add_scroll(box: VBoxContainer, label: Label, height: float) -> void:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = height
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	scroll.add_child(label)

func _fill_offers() -> void:
	entries.clear()
	if not site_id.is_empty():
		return
	var economy = world_state.economy
	var kind: String = category.get_selected_metadata()
	var collection: Dictionary = economy.catalog.buildings if kind == "build" else economy.catalog.recruits if kind == "recruit" else economy.catalog.upgrades if kind == "upgrade" else economy.artifact_offers
	for item: String in collection:
		if kind == "build" and item not in economy.catalog.town_buildings.get(world_state.location_at(world_state.hero_cell).get("id", ""), []):
			continue
		entries.add_item(str(collection[item].name))
		entries.set_item_metadata(entries.item_count - 1, {"kind":kind, "id":item})

func refresh() -> void:
	var economy = world_state.economy
	resources.text = "RECURSOS · " + economy.cost_text(world_state.resources)
	input.clear()
	battle_button.hide()
	input.show()
	send_button.show()
	entries.visible = site_id.is_empty()
	category.visible = site_id.is_empty()
	category.disabled = not economy.pending.is_empty()
	cancel_button.visible = site_id.is_empty() and not economy.pending.is_empty()
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
	if entries.item_count == 0:
		description.text = "No hay opciones en esta categoría."
		prompt.text = "Elige otra categoría."
		input.hide()
		send_button.hide()
		return
	var selected: Dictionary = entries.get_selected_metadata()
	var definition: Dictionary = economy.offer(selected.kind,selected.id)
	if selected.kind in ["build","artifact"]:
		quantity.set_value_no_signal(1)
	quantity.visible = selected.kind not in ["build","artifact"]
	quantity.editable = quantity.visible and economy.pending.is_empty()
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
	var step: String = {"request":"1/3 · Escribe qué quieres pedir", "price":"2/3 · Escribe el coste del pedido", "confirm":"3/3 · Confirma el pedido en español"}[economy.phase]
	prompt.text = step + "\n" + economy.cue(world_state,selected.kind,selected.id,amount)
	input.placeholder_text = {"request":"Pide el edificio, las tropas o el objeto.", "price":"Indica los recursos y sus cantidades.", "confirm":"Confirma lo que quieres comprar."}[economy.phase]
	send_button.text = {"request":"Continuar", "price":"Comprobar coste", "confirm":"Confirmar y pagar"}[economy.phase]
	if not denied.is_empty():
		prompt.text = "No disponible: " + denied + "\nElige otra opción o vuelve al mapa."
		input.hide()
		send_button.hide()
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
	if entries.item_count == 0:
		description.text = "No hay opciones en esta categoría."
		prompt.text = "Elige otra categoría."
		input.hide()
		send_button.hide()
		return
	var selected: Dictionary = entries.get_selected_metadata()
	var sent := input.text
	var result: Dictionary = economy.submit(world_state,selected.kind,selected.id,int(quantity.value),sent)
	feedback.text = result.message
	if result.ok and not result.get("committed",false):
		feedback.text = "Paso aceptado; todavía NO se ha pagado ni hecho nada. " + result.message
	PlayLog.write("order",{"kind":selected.kind,"id":selected.id,"text":sent,"ok":result.ok,"committed":result.get("committed",false),"message":result.message})
	if result.ok:
		refresh()
		if result.get("committed",false):
			committed.emit()

func close() -> void:
	if world_state != null:
		world_state.economy.cancel()
	hide()
	closed.emit()