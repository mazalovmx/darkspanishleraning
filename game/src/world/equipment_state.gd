extends RefCounted
## Instance ownership and soul consent; acquisition callers must verify purchases/rewards.
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/equipment.json"))
var language: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/soul_rituals.json"))
var items: Dictionary = {}
var sets: Dictionary = {}
var types: Dictionary = {}
var instances: Dictionary = {}
var assemblies: Dictionary = {}
var rituals: Dictionary = {}
var special_used: Dictionary = {}
var next_instance := 1
const HEROES := ["inquisitor","smuggler","survivor"]
const STAGES := ["listen","compare_memories","supported_production","independent_argument","answer_objection","delayed_recall","consent"]

func _init() -> void:
	for item: Dictionary in catalog.items:
		items[item.id] = item
	for entry: Dictionary in catalog.sets:
		sets[entry.id] = entry
	for type: Dictionary in catalog.types:
		types[type.id] = type

func can_grant(item_id: String, owner: String) -> bool:
	if owner not in HEROES or not items.has(item_id) or items[item_id].rarity == "soul" or instances.size() >= 2048 or next_instance >= 1000000000:
		return false
	if items[item_id].unique:
		for entry in instances.values():
			if entry.item == item_id:
				return false
	return true

func grant(item_id: String, owner: String) -> String:
	if not can_grant(item_id,owner):
		return ""
	var id := "I%06d" % next_instance
	next_instance += 1
	instances[id] = {"item":item_id,"owner":owner,"slot":""}
	return id

func _slot_allowed(item_id: String, slot: String) -> bool:
	if slot not in catalog.slots:
		return false
	var group: String = types[items[item_id].type].slot_group
	return slot in catalog.rules.slot_groups[group] if catalog.rules.slot_groups.has(group) else slot == group

func at_slot(owner: String, slot: String) -> String:
	for id in instances:
		if instances[id].owner == owner and instances[id].slot == slot:
			return id
	return ""

func _assembled(instance_id: String) -> bool:
	for entry in assemblies.values():
		if instance_id in entry.parts:
			return true
	return false

func _allowed(world: RefCounted, counter := false) -> bool:
	return (counter or not world.planning_active()) and world.ghosts.pending_encounter.is_empty() and world.active_battle == null and world.trade.pending.is_empty() and world.economy.pending.is_empty()

func equip(world: RefCounted, instance_id: String, slot: String) -> bool:
	if not _allowed(world) or not instances.has(instance_id) or _assembled(instance_id):
		return false
	var entry: Dictionary = instances[instance_id]
	if entry.owner != world.party.active_id or not _slot_allowed(entry.item,slot):
		return false
	var occupied := at_slot(entry.owner,slot)
	if not occupied.is_empty() and occupied != instance_id:
		return false
	entry.slot = slot
	return true

func unequip(world: RefCounted, instance_id: String) -> bool:
	if not _allowed(world) or not instances.has(instance_id) or _assembled(instance_id) or instances[instance_id].owner != world.party.active_id:
		return false
	instances[instance_id].slot = ""
	_clamp_movement(world,world.party.active_id)
	return true

func components(owner: String, set_id: String) -> Array:
	if not sets.has(set_id):
		return []
	var result := []
	for part: Dictionary in sets[set_id].components:
		var id := at_slot(owner,part.slot)
		if id.is_empty() or instances[id].item != part.item_id:
			return []
		result.append(id)
	return result

func consent(owner: String, set_id: String) -> bool:
	return rituals.get(owner,{}).get(set_id,{}).size() == STAGES.size()

func bonuses(owner: String) -> Dictionary:
	var result := {}
	for effect in catalog.effects:
		result[effect] = 0
	for entry in instances.values():
		if entry.owner != owner or str(entry.slot).is_empty():
			continue
		for effect: Dictionary in items[entry.item].effects:
			result[effect.effect] += int(effect.amount)
	for id in assemblies:
		if assemblies[id].owner == owner and consent(owner,id):
			var bonus: Dictionary = sets[id].bonus
			result[bonus.effect] += int(bonus.amount)
	for effect in result:
		result[effect] = mini(int(catalog.effects[effect].cap),int(result[effect]))
	return result

