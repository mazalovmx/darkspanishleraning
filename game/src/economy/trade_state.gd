extends RefCounted
## Authored transaction practice; model prose never grants goods.
var goods: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/economy/market.json"))
var stock: Dictionary = {}
var inventory: Dictionary = {}
var receipts: Array = []
var purchase_count := 0
var pending: Dictionary = {}
var phase := "request"

func _init() -> void:
	for id in goods:
		stock[id] = int(goods[id].stock)
		inventory[id] = 0

func normalize(message: String) -> String:
	var text := message.strip_edges().to_lower()
	for pair in [["á","a"],["é","e"],["í","i"],["ó","o"],["ú","u"]]:
		text = text.replace(pair[0], pair[1])
	return text.trim_prefix("¿").trim_suffix("?").trim_suffix(".").strip_edges()

func phrase(id: String, quantity: int) -> String:
	return "%d %s" % [quantity, goods[id].singular if quantity == 1 else goods[id].plural]

func models(id: String, quantity: int, tier: String = "basic") -> Dictionary:
	var total: int = int(goods[id].price) * quantity
	var verb := "contratar" if goods[id].kind == "recruit" else "comprar"
	var noun := "contratación" if goods[id].kind == "recruit" else "compra"
	var result := {"request": "Quiero %s %s." % [verb, phrase(id, quantity)],
		"price": ("Es " if total == 1 else "Son ") + money(total) + ".",
		"confirm": "Confirmo la %s de %s por %s." % [noun, phrase(id, quantity), money(total)]}
	if tier == "past":
		result.request = "Decidí %s %s." % [verb, phrase(id, quantity)]
		result.price = "El total es %s por %s." % [money(total), phrase(id, quantity)]
	elif tier == "plans":
		result.request = "Voy a %s %s." % [verb, phrase(id, quantity)]
		result.confirm = "Voy a pagar %s por %s." % [money(total), phrase(id, quantity)]
	elif tier == "argument":
		result.request = "Querría %s %s." % [verb, phrase(id, quantity)]
		result.price = "Si pido %s, el total es %s." % [phrase(id, quantity), money(total)]
		result.confirm = "Acepto pagar %s porque necesito %s." % [money(total), phrase(id, quantity)]
	return result

func tier_for(state: RefCounted) -> String:
	var grammar: Array = state.learner.curriculum.allowed_grammar()
	if "conditional" in grammar:
		return "argument"
	if "ir_a_future" in grammar:
		return "plans"
	if "preterite" in grammar:
		return "past"
	return "basic"

func current_models(state: RefCounted, id: String, quantity: int) -> Dictionary:
	return models(id, quantity, str(pending.get("tier", tier_for(state))))

func money(amount: int) -> String:
	return "%d %s" % [amount, "moneda" if amount == 1 else "monedas"]

func _matches(id: String, quantity: int, message: String, stage: String, tier: String = "basic") -> bool:
	if message.length() > 300:
		return false
	var normalized := normalize(message)
	var expected: Dictionary = models(id, quantity, tier)
	if normalized == normalize(expected[stage]):
		return true
	if stage == "request" and tier == "basic":
		return normalized in [normalize("necesito " + phrase(id, quantity)), normalize("quiero " + phrase(id, quantity))]
	return false

func cancel() -> void:
	pending.clear()
	phase = "request"

