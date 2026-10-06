extends RefCounted
## Canonical resource transactions. Quotes never spend; only validated confirmations do.
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/economy/strategy.json"))
var buildings: Dictionary = {}
var recruited: Dictionary = {}
var mines: Dictionary = {}
var receipts: Array = []
var purchase_count := 0
var last_income_day := 1
var pending: Dictionary = {}
var phase := "request"
const TIERS := ["basic","past","plans","argument"]

func offer(kind: String, id: String) -> Dictionary:
	var collection: Dictionary = catalog.buildings if kind == "build" else catalog.recruits if kind == "recruit" else catalog.upgrades if kind == "upgrade" else {}
	if not collection.has(id):
		return {}
	var result: Dictionary = collection[id].duplicate(true)
	result["kind"] = kind
	result["id"] = id
	return result

func cost(kind: String, id: String, quantity: int) -> Dictionary:
	var definition := offer(kind,id)
	var result := {}
	if definition.is_empty():
		return result
	for resource in definition.cost:
		result[resource] = int(definition.cost[resource]) * quantity
	return result

func cost_text(amounts: Dictionary) -> String:
	var parts: PackedStringArray = []
	for resource in catalog.resource_names:
		if amounts.has(resource):
			parts.append("%d de %s" % [amounts[resource],catalog.resource_names[resource]])
	return " y ".join(parts)

func models(kind: String, id: String, quantity: int, tier := "basic") -> Dictionary:
	var definition := offer(kind,id)
	if definition.is_empty():
		return {}
	var target: String = definition.name if kind == "build" else "%d %s" % [quantity,definition.name]
	var verb := "construir" if kind == "build" else "contratar" if kind == "recruit" else "mejorar a"
	var total := cost_text(cost(kind,id,quantity))
	var request := "Quiero"
	if tier == "past":
		request = "Decidí"
	elif tier == "plans":
		request = "Voy a"
	elif tier == "argument":
		request = "Querría"
	return {"request":"%s %s %s." % [request,verb,target],
		"price":("Si pido %s, el coste total es %s." % [target,total]) if tier == "argument" else "El coste total es %s." % total,
		"confirm":("Acepto pagar %s porque necesito %s." % [total,target]) if tier == "argument" else ("Voy a pagar %s por %s." % [total,target]) if tier == "plans" else "Confirmo %s por %s." % [target,total]}

func current_models(world: RefCounted, kind: String, id: String, quantity: int) -> Dictionary:
	return models(kind,id,quantity,str(pending.get("tier",world.trade.tier_for(world))))

func cancel() -> void:
	pending.clear()
	phase = "request"

func _location(world: RefCounted) -> String:
	return world.location_at(world.hero_cell).get("id","")

func stock(location: String, id: String, day: int) -> int:
	if not catalog.recruits.has(id):
		return 0
	var definition: Dictionary = catalog.recruits[id]
	var built: int = int(buildings.get(location,{}).get(definition.building,0))
	if built == 0:
		return 0
	var weeks := int((day - 1) / 7) - int((built - 1) / 7) + 1
	return mini(100000,maxi(0,int(definition.weekly) * weeks - int(recruited.get(location,{}).get(id,0))))

func _army_after(world: RefCounted, kind: String, id: String, quantity: int) -> Array:
	var army: Array = world.army.duplicate(true)
	var target := id
	if kind == "upgrade":
		target = catalog.upgrades[id].target
		var source := -1
		for i in army.size():
			if army[i].type == id and army[i].count >= quantity:
				source = i
				break
		if source == -1:
			return []
		army[source].count -= quantity
		if army[source].count == 0:
			army.remove_at(source)
	var merge := -1
	for i in army.size():
		if army[i].type == target:
			merge = i
			break
	if merge == -1:
		if army.size() >= 7:
			return []
		army.append({"type":target,"count":quantity})
	else:
		if army[merge].count + quantity > 100000:
			return []
		army[merge].count += quantity
	return army

func reason(world: RefCounted, kind: String, id: String, quantity: int) -> String:
	var definition := offer(kind,id)
	var location := _location(world)
	if world.map_id != "province_160x120_v1" or location not in catalog.towns:
		return "Visita un asentamiento con licencia de construcción."
	if definition.is_empty() or quantity < 1 or quantity > 20 or world.active_battle != null or not world.trade.pending.is_empty():
		return "Termina la acción actual y revisa el pedido."
	var local_buildings: Dictionary = buildings.get(location,{})
	if kind == "build":
		if quantity != 1 or local_buildings.has(id):
			return "El edificio ya existe o la cantidad no es válida."
		for built_day in local_buildings.values():
			if built_day == world.day:
				return "Solo se construye un edificio por asentamiento y día."
		for requirement in definition.requires:
			if not local_buildings.has(requirement):
				return "Falta un edificio necesario."
	else:
		if not local_buildings.has(definition.building):
			return "Construye primero el edificio de este servicio."
		if kind == "recruit" and stock(location,id,world.day) < quantity:
			return "No quedan suficientes tropas esta semana."
		if _army_after(world,kind,id,quantity).is_empty():
			return "Revisa las tropas disponibles y los siete espacios del ejército."
	for resource in definition.cost:
		if int(world.resources[resource]) < int(definition.cost[resource]) * quantity:
			return "No hay recursos suficientes. No se cobra nada."
	return ""

