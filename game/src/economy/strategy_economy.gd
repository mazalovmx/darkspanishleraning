extends RefCounted
## Canonical resource transactions. Quotes never spend; only validated confirmations do.
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/economy/strategy.json"))
var buildings: Dictionary = {}
var recruited: Dictionary = {}
var artifact_sales: Dictionary = {}
var artifact_offers: Dictionary = {}
var mines: Dictionary = {}
var receipts: Array = []
var purchase_count := 0
var last_income_day := 1
var pending: Dictionary = {}
var phase := "request"
## Map treasures: the only source of the 90 optional_treasure items (section 12).
var treasures: Dictionary = {}
const TIERS := ["basic","past","plans","argument"]

func _init() -> void:
	_load_treasures()
	var labels := {"army_attack":"Ataque","army_defense":"Defensa","army_hp_percent":"Salud (%)","army_initiative":"Iniciativa","army_luck":"Suerte","army_morale":"Moral","world_movement":"Movimiento","ranged_damage_percent":"Daño a distancia (%)"}
	var equipment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/equipment.json"))
	for item: Dictionary in equipment.items:
		if item.source.kind == "merchant":
			var details: PackedStringArray = [str(item.lore)]
			for effect: Dictionary in item.effects:
				details.append("%s: +%d" % [labels[effect.effect],effect.amount])
			artifact_offers[item.id] = {"name":item.name,"cost":{"gold":int(item.price_gold)},
				"building":"artifact_market","description":"\n".join(details)}

func _load_treasures() -> void:
	for entry: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://content/world/treasures.json")).treasures:
		treasures[entry.id] = entry

func treasure(world: RefCounted, id: String) -> Dictionary:
	return treasures.get(id, {}) if world.map_id == "province_160x120_v1" else {}

func treasure_at(world: RefCounted, cell: Vector2i) -> Dictionary:
	for id: String in treasures:
		var entry: Dictionary = treasure(world, id)
		if not entry.is_empty() and cell == Vector2i(entry.position[0], entry.position[1]):
			return entry
	return {}

## Claimed when every item of the cache exists; the items have no other source.
func treasure_claimed(world: RefCounted, id: String) -> bool:
	var owned := {}
	for entry: Dictionary in world.equipment.instances.values():
		owned[entry.item] = true
	return treasure(world, id).get("items", []).all(func(item: String) -> bool: return owned.has(item))

const TREASURE_VERBS := ["abrir", "tomar", "recoger", "llevar", "coger", "sacar", "abrimos", "abro", "tomo", "recojo"]
const TREASURE_NOUNS := ["cofre", "arca", "caja", "alijo", "tesoro"]

func treasure_missing(world: RefCounted, id: String, message: String, tier: String) -> Array[String]:
	var result: Array[String] = []
	if message.length() > 300 or treasure(world, id).is_empty():
		result.append("una frase más corta")
		return result
	var text: String = _trade.words(message)
	if not _trade.RULES.request[tier].verbs.any(func(verb: String) -> bool: return text.contains(" %s " % verb)):
		result.append(LABELS.verb)
	if not TREASURE_VERBS.any(func(verb: String) -> bool: return text.contains(" %s " % verb)):
		result.append("qué haces (abrir, tomar, recoger…)")
	if not TREASURE_NOUNS.any(func(noun: String) -> bool: return text.contains(" %s " % noun)):
		result.append("el cofre o el alijo")
	return result

func treasure_cue(world: RefCounted, id: String) -> String:
	var tier: String = world.trade.tier_for(world)
	return "Objetivo: %s\nRecuerda: %s" % [treasure(world, id).name,
		str(_trade.REMINDERS.request[tier]).replace("cantidad + producto", "lo que haces con el cofre")]