func _clamp_movement(world: RefCounted, owner: String) -> void:
	var member = world.party.heroes[owner]
	member.movement_remaining = mini(member.movement_remaining,int(member.definition.movement_max) + int(bonuses(owner).world_movement))

func _language_ready(world: RefCounted, set_id: String, day: int) -> bool:
	var node := {"min_block":int(sets[set_id].ritual.required_block)-1,"grammar":language[set_id].grammar}
	return world.campaign.language_ready(world,node,day)

func ritual_stage(owner: String,set_id: String) -> String:
	var count: int = rituals.get(owner,{}).get(set_id,{}).size()
	return "complete" if count >= STAGES.size() else str(STAGES[count])

func expected(set_id: String, stage: String) -> String:
	match stage:
		"listen": return "Quiero escuchar tus recuerdos."
		"compare_memories": return language[set_id].comparison
		"supported_production": return sets[set_id].ritual.supported_frame
		"independent_argument": return language[set_id].independent
		"answer_objection": return language[set_id].objection
		"delayed_recall": return language[set_id].recall
		"consent": return "Acepto este pacto."
	return ""

const LISTEN_KEYS := [{"need":"pedir en presente (quiero, necesito…)","any":["quiero","necesito","deseo","pido","puedo"]},
	{"need":"escuchar","any":["escuchar","oir","conocer"]},{"need":"los recuerdos","any":["recuerdos","memorias"]}]

var _separators := RegEx.create_from_string("[^\\p{L}\\p{N}]+")

func _words(answer: String) -> String:
	var text: String = _separators.sub(answer.to_lower(), " ", true)
	for pair in [["á","a"],["é","e"],["í","i"],["ó","o"],["ú","u"]]:
		text = text.replace(pair[0], pair[1])
	return " " + " ".join(text.split(" ", false)) + " "

## Authored needs a free answer still lacks; consent has no keys and stays exact.
func missing(set_id: String, stage: String, answer: String) -> Array[String]:
	var keys: Array = LISTEN_KEYS if stage == "listen" else language[set_id].get("keys",{}).get(stage,[])
	var result: Array[String] = []
	if keys.is_empty():
		result.append("la frase completa")
		return result
	var text := _words(answer)
	for group: Dictionary in keys:
		if not group.any.any(func(form: String) -> bool: return text.contains(" %s " % form)):
			result.append(str(group.need))
	return result

func _near_miss(world: RefCounted,set_id: String,stage: String,answer: String) -> bool:
	for phrase: String in language[set_id].get("alternatives",{}).get(stage,[]):
		if world.learner.curriculum.normalized(answer) == world.learner.curriculum.normalized(phrase):
			return true
	return false

func _valid_response(world: RefCounted,set_id: String,stage: String,answer: String,memories: Array) -> bool:
	if answer.length() > 300:
		return false
	var exact: bool = world.learner.curriculum.normalized(answer) == world.learner.curriculum.normalized(expected(set_id,stage))
	if not exact and not _near_miss(world,set_id,stage,answer) and not missing(set_id,stage,answer).is_empty():
		return false
	if stage != "compare_memories":
		return memories.is_empty()
	var required: Array = sets[set_id].ritual.required_memories
	return memories.size() == 2 and memories[0] != memories[1] and memories[0] in required and memories[1] in required

