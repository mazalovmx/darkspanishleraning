extends ColorRect
const TITLES := {"LOC11": "MERCADO DE LA VENTA", "LOC15": "HOSPITAL DE MIRALBA · MÉDICO"}
var title := Label.new()
signal closed
signal purchased
var world_state: RefCounted
var products := OptionButton.new()
var quantity := SpinBox.new()
var description := Label.new()
var prompt := Label.new()
var input := LineEdit.new()
var send_button := Button.new()
var feedback := Label.new()
var inventory_label := Label.new()
var close_button := Button.new()
func _ready() -> void:
	color = Color(0, 0, 0, 0.85)
	z_index = 25
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.position = Vector2(210, 75)
	panel.size = Vector2(860, 560)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#22252a")
	panel.add_theme_stylebox_override("panel", style)
	# Parchment like the journal; its frame is thicker, so the inner margin shrinks.
	var paper: bool = preload("res://src/common/parchment_theme.gd").apply(panel)
	if paper:
		panel.position.y = 40
	add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6 if paper and side in ["top", "bottom"] else 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	title.text = "MERCADO DE LA VENTA"
	box.add_child(title)
	var row := HBoxContainer.new()
	products.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(products)
	quantity.min_value = 1
	quantity.max_value = 20
	quantity.step = 1
	row.add_child(quantity)
	box.add_child(row)
	products.item_selected.connect(func(_index: int): _refresh())
	quantity.value_changed.connect(func(_value: float): _refresh())
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(prompt)
	input.max_length = 300
	input.placeholder_text = "Escribe tu petición en español."
	input.text_submitted.connect(submit)
	box.add_child(input)
	send_button.text = "Decir"
	send_button.pressed.connect(func(): submit(input.text))
	box.add_child(send_button)
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.custom_minimum_size.y = 70
	box.add_child(feedback)
	inventory_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(inventory_label)
	close_button.text = "Volver sin pedido pendiente"
	close_button.pressed.connect(close)
	box.add_child(close_button)
	hide()

## Opens the counter of the place the hero stands on: the inn's market or the healer.
func open_market(state: RefCounted) -> bool:
	var location := str(state.location_at(state.hero_cell).get("id", ""))
	if state.active_battle != null or state.trade.offers_at(location).is_empty():
		return false
	world_state = state
	world_state.trade.cancel()
	title.text = TITLES.get(location, "MERCADO")
	products.clear()
	for id in world_state.trade.offers_at(location):
		products.add_item(world_state.trade.goods[id].name)
		products.set_item_metadata(products.item_count - 1, id)
	quantity.value = 1
	feedback.text = "Practica petición, precio y confirmación. Aún no hay ningún cobro."
	input.clear()
	_refresh()
	show()
	input.grab_focus()
	return true

func _refresh() -> void:
	if world_state == null or products.item_count == 0:
		return
	var id: String = products.get_item_metadata(products.selected)
	var trade = world_state.trade
	var item: Dictionary = trade.goods[id]
	description.text = "%s · Precio: %d monedas · Existencias: %d · Tu oro: %d" % [item.name, item.price, trade.stock[id], world_state.resources.gold]
	if item.has("use"):
		description.text += "\n" + str(item.use)
	var phase_name: String = {"request": "1. Pide producto y cantidad", "price": "2. Comprueba el precio", "confirm": "3. Confirma el pedido" if item.kind == "service" else "3. Confirma la compra"}[trade.phase]
	prompt.text = phase_name + "\n" + trade.cue(world_state, id, int(quantity.value))
	products.disabled = trade.phase != "request"
	quantity.editable = trade.phase == "request"
	var items: Array[String] = []
	for item_id in trade.inventory:
		if trade.inventory[item_id] > 0:
			items.append("%s: %d" % [trade.goods[item_id].name, trade.inventory[item_id]])
	inventory_label.text = "Provisiones: " + (", ".join(items) if not items.is_empty() else "ninguna")

func submit(message: String) -> void:
	if world_state == null or not visible:
		return
	var id: String = products.get_item_metadata(products.selected)
	var result: Dictionary = world_state.trade.submit(world_state, id, int(quantity.value), message)
	feedback.text = result.message
	if result.ok:
		input.clear()
	_refresh()
	if result.get("committed", false):
		purchased.emit()

func close() -> void:
	if world_state != null:
		world_state.trade.cancel()
	hide()
	closed.emit()