func submit(world: RefCounted, kind: String, id: String, quantity: int, message: String) -> Dictionary:
	var denied := reason(world,kind,id,quantity)
	if not denied.is_empty():
		cancel()
		return {"ok":false,"message":denied}
	var tier: String = str(pending.get("tier",world.trade.tier_for(world)))
	var expected := models(kind,id,quantity,tier)
	if message.length() > 300 or world.trade.normalize(message) != world.trade.normalize(expected[phase]):
		return {"ok":false,"message":"Revisa el pedido y escribe una frase completa. Modelo: " + str(expected[phase])}
	var location := _location(world)
	if phase == "request":
		pending = {"kind":kind,"id":id,"quantity":quantity,"day":world.day,"hero":world.party.active_id,
			"location":location,"tier":tier,"request":message.strip_edges()}
		phase = "price"
		return {"ok":true,"message":"Explica el coste completo: " + cost_text(cost(kind,id,quantity))}
	if pending.kind != kind or pending.id != id or pending.quantity != quantity or pending.day != world.day or pending.hero != world.party.active_id or pending.location != location:
		cancel()
		return {"ok":false,"message":"El pedido ha cambiado. Empieza de nuevo."}
	if phase == "price":
		pending["price"] = message.strip_edges()
		phase = "confirm"
		return {"ok":true,"message":"Confirma la operación y todos los recursos."}
	var amounts := cost(kind,id,quantity)
	# All checks above are synchronous and precede every mutation.
	if kind == "build":
		if not buildings.has(location):
			buildings[location] = {}
		buildings[location][id] = world.day
	else:
		world.army = _army_after(world,kind,id,quantity)
		if kind == "recruit":
			if not recruited.has(location):
				recruited[location] = {}
			recruited[location][id] = int(recruited[location].get(id,0)) + quantity
	for resource in amounts:
		world.resources[resource] -= amounts[resource]
	var receipt := pending.duplicate(true)
	receipt["confirm"] = message.strip_edges()
	receipts.append(receipt)
	purchase_count += 1
	if receipts.size() > 100:
		receipts.pop_front()
	cancel()
	return {"ok":true,"committed":true,"message":"Operación completada. Coste: " + cost_text(amounts)}

func site(world: RefCounted, id: String) -> Dictionary:
	for entry: Dictionary in world.map_data.get("resource_sites",[]):
		if entry.id == id:
			return entry
	return {}

func claim_model(world: RefCounted, id: String, tier := "") -> String:
	var entry := site(world,id)
	if entry.is_empty():
		return ""
	if tier.is_empty():
		tier = world.trade.tier_for(world)
	var verb: String = {"basic":"Quiero","past":"Decidí","plans":"Voy a","argument":"Querría"}[tier]
	return "%s asegurar la mina de %s." % [verb,catalog.resource_names[entry.resource]]

func claim(world: RefCounted, id: String, message: String) -> bool:
	var entry := site(world,id)
	if entry.is_empty() or mines.has(id) or world.active_battle != null or not pending.is_empty() or not world.trade.pending.is_empty():
		return false
	if world.hero_cell != Vector2i(entry.position[0],entry.position[1]):
		return false
	if entry.guarded and world.encounters.get(id,{}).get("outcome","") != "victory":
		return false
	var tier: String = world.trade.tier_for(world)
	if message.length() > 300 or world.trade.normalize(message) != world.trade.normalize(claim_model(world,id,tier)):
		return false
	mines[id] = {"day":world.day,"hero":world.party.active_id,"message":message.strip_edges(),"tier":tier}
	return true

func advance_day(world: RefCounted) -> Dictionary:
	if world.day <= last_income_day:
		return {}
	var income := {}
	for id in mines:
		var entry := site(world,id)
		income[entry.resource] = int(income.get(entry.resource,0)) + int(entry.daily_income)
	for location in buildings:
		for id in buildings[location]:
			for resource in catalog.buildings[id].income:
				income[resource] = int(income.get(resource,0)) + int(catalog.buildings[id].income[resource])
	for resource in income:
		world.resources[resource] = mini(1000000000,int(world.resources[resource]) + int(income[resource]))
	last_income_day = world.day
	return income