func claim_treasure(world: RefCounted, id: String, message: String) -> Dictionary:
	var entry := treasure(world, id)
	if entry.is_empty() or world.planning_active() or world.active_battle != null or not pending.is_empty() or not world.trade.pending.is_empty():
		return {"ok": false, "message": "Termina la acción actual."}
	if world.hero_cell != Vector2i(entry.position[0], entry.position[1]):
		return {"ok": false, "message": "El héroe debe estar junto al tesoro."}
	if treasure_claimed(world, id):
		return {"ok": false, "message": "Ya has recogido este tesoro."}
	if entry.guarded and world.encounters.get(id, {}).get("outcome", "") != "victory":
		return {"ok": false, "message": "Los guardianes controlan el tesoro."}
	var tier: String = world.trade.tier_for(world)
	var gaps := treasure_missing(world, id, message, tier)
	if not gaps.is_empty():
		return {"ok": false, "message": _gaps_text(gaps)}
	var spelling: String = _trade.spelling(message, "", "request", tier)
	if not spelling.is_empty():
		return {"ok": false, "message": spelling}
	var owner: String = world.party.active_id
	var room: int = 2048 - world.equipment.instances.size()
	if room < entry.items.size() or not entry.items.all(func(item: String) -> bool: return world.equipment.can_grant(item, owner)):
		return {"ok": false, "message": "No queda espacio en la mochila. El tesoro sigue aquí."}
	var names: PackedStringArray = []
	for item: String in entry.items:
		world.equipment.grant(item, owner)
		names.append(str(world.equipment.items[item].name))
	return {"ok": true, "message": "Guardas en la mochila: " + ", ".join(names) + "."}

func offer(kind: String, id: String) -> Dictionary:
	var collection: Dictionary = catalog.buildings if kind == "build" else catalog.recruits if kind == "recruit" else catalog.upgrades if kind == "upgrade" else artifact_offers if kind == "artifact" else {}
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

func cost_text(amounts: Dictionary, legacy := false) -> String:
	var parts: PackedStringArray = []
	for resource in catalog.resource_names:
		if amounts.has(resource):
			var amount: int = int(amounts[resource])
			if legacy:
				parts.append("%d de %s" % [amount,catalog.resource_names[resource]])
			elif resource == "gold":
				parts.append("%d %s de oro" % [amount,"moneda" if amount == 1 else "monedas"])
			elif resource == "gems":
				parts.append("%d %s" % [amount,"gema" if amount == 1 else "gemas"])
			else:
				parts.append("%d %s de %s" % [amount,"unidad" if amount == 1 else "unidades",catalog.resource_names[resource]])
	return " y ".join(parts)

func models(kind: String, id: String, quantity: int, tier := "basic", legacy := false) -> Dictionary:
	var definition := offer(kind,id)
	if definition.is_empty():
		return {}
	var target: String = definition.name if kind == "build" else "%d %s" % [quantity,definition.name]
	var verb := "construir" if kind == "build" else "contratar" if kind == "recruit" else "mejorar a"
	if not legacy:
		if kind == "build":
			target = ("una " if id in ["council_hall","forge","treasury","artifact_market"] else "un ") + str(definition.name)
		elif kind == "upgrade":
			verb = "convertir"
			target = "%d %s en %s" % [quantity,"miliciano" if quantity == 1 else "milicianos",definition.singular if quantity == 1 else definition.name]
		elif kind == "recruit" and quantity == 1:
			target = "1 " + str(definition.singular)
	if kind == "artifact":
		verb = "comprar"
		target = "el artículo «%s»" % definition.name
	var total := cost_text(cost(kind,id,quantity),legacy)
	var confirmation_target := target
	if not legacy and kind == "build":
		confirmation_target = "la construcción de " + target
	elif not legacy and kind == "upgrade":
		confirmation_target = "la mejora de %d %s a %s" % [quantity,"miliciano" if quantity == 1 else "milicianos",definition.singular if quantity == 1 else definition.name]
	var request := "Quiero"
	if tier == "past":
		request = "Decidí"
	elif tier == "plans":
		request = "Voy a"
	elif tier == "argument":
		request = "Querría"
	return {"request":"%s %s %s." % [request,verb,target],
		"price":("Si pido %s, el coste total es %s." % [confirmation_target,total]) if tier == "argument" else "El coste total es %s." % total,
		"confirm":("Acepto pagar %s porque necesito %s." % [total,confirmation_target]) if tier == "argument" else ("Voy a pagar %s por %s." % [total,confirmation_target]) if tier == "plans" else "Confirmo %s por %s." % [confirmation_target,total]}

const UNIT_WORDS := {"gold": ["moneda", "monedas", "oro"], "gems": ["gema", "gemas"]}
const LABELS := {"verb": "la forma verbal", "target": "lo que pides", "cost": "el coste completo"}

