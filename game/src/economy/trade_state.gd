extends RefCounted
## Authored transaction practice; model prose never grants goods.
const Curriculum = preload("res://src/spanish/curriculum.gd")
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
	var text := Curriculum.fold(message)
	return text.trim_prefix("¿").trim_suffix("?").trim_suffix(".").strip_edges()

## Goods and services are offered at their "locations" (the roadside inn by default).
func sold_at(id: String, location: String) -> bool:
	return goods.has(id) and location in goods[id].get("locations", ["LOC11"])

func offers_at(location: String) -> Array:
	return goods.keys().filter(func(id: String) -> bool: return sold_at(id, location))

## Inventories equal once goods added after a save count as zero.
static func same_inventory(a: Dictionary, b: Dictionary) -> bool:
	for id in a.keys() + b.keys():
		if int(a.get(id, 0)) != int(b.get(id, 0)):
			return false
	return true

func phrase(id: String, quantity: int) -> String:
	return "%d %s" % [quantity, goods[id].singular if quantity == 1 else goods[id].plural]

func models(id: String, quantity: int, tier: String = "basic") -> Dictionary:
	var total: int = int(goods[id].price) * quantity
	var verb: String = goods[id].get("verb", "contratar" if goods[id].kind == "recruit" else "comprar")
	var noun: String = goods[id].get("confirm_noun", "la contratación" if goods[id].kind == "recruit" else "la compra")
	# A service can name what is booked before the quantity: "una habitación para 2 noches".
	var object: String = (str(goods[id].frame) + " " if goods[id].has("frame") else "") + phrase(id, quantity)
	var result := {"request": "Quiero %s %s." % [verb, object],
		"price": ("Es " if total == 1 else "Son ") + money(total) + ".",
		"confirm": "Confirmo %s de %s por %s." % [noun, phrase(id, quantity), money(total)]}
	if tier == "past":
		result.request = "Decidí %s %s." % [verb, object]
		result.price = "El total es %s por %s." % [money(total), phrase(id, quantity)]
	elif tier == "plans":
		result.request = "Voy a %s %s." % [verb, object]
		result.confirm = "Voy a pagar %s por %s." % [money(total), phrase(id, quantity)]
	elif tier == "argument":
		result.request = "Querría %s %s." % [verb, object]
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

const NUMBER_WORDS := ["", "uno", "dos", "tres", "cuatro", "cinco", "seis", "siete", "ocho", "nueve", "diez",
	"once", "doce", "trece", "catorce", "quince", "dieciseis", "diecisiete", "dieciocho", "diecinueve", "veinte"]
const PRICE_VERBS := ["es", "son", "cuesta", "cuestan", "vale", "valen"]
# Per stage and tier: accepted verb forms, other required words, and whether the
# quantity + product and the total in coins must appear. Word order is free.
const RULES := {
	"request": {"basic": {"verbs": ["quiero", "necesito"], "items": true},
		"past": {"verbs": ["decidi"], "items": true},
		"plans": {"verbs": ["voy a"], "items": true},
		"argument": {"verbs": ["querria", "me gustaria"], "items": true}},
	"price": {"basic": {"verbs": PRICE_VERBS, "total": true},
		"past": {"verbs": PRICE_VERBS, "total": true, "items": true},
		"plans": {"verbs": PRICE_VERBS, "total": true},
		"argument": {"verbs": PRICE_VERBS, "words": ["si"], "total": true, "items": true}},
	"confirm": {"basic": {"verbs": ["confirmo"], "total": true, "items": true},
		"past": {"verbs": ["confirmo"], "total": true, "items": true},
		"plans": {"verbs": ["voy a"], "total": true, "items": true},
		"argument": {"verbs": ["acepto", "pagaria"], "words": ["porque"], "total": true, "items": true}}}