func submit(state: RefCounted, id: String, quantity: int, message: String) -> Dictionary:
	if not goods.has(id) or quantity < 1 or quantity > 20 or state.active_battle != null:
		return {"ok": false, "message": "Pedido no válido."}
	if state.location_at(state.hero_cell).get("id", "") != "LOC11":
		cancel()
		return {"ok": false, "message": "Visita la venta para comprar."}
	if phase == "request":
		if not _matches(id, quantity, message, "request", tier_for(state)):
			return {"ok": false, "message": "Pide el producto y la cantidad: " + current_models(state, id, quantity).request}
		if int(stock[id]) < quantity:
			return {"ok": false, "message": "No hay existencias suficientes."}
		pending = {"id": id, "quantity": quantity, "total": int(goods[id].price) * quantity,
			"day": state.day, "request": message, "tier": tier_for(state)}
		phase = "price"
		return {"ok": true, "message": "El total es %s. Explica cuánto cuesta." % money(pending.total)}
	if pending.get("id") != id or pending.get("quantity") != quantity or pending.get("day") != state.day:
		cancel()
		return {"ok": false, "message": "El pedido cambia. Empieza de nuevo."}
	if phase == "price":
		if not _matches(id, quantity, message, "price", pending.tier):
			return {"ok": false, "message": "Revisa la cantidad por el precio: " + current_models(state, id, quantity).price}
		pending["price"] = message
		phase = "confirm"
		return {"ok": true, "message": "Correcto. Confirma producto, cantidad y precio."}
	if not _matches(id, quantity, message, "confirm", pending.tier):
		return {"ok": false, "message": "Confirma el pedido completo: " + current_models(state, id, quantity).confirm}
	var total: int = int(goods[id].price) * quantity
	if pending.total != total or int(stock[id]) < quantity or int(state.resources.gold) < total:
		cancel()
		return {"ok": false, "message": "No hay suficientes existencias o monedas. No se cobra nada."}
	if goods[id].kind == "recruit":
		var target := -1
		for i in state.army.size():
			if state.army[i].type == id:
				target = i
				break
		if target == -1 and state.army.size() >= 7:
			cancel()
			return {"ok": false, "message": "Tu ejército ya tiene siete destacamentos."}
		if target >= 0 and state.army[target].count + quantity > 100000:
			cancel()
			return {"ok": false, "message": "Ese destacamento está completo."}
		if target == -1:
			state.army.append({"type": id, "count": quantity})
		else:
			state.army[target].count += quantity
	else:
		inventory[id] += quantity
	state.resources.gold -= total
	stock[id] -= quantity
	purchase_count += 1
	receipts.append({"id": id, "quantity": quantity, "total": total, "day": state.day,
		"request": str(pending.request), "price": str(pending.price), "confirm": message})
	if receipts.size() > 100:
		receipts.pop_front()
	cancel()
	return {"ok": true, "committed": true, "message": "Compra completada: %s. Pagas %s." % [phrase(id, quantity), money(total)]}

func snapshot() -> Dictionary:
	return {"stock": stock.duplicate(), "inventory": inventory.duplicate(),
		"receipts": receipts.duplicate(true), "purchase_count": purchase_count}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant, day: int) -> bool:
	if not data is Dictionary or data.size() != 4 or not data.get("stock") is Dictionary or not data.get("inventory") is Dictionary:
		return false
	if data.stock.size() != goods.size() or data.inventory.size() != goods.size():
		return false
	for id in goods:
		if not _integer(data.stock.get(id), 0, int(goods[id].stock)) or not _integer(data.inventory.get(id), 0, 1000000):
			return false
	if not data.get("receipts") is Array or data.receipts.size() > 100 or not _integer(data.get("purchase_count"), 0, 1000000):
		return false
	if data.receipts.size() != mini(int(data.purchase_count), 100):
		return false
	var previous_day := 0
	for receipt in data.receipts:
		if not receipt is Dictionary or receipt.size() != 7 or not receipt.get("id") is String or not goods.has(receipt.id):
			return false
		if not _integer(receipt.get("quantity"), 1, 20) or not _integer(receipt.get("day"), 1, day) or receipt.day < previous_day:
			return false
		if not _integer(receipt.get("total"), 1, 1000000) or receipt.total != int(goods[receipt.id].price) * int(receipt.quantity):
			return false
		var matches_tier := false
		for tier in ["basic", "past", "plans", "argument"]:
			var all_stages := true
			for stage in ["request", "price", "confirm"]:
				if not receipt.get(stage) is String or not _matches(receipt.id, int(receipt.quantity), receipt[stage], stage, tier):
					all_stages = false
			if all_stages:
				matches_tier = true
		if not matches_tier:
			return false
		previous_day = int(receipt.day)
	stock = data.stock.duplicate()
	inventory = data.inventory.duplicate()
	receipts = data.receipts.duplicate(true)
	purchase_count = int(data.purchase_count)
	cancel()
	return true