## Quantity and noun that a request, an argued price and a confirmation must name.
func _has_target(text: String, kind: String, id: String, quantity: int) -> bool:
	var definition := offer(kind,id)
	if kind in ["build","artifact"]:
		return text.contains(world_words(str(definition.name)))
	var noun: String = definition.singular if quantity == 1 else definition.name
	for number in _trade.call("_numbers", quantity, false):
		if text.contains(" %s%s" % [number, world_words(noun)]):
			return true
	return false

## Every resource of the cost: its amount followed, within two words, by its unit.
func _has_cost(text: String, amounts: Dictionary) -> bool:
	for resource in amounts:
		var units: Array = UNIT_WORDS.get(resource, [catalog.resource_names[resource]])
		var found := false
		for number in _trade.call("_numbers", int(amounts[resource]), true):
			var pattern := RegEx.create_from_string(" %s (?:\\S+ ){0,2}(?:%s) " % [number, "|".join(units)])
			found = found or pattern.search(text) != null
		if not found:
			return false
	return true

var _trade: RefCounted = preload("res://src/economy/trade_state.gd").new()

func world_words(phrase: String) -> String:
	return _trade.words(phrase).substr(1)

## Names what an order sentence still lacks; the model itself always passes.
func missing(kind: String, id: String, quantity: int, message: String, stage: String, tier: String) -> Array[String]:
	var result: Array[String] = []
	if message.length() > 300:
		result.append("una frase más corta")
		return result
	for legacy in [false,true]:
		if _trade.normalize(message) == _trade.normalize(str(models(kind,id,quantity,tier,legacy).get(stage,""))):
			return result
	var text: String = _trade.words(message)
	var rule: Dictionary = _trade.RULES[stage][tier]
	if not rule.verbs.any(func(verb: String) -> bool: return text.contains(" %s " % verb)):
		result.append(LABELS.verb)
	for word in rule.get("words", []):
		if not text.contains(" %s " % word):
			result.append("«%s»" % word)
	if (stage != "price" or tier in ["past","argument"]) and not _has_target(text,kind,id,quantity):
		result.append(LABELS.target)
	if stage != "request" and not _has_cost(text,cost(kind,id,quantity)):
		result.append(LABELS.cost)
	return result

## Facts to express and a rule reminder, shown instead of a model sentence.
func cue(world: RefCounted, kind: String, id: String, quantity: int) -> String:
	var tier := str(pending.get("tier",world.trade.tier_for(world)))
	var definition := offer(kind,id)
	var target: String = definition.name if kind in ["build","artifact"] else "%d %s" % [quantity,definition.singular if quantity == 1 else definition.name]
	return "Pedido: %s · Coste: %s\nRecuerda: %s" % [target,cost_text(cost(kind,id,quantity)),_trade.REMINDERS[phase][tier]]

func _gaps_text(gaps: Array[String]) -> String:
	return "Falta " + (", ".join(gaps.slice(0, gaps.size() - 1)) + " y " + gaps[-1] if gaps.size() > 1 else gaps[0]) + "."

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
	if world.planning_active():
		return "Resuelve primero las órdenes preparadas."
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
		# Hero-specific archetypes (master spec 9): only their hero can hire them.
		if kind == "recruit" and definition.has("hero") and definition.hero != world.party.active_id:
			return "Estas tropas solo sirven a " + str(world.party.heroes[definition.hero].definition.name) + "."
		if kind == "recruit" and stock(location,id,world.day) < quantity:
			return "No quedan suficientes tropas esta semana."
		if kind == "artifact":
			if quantity != 1 or artifact_sales.get(location,{}).has(id):
				return "Solo hay una pieza de este artículo por mercado."
			if not world.equipment.can_grant(id,world.party.active_id):
				return "No queda espacio para otra pieza."
		elif _army_after(world,kind,id,quantity).is_empty():
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
	var gaps := missing(kind,id,quantity,message,phase,tier)
	if not gaps.is_empty():
		return {"ok":false,"message":_gaps_text(gaps) + "\nRecuerda: " + str(_trade.REMINDERS[phase][tier])}
	var spelling: String = _trade.spelling(message,str(models(kind,id,quantity,tier)[phase]),phase,tier)
	if not spelling.is_empty():
		return {"ok":false,"message":spelling}
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
	elif kind == "artifact":
		var instance: String = world.equipment.grant(id,world.party.active_id)
		if not artifact_sales.has(location):
			artifact_sales[location] = {}
		artifact_sales[location][id] = {"instance":instance,"day":world.day,"hero":world.party.active_id}
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

## What a claim order lacks: a verb form of the tier, the mine and its resource.
func claim_missing(world: RefCounted, id: String, message: String, tier: String) -> Array[String]:
	var result: Array[String] = []
	var entry := site(world,id)
	if message.length() > 300 or entry.is_empty():
		result.append("una frase más corta")
		return result
	if _trade.normalize(message) == _trade.normalize(claim_model(world,id,tier)):
		return result
	var text: String = _trade.words(message)
	if not _trade.RULES.request[tier].verbs.any(func(verb: String) -> bool: return text.contains(" %s " % verb)):
		result.append(LABELS.verb)
	if not text.contains(" mina ") or not text.contains(" %s " % world_words(catalog.resource_names[entry.resource]).strip_edges()):
		result.append("la mina y su recurso")
	return result

func claim_cue(world: RefCounted, id: String) -> String:
	var tier: String = world.trade.tier_for(world)
	return "Objetivo: la mina de %s\nRecuerda: %s" % [catalog.resource_names[site(world,id).resource],
		str(_trade.REMINDERS.request[tier]).replace("cantidad + producto","lo que quieres asegurar")]

func claim_feedback(world: RefCounted, id: String, message: String) -> String:
	var tier: String = world.trade.tier_for(world)
	var gaps := claim_missing(world,id,message,tier)
	var spelling: String = _trade.spelling(message,claim_model(world,id,tier),"request",tier)
	return _gaps_text(gaps) if not gaps.is_empty() else spelling if not spelling.is_empty() else "Revisa el acceso."

## Owned mines are contested (master spec 12): raiders arrive every seventh day after
## the claim; the mine yields nothing until a victory over them that is not older than
## the latest raid. Derived from the claim day and encounters, so it adds no save field.
const RAID_PREFIX := "raid_"

func raid_id(id: String) -> String:
	return RAID_PREFIX + id

func raid_day(world: RefCounted, id: String) -> int:
	if not mines.has(id):
		return 0
	var since: int = world.day - int(mines[id].day)
	return 0 if since < 7 else int(mines[id].day) + 7 * int(since / 7)

func contested(world: RefCounted, id: String) -> bool:
	var raided := raid_day(world, id)
	var won: Dictionary = world.encounters.get(raid_id(id), {})
	return raided > 0 and not (won.get("outcome", "") == "victory" and int(won.get("day", 0)) >= raided)

func raid_definition(world: RefCounted, encounter_id: String) -> Dictionary:
	var id := encounter_id.trim_prefix(RAID_PREFIX)
	var entry := site(world, id) if encounter_id.begins_with(RAID_PREFIX) else {}
	if entry.is_empty():
		return {}
	var raiders: Array = catalog.mine_guards.get(entry.resource, [{"type": "bandits", "count": 5}]).duplicate(true)
	return {"id": encounter_id, "name": "Salteadores en la mina de " + str(catalog.resource_names[entry.resource]),
		"position": entry.position.duplicate(), "enemies": raiders, "requires": "", "reward": {}}

func claim(world: RefCounted, id: String, message: String) -> bool:
	var entry := site(world,id)
	if world.planning_active() or entry.is_empty() or mines.has(id) or world.active_battle != null or not pending.is_empty() or not world.trade.pending.is_empty():
		return false
	if world.hero_cell != Vector2i(entry.position[0],entry.position[1]):
		return false
	if entry.guarded and world.encounters.get(id,{}).get("outcome","") != "victory":
		return false
	var tier: String = world.trade.tier_for(world)
	if not claim_missing(world,id,message,tier).is_empty() or not _trade.spelling(message,claim_model(world,id,tier),"request",tier).is_empty():
		return false
	mines[id] = {"day":world.day,"hero":world.party.active_id,"message":message.strip_edges(),"tier":tier}
	return true