const REMINDERS := {
	"request": {"basic": "Pide en presente: quiero / necesito + cantidad + producto. Tras «quiero» puedes poner un infinitivo (comprar, contratar).",
		"past": "Pretérito de decidir: yo decidí. Cuenta lo que decidiste: decidí + infinitivo + cantidad + producto.",
		"plans": "Plan con ir a + infinitivo: yo voy a + comprar / contratar + cantidad + producto.",
		"argument": "Condicional de cortesía: querer → querría (o me gustaría) + infinitivo + cantidad + producto."},
	"price": {"basic": "Precio: ser → es (una moneda) / son (varias), o costar → cuesta / cuestan + el total en monedas.",
		"past": "Resume el total: el total es + monedas + por + cantidad + producto.",
		"plans": "Precio: ser → es / son, o costar → cuesta / cuestan + el total en monedas.",
		"argument": "Hipótesis: si + presente (pedir → pido) + cantidad + producto; luego el total con es / son + monedas."},
	"confirm": {"basic": "Confirma en primera persona: confirmar → confirmo + la compra de + cantidad + producto + por + total.",
		"past": "Confirma en primera persona: confirmar → confirmo + la compra de + cantidad + producto + por + total.",
		"plans": "Plan con ir a: voy a pagar + total + por + cantidad + producto.",
		"argument": "Acepta y da una razón: acepto pagar + total + porque + necesitar → necesito + cantidad + producto."}}

## The reminder for a stage, naming a service's own verb (reservar, pagar) instead of
## comprar / contratar.
func reminder(id: String, stage: String, tier: String) -> String:
	var text := str(REMINDERS[stage][tier])
	if goods.has(id) and goods[id].has("verb"):
		text = text.replace("(comprar, contratar)", "(%s)" % goods[id].verb).replace("comprar / contratar", str(goods[id].verb))
	return text

func words(message: String) -> String:
	var text := normalize(message)
	for mark in [",", ".", ";", ":", "!", "¡", "?", "¿", "\"", "«", "»"]:
		text = text.replace(mark, " ")
	return " " + " ".join(text.split(" ", false)) + " "

func _numbers(amount: int, feminine: bool) -> Array:
	var result := [str(amount)]
	if amount == 1:
		result.append_array(["una"] if feminine else ["un", "uno"])
	elif amount < NUMBER_WORDS.size():
		result.append(NUMBER_WORDS[amount])
	return result

func _has_items(text: String, id: String, quantity: int) -> bool:
	var noun: String = words(goods[id].singular if quantity == 1 else goods[id].plural).strip_edges()
	var head: String = words(goods[id].singular).strip_edges().get_slice(" ", 0)
	for number in _numbers(quantity, bool(goods[id].get("feminine", head.ends_with("a") or head.ends_with("on")))):
		if text.contains(" %s %s " % [number, noun]):
			return true
	return false

func _has_total(text: String, total: int) -> bool:
	for number in _numbers(total, true):
		if text.contains(" %s %s " % [number, "moneda" if total == 1 else "monedas"]):
			return true
	return false

## Names what a sentence still lacks; empty when it is accepted.
func missing(id: String, quantity: int, message: String, stage: String, tier: String = "basic") -> Array[String]:
	var result: Array[String] = []
	if message.length() > 300:
		result.append("una frase más corta")
		return result
	if normalize(message) == normalize(models(id, quantity, tier)[stage]):
		return result
	var rule: Dictionary = RULES[stage][tier]
	var text := words(message)
	if not rule.verbs.any(func(verb: String) -> bool: return text.contains(" %s " % verb)):
		result.append("la forma verbal")
	for word in rule.get("words", []):
		if not text.contains(" %s " % word):
			result.append("«%s»" % word)
	if rule.get("items", false) and not _has_items(text, id, quantity):
		result.append("la cantidad con el producto")
	if rule.get("total", false) and not _has_total(text, int(goods[id].price) * quantity):
		result.append("el total en monedas")
	return result

func _matches(id: String, quantity: int, message: String, stage: String, tier: String = "basic") -> bool:
	return missing(id, quantity, message, stage, tier).is_empty()

## The cue shown instead of a model sentence: facts to express, never the sentence.
func cue(state: RefCounted, id: String, quantity: int) -> String:
	var tier := str(pending.get("tier", tier_for(state)))
	var facts := "Producto: %s · Total: %s" % [phrase(id, quantity), money(int(goods[id].price) * quantity)]
	return facts + "\nRecuerda: " + reminder(id, phase, tier)