func persuade(world: RefCounted,set_id: String,answer: String,memories: Array = []) -> Dictionary:
	var owner: String = world.party.active_id
	if not sets.has(set_id) or not _allowed(world) or components(owner,set_id).is_empty():
		return {"ok":false,"message":"Reúne y equipa las cuatro partes del mismo conjunto."}
	if not _language_ready(world,set_id,world.day):
		return {"ok":false,"message":"Consolida los bloques anteriores y practica las formas de esta conversación."}
	var stage := ritual_stage(owner,set_id)
	if stage == "complete":
		return {"ok":false,"message":"Esta alma ya acepta tu pacto."}
	var progress: Dictionary = rituals.get(owner,{}).get(set_id,{})
	if stage == "delayed_recall" and world.day <= progress.answer_objection.day:
		return {"ok":false,"message":"Vuelve en un día posterior para recordar sin el modelo."}
	if not _valid_response(world,set_id,stage,answer,memories):
		var hint := "Elige dos recuerdos distintos que el alma reconozca."
		var gaps := missing(set_id,stage,answer)
		if answer.length() > 300:
			hint = "Usa una frase más corta."
		elif stage == "consent":
			hint = "Confirma con la frase del pacto."
		elif not gaps.is_empty() and not _near_miss(world,set_id,stage,answer) and world.learner.curriculum.normalized(answer) != world.learner.curriculum.normalized(expected(set_id,stage)):
			hint = "Tu frase necesita: " + "; ".join(gaps) + "."
		return {"ok":false,"message":str(sets[set_id].ritual.retry_response) + "\n" + hint}
	if not rituals.has(owner):
		rituals[owner] = {}
	if not rituals[owner].has(set_id):
		rituals[owner][set_id] = {}
	rituals[owner][set_id][stage] = {"day":world.day,"answer":answer.strip_edges(),"memories":memories.duplicate()}
	if _near_miss(world,set_id,stage,answer):
		return {"ok":true,"message":"Se entiende. Forma sugerida: " + expected(set_id,stage)}
	return {"ok":true,"message":"El alma reconoce tu argumento." if stage == "consent" else "La conversación continúa."}

func assemble(world: RefCounted,set_id: String) -> bool:
	var owner: String = world.party.active_id
	if not _allowed(world) or not sets.has(set_id) or assemblies.has(set_id) or not consent(owner,set_id):
		return false
	var parts := components(owner,set_id)
	if parts.is_empty():
		return false
	assemblies[set_id] = {"owner":owner,"creator":owner,"parts":parts,"day":world.day}
	return true

func disassemble(world: RefCounted,set_id: String) -> bool:
	if not _allowed(world) or not assemblies.has(set_id) or assemblies[set_id].owner != world.party.active_id:
		return false
	assemblies.erase(set_id)
	_clamp_movement(world,world.party.active_id)
	return true

func _can_transfer(world: RefCounted,source: String,target: String) -> bool:
	if not _allowed(world) or source != world.party.active_id or target not in HEROES or source == target:
		return false
	return world.party.heroes[target].unlocked and world.party.heroes[source].cell == world.party.heroes[target].cell

func transfer(world: RefCounted,instance_id: String,target: String) -> bool:
	if not instances.has(instance_id) or _assembled(instance_id):
		return false
	var entry: Dictionary = instances[instance_id]
	var source: String = entry.owner
	if not _can_transfer(world,source,target):
		return false
	entry.owner = target
	entry.slot = ""
	_clamp_movement(world,source)
	return true

func transfer_set(world: RefCounted,set_id: String,target: String) -> bool:
	if not assemblies.has(set_id):
		return false
	var entry: Dictionary = assemblies[set_id]
	var source: String = entry.owner
	if not _can_transfer(world,source,target):
		return false
	for slot: String in sets[set_id].reserved_slots:
		if not at_slot(target,slot).is_empty():
			return false
	for id: String in entry.parts:
		instances[id].owner = target
	entry.owner = target
	_clamp_movement(world,source)
	return true

func consume_special(world: RefCounted,set_id: String) -> Dictionary:
	if not _allowed(world,true) or not assemblies.has(set_id) or assemblies[set_id].owner != world.party.active_id or not consent(world.party.active_id,set_id) or int(special_used.get(set_id,0)) >= world.day:
		return {}
	special_used[set_id] = world.day
	return sets[set_id].special.duplicate(true)

func snapshot() -> Dictionary:
	return {"next_instance":next_instance,"instances":instances.duplicate(true),"assemblies":assemblies.duplicate(true),
		"rituals":rituals.duplicate(true),"special_used":special_used.duplicate()}