func advance_day(world: RefCounted) -> Dictionary:
	if world.day <= last_income_day:
		return {}
	var income := {}
	for id in mines:
		if contested(world,id):
			continue
		var entry := site(world,id)
		income[entry.resource] = int(income.get(entry.resource,0)) + int(entry.daily_income)
	for location in buildings:
		for id in buildings[location]:
			for resource in catalog.buildings[id].income:
				income[resource] = int(income.get(resource,0)) + int(catalog.buildings[id].income[resource])
	# Decisions with lasting output (campaign outcomes with "income").
	var decided: Dictionary = world.campaign.income(world)
	for resource in decided:
		income[resource] = int(income.get(resource,0)) + int(decided[resource])
	for resource in income:
		world.resources[resource] = mini(1000000000,int(world.resources[resource]) + int(income[resource]))
	last_income_day = world.day
	return income

func snapshot() -> Dictionary:
	return {"artifact_sales":artifact_sales.duplicate(true),"buildings":buildings.duplicate(true),"recruited":recruited.duplicate(true),
		"mines":mines.duplicate(true),"receipts":receipts.duplicate(true),
		"purchase_count":purchase_count,"last_income_day":last_income_day}

func _integer(value: Variant, low: int, high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant, world: RefCounted) -> bool:
	if not data is Dictionary or data.size() != 7 or not data.get("artifact_sales") is Dictionary:
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
		if not claim_missing(world,id,record.message,record.tier).is_empty():
			return false
		if entry.guarded and (world.encounters.get(id,{}).get("outcome","") != "victory" or world.encounters[id].day > record.day):
			return false
	var sold_instances := {}
	for location in data.artifact_sales:
		if location not in catalog.towns or not data.artifact_sales[location] is Dictionary:
			return false
		var built: int = int(data.buildings.get(location,{}).get("artifact_market",0))
		for id in data.artifact_sales[location]:
			var sale: Variant = data.artifact_sales[location][id]
			if not artifact_offers.has(id) or not sale is Dictionary or sale.size() != 3 or built < 1:
				return false
			if not _integer(sale.get("day"),built,world.day) or sale.get("hero") not in world.party.heroes:
				return false
			if not world.party.heroes[sale.hero].unlocked or not sale.get("instance") is String:
				return false
			if sold_instances.has(sale.instance) or not world.equipment.instances.has(sale.instance):
				return false
			if world.equipment.instances[sale.instance].item != id:
				return false
			sold_instances[sale.instance] = true
	if sold_instances.size() > data.purchase_count:
		return false
	var previous := 0
	var recent_recruits := {}
	var construction_receipts := {}
	var sale_receipts := {}
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
			if catalog.recruits[receipt.id].get("hero", receipt.hero) != receipt.hero:
				return false
			var key: String = receipt.location + "/" + receipt.id
			recent_recruits[key] = int(recent_recruits.get(key,0)) + int(receipt.quantity)
			if int(data.recruited.get(receipt.location,{}).get(receipt.id,0)) < recent_recruits[key]:
				return false
		if receipt.kind == "artifact":
			var key: String = receipt.location + "/" + receipt.id
			var sale: Dictionary = data.artifact_sales.get(receipt.location,{}).get(receipt.id,{})
			if receipt.quantity != 1 or sale.is_empty() or sale_receipts.has(key):
				return false
			if sale.day != receipt.day or sale.hero != receipt.hero:
				return false
			sale_receipts[key] = true
		for stage in ["request","price","confirm"]:
			if not receipt.get(stage) is String or not missing(receipt.kind,receipt.id,int(receipt.quantity),receipt[stage],stage,receipt.tier).is_empty():
				return false
	if data.purchase_count <= 100 and sale_receipts.size() != sold_instances.size():
		return false
	if world.map_id != "province_160x120_v1" and (not data.buildings.is_empty() or not data.recruited.is_empty() or not data.mines.is_empty() or not data.artifact_sales.is_empty() or data.purchase_count != 0):
		return false
	# A treasure item comes only from its cache: a guarded cache needs its victory.
	for entry: Dictionary in world.equipment.instances.values():
		for id: String in treasures:
			if entry.item in treasures[id].items and world.map_id == "province_160x120_v1" and treasures[id].guarded and world.encounters.get(id, {}).get("outcome", "") != "victory":
				return false
	artifact_sales = data.artifact_sales.duplicate(true)
	buildings = data.buildings.duplicate(true)
	recruited = data.recruited.duplicate(true)
	mines = data.mines.duplicate(true)
	receipts = data.receipts.duplicate(true)
	purchase_count = int(data.purchase_count)
	last_income_day = int(data.last_income_day)
	cancel()
	return true