func snapshot() -> Dictionary:
	return {"buildings":buildings.duplicate(true),"recruited":recruited.duplicate(true),
		"mines":mines.duplicate(true),"receipts":receipts.duplicate(true),
		"purchase_count":purchase_count,"last_income_day":last_income_day}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant, world: RefCounted) -> bool:
	if not data is Dictionary or data.size() != 6:
		return false
	if not data.get("buildings") is Dictionary or not data.get("recruited") is Dictionary or not data.get("mines") is Dictionary:
		return false
	if not _integer(data.get("purchase_count"),0,1000000) or not _integer(data.get("last_income_day"),1,world.day):
		return false
	if not data.get("receipts") is Array or data.receipts.size() != mini(100,int(data.purchase_count)):
		return false
	for location in data.buildings:
		if location not in catalog.towns or not data.buildings[location] is Dictionary:
			return false
		var days := {}
		for id in data.buildings[location]:
			var day: Variant = data.buildings[location][id]
			if not catalog.buildings.has(id) or not _integer(day,1,world.day) or days.has(day):
				return false
			days[day] = true
		for id in data.buildings[location]:
			for required in catalog.buildings[id].requires:
				if not data.buildings[location].has(required) or data.buildings[location][required] >= data.buildings[location][id]:
					return false
	for location in data.recruited:
		if location not in catalog.towns or not data.recruited[location] is Dictionary:
			return false
		for id in data.recruited[location]:
			if not catalog.recruits.has(id):
				return false
			var built: int = int(data.buildings.get(location,{}).get(catalog.recruits[id].building,0))
			var capacity := int(catalog.recruits[id].weekly) * (int((world.day-1)/7) - int((built-1)/7) + 1)
			if built < 1 or not _integer(data.recruited[location][id],0,capacity):
				return false
	for id in data.mines:
		var entry := site(world,id)
		var record: Variant = data.mines[id]
		if entry.is_empty() or not record is Dictionary or record.size() != 4:
			return false
		if not _integer(record.get("day"),1,world.day) or not record.get("hero") is String or not world.party.heroes.has(record.hero):
			return false
		if not world.party.heroes[record.hero].unlocked or record.get("tier") not in TIERS or not record.get("message") is String:
			return false
		if world.trade.normalize(record.message) != world.trade.normalize(claim_model(world,id,record.tier)):
			return false
		if entry.guarded and (world.encounters.get(id,{}).get("outcome","") != "victory" or world.encounters[id].day > record.day):
			return false
	var previous := 0
	var recent_recruits := {}
	var construction_receipts := {}
	for receipt in data.receipts:
		if not receipt is Dictionary or receipt.size() != 10 or not receipt.get("kind") is String or not receipt.get("id") is String:
			return false
		var definition := offer(receipt.kind,receipt.id)
		if definition.is_empty() or not _integer(receipt.get("quantity"),1,20) or not _integer(receipt.get("day"),1,world.day):
			return false
		if receipt.day < previous or receipt.get("location") not in catalog.towns or receipt.get("hero") not in world.party.heroes or receipt.get("tier") not in TIERS:
			return false
		previous = int(receipt.day)
		var required: String = receipt.id if receipt.kind == "build" else definition.building
		var built: int = int(data.buildings.get(receipt.location,{}).get(required,0))
		if built < 1 or built > receipt.day or (receipt.kind == "build" and (receipt.quantity != 1 or built != receipt.day)):
			return false
		if receipt.kind == "build":
			var key: String = receipt.location + "/" + receipt.id
			if construction_receipts.has(key):
				return false
			construction_receipts[key] = true
		if receipt.kind == "recruit":
			var key: String = receipt.location + "/" + receipt.id
			recent_recruits[key] = int(recent_recruits.get(key,0)) + int(receipt.quantity)
			if int(data.recruited.get(receipt.location,{}).get(receipt.id,0)) < recent_recruits[key]:
				return false
		var expected := models(receipt.kind,receipt.id,int(receipt.quantity),receipt.tier)
		for stage in ["request","price","confirm"]:
			if not receipt.get(stage) is String or receipt[stage].length() > 300 or world.trade.normalize(receipt[stage]) != world.trade.normalize(expected[stage]):
				return false
	if world.map_id != "province_160x120_v1" and (not data.buildings.is_empty() or not data.recruited.is_empty() or not data.mines.is_empty() or data.purchase_count != 0):
		return false
	buildings = data.buildings.duplicate(true)
	recruited = data.recruited.duplicate(true)
	mines = data.mines.duplicate(true)
	receipts = data.receipts.duplicate(true)
	purchase_count = int(data.purchase_count)
	last_income_day = int(data.last_income_day)
	cancel()
	return true