func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant,world: RefCounted) -> bool:
	if not data is Dictionary or data.size() != 5 or not _integer(data.get("next_instance"),1,1000000000):
		return false
	for field in ["instances","assemblies","rituals","special_used"]:
		if not data.get(field) is Dictionary:
			return false
	if data.instances.size() > 2048 or data.assemblies.size() > sets.size() or data.rituals.size() > HEROES.size() or data.special_used.size() > sets.size():
		return false
	var occupied := {}
	var unique_items := {}
	for id in data.instances:
		var entry: Variant = data.instances[id]
		if not id is String or not id.begins_with("I") or not id.trim_prefix("I").is_valid_int():
			return false
		var number := int(id.trim_prefix("I"))
		if number < 1 or number >= data.next_instance or id != "I%06d" % number:
			return false
		if not entry is Dictionary or entry.size() != 3 or not entry.get("item") is String or not items.has(entry.item):
			return false
		if entry.get("owner") not in HEROES or not entry.get("slot") is String or items[entry.item].rarity == "soul":
			return false
		if items[entry.item].unique:
			if unique_items.has(entry.item):
				return false
			unique_items[entry.item] = true
		if not entry.slot.is_empty():
			var key: String = entry.owner + "/" + entry.slot
			if not _slot_allowed(entry.item,entry.slot) or occupied.has(key):
				return false
			occupied[key] = id
	for owner in data.rituals:
		if owner not in HEROES or not data.rituals[owner] is Dictionary or data.rituals[owner].size() > sets.size():
			return false
		for set_id in data.rituals[owner]:
			var progress: Variant = data.rituals[owner][set_id]
			if not sets.has(set_id) or not progress is Dictionary or progress.is_empty() or progress.size() > STAGES.size():
				return false
			var previous := 0
			for i in progress.size():
				var stage: String = STAGES[i]
				var entry: Variant = progress.get(stage)
				if not entry is Dictionary or entry.size() != 3 or not _integer(entry.get("day"),1,world.day):
					return false
				if entry.day < previous or (stage == "delayed_recall" and entry.day <= previous):
					return false
				if not entry.get("answer") is String or not entry.get("memories") is Array or not _valid_response(world,set_id,stage,entry.answer,entry.memories):
					return false
				if not _language_ready(world,set_id,int(entry.day)):
					return false
				previous = int(entry.day)
	for set_id in data.assemblies:
		var entry: Variant = data.assemblies[set_id]
		if not sets.has(set_id) or not entry is Dictionary or entry.size() != 4 or entry.get("owner") not in HEROES or entry.get("creator") not in HEROES:
			return false
		if not _integer(entry.get("day"),1,world.day) or not entry.get("parts") is Array or entry.parts.size() != sets[set_id].components.size():
			return false
		var progress: Dictionary = data.rituals.get(entry.creator,{}).get(set_id,{})
		if progress.size() != STAGES.size() or int(progress.consent.day) > entry.day:
			return false
		for i in entry.parts.size():
			var part: Dictionary = sets[set_id].components[i]
			var id: Variant = entry.parts[i]
			if not id is String or not data.instances.has(id):
				return false
			var instance: Dictionary = data.instances[id]
			if instance.item != part.item_id or instance.owner != entry.owner or instance.slot != part.slot:
				return false
	for set_id in data.special_used:
		if not sets.has(set_id) or not _integer(data.special_used[set_id],1,world.day):
			return false
		var accepted := false
		for owner in data.rituals:
			var progress: Dictionary = data.rituals[owner].get(set_id,{})
			if progress.size() == STAGES.size() and progress.consent.day <= data.special_used[set_id]:
				accepted = true
		if not accepted:
			return false
	next_instance = int(data.next_instance)
	instances = data.instances.duplicate(true)
	assemblies = data.assemblies.duplicate(true)
	rituals = data.rituals.duplicate(true)
	special_used = data.special_used.duplicate()
	return true