## The argument tier belongs to the last block, where tildes count (master spec 1.3).
func spelling(message: String, model: String, stage: String, tier: String) -> String:
	if tier != "argument":
		return ""
	var errors := Curriculum.orthography_errors(message, [model, str(REMINDERS[stage][tier])])
	return "" if errors.is_empty() else "En este nivel cuentan las tildes: " + ", ".join(errors) + "."

func _rejection(id: String, quantity: int, message: String, tier: String) -> String:
	var gaps := missing(id, quantity, message, phase, tier)
	var text := "Falta " + (", ".join(gaps.slice(0, gaps.size() - 1)) + " y " + gaps[-1] if gaps.size() > 1 else gaps[0]) + "."
	return text + "\nRecuerda: " + reminder(id, phase, tier)

func cancel() -> void:
	pending.clear()
	phase = "request"

func submit(state: RefCounted, id: String, quantity: int, message: String) -> Dictionary:
	if state.planning_active():
		return {"ok": false, "message": "Resuelve primero las órdenes preparadas."}
	if not goods.has(id) or quantity < 1 or quantity > 20 or state.active_battle != null:
		return {"ok": false, "message": "Pedido no válido."}
	if not sold_at(id, str(state.location_at(state.hero_cell).get("id", ""))):
		cancel()
		return {"ok": false, "message": "Aquí no se ofrece eso." if not offers_at(str(state.location_at(state.hero_cell).get("id", ""))).is_empty() else "Visita la venta para comprar."}
	if phase == "request":
		if not _matches(id, quantity, message, "request", tier_for(state)):
			return {"ok": false, "message": _rejection(id, quantity, message, tier_for(state))}
		var request_spelling := spelling(message, models(id, quantity, tier_for(state)).request, "request", tier_for(state))
		if not request_spelling.is_empty():
			return {"ok": false, "message": request_spelling}
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
			return {"ok": false, "message": _rejection(id, quantity, message, pending.tier)}
		var price_spelling := spelling(message, models(id, quantity, pending.tier).price, "price", pending.tier)
		if not price_spelling.is_empty():
			return {"ok": false, "message": price_spelling}
		pending["price"] = message
		phase = "confirm"
		return {"ok": true, "message": "Correcto. Confirma producto, cantidad y precio."}
	if not _matches(id, quantity, message, "confirm", pending.tier):
		return {"ok": false, "message": _rejection(id, quantity, message, pending.tier)}
	var confirm_spelling := spelling(message, models(id, quantity, pending.tier).confirm, "confirm", pending.tier)
	if not confirm_spelling.is_empty():
		return {"ok": false, "message": confirm_spelling}
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
	elif id == "treatment":
		# The healer treats the active hero at once.
		var patient = state.party.active()
		patient.health = mini(100, int(patient.health) + 40 * quantity)
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
	var done := "Reserva hecha" if id == "room" else "Cura recibida" if id == "treatment" else "Compra completada"
	return {"ok": true, "committed": true, "message": "%s: %s. Pagas %s." % [done, phrase(id, quantity), money(total)]}

func snapshot() -> Dictionary:
	return {"stock": stock.duplicate(), "inventory": inventory.duplicate(),
		"receipts": receipts.duplicate(true), "purchase_count": purchase_count}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant, day: int) -> bool:
	if not data is Dictionary or data.size() != 4 or not data.get("stock") is Dictionary or not data.get("inventory") is Dictionary:
		return false
	# A save written before goods were added lacks them: they start full and empty.
	for table in [data.stock, data.inventory]:
		for id in table:
			if not goods.has(id):
				return false
	for id in goods:
		if not _integer(data.stock.get(id, int(goods[id].stock)), 0, int(goods[id].stock)) or not _integer(data.inventory.get(id, 0), 0, 1000000):
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
	for id in goods:
		stock[id] = int(data.stock.get(id, int(goods[id].stock)))
		inventory[id] = int(data.inventory.get(id, 0))
	receipts = data.receipts.duplicate(true)
	purchase_count = int(data.purchase_count)
	cancel()
	return true
