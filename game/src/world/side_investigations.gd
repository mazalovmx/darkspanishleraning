extends RefCounted
## Bounded authored practice; no free-language grading or truth from a battle.
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/side_investigations.json"))
static var practice: Array = JSON.parse_string(FileAccess.get_file_as_string("res://content/spanish/side_practice.json"))
var quests: Dictionary = {}
var battles: Dictionary = {}
var artifacts: Dictionary = {}
var branches: Dictionary = {}
var records: Dictionary = {}
const STAGES := ["access","inspect","puzzle","supported","independent","recall"]

func _init() -> void:
	for entry: Dictionary in catalog.quests:
		quests[entry.id] = entry
	for entry: Dictionary in catalog.battles:
		battles[entry.id] = entry
	for entry: Dictionary in catalog.artifacts:
		artifacts[entry.id] = entry
	for entry: Dictionary in catalog.branches:
		branches[entry.id] = entry

func stages(id: String) -> Array:
	return STAGES + (["choice"] if not quests[id].final_choice.is_empty() else [])

func complete(id: String, ledger: Dictionary) -> bool:
	return quests.has(id) and ledger.has(id) and ledger[id].progress.size() == stages(id).size()

func stage(id: String) -> String:
	var count: int = records.get(id,{}).get("progress",{}).size()
	return "complete" if count >= stages(id).size() else str(stages(id)[count])

func completed_day(id: String, ledger: Dictionary) -> int:
	return int(ledger[id].progress[stages(id).back()].day) if complete(id,ledger) else 0

func language_ready(world: RefCounted,id: String,day: int) -> bool:
	var node: Dictionary = quests[id]
	var grammar: Array = [node.language.new_target]
	if int(node.language.block) == 6:
		grammar.append("ir_a_future")
	return world.campaign.language_ready(world,{"min_block":int(node.language.block)-1,"grammar":grammar},day)

func prerequisites(id: String,ledger: Dictionary,day: int) -> bool:
	for required: String in quests[id].requires:
		var completed := completed_day(required,ledger)
		if completed < 1 or completed > day:
			return false
	return true

func reason(world: RefCounted,id: String) -> String:
	if not quests.has(id) or world.map_id != "province_160x120_v1":
		return "Este expediente pertenece a la provincia."
	if world.active_battle != null or not world.trade.pending.is_empty() or not world.economy.pending.is_empty():
		return "Termina la acción actual."
	if world.location_at(world.hero_cell).get("id","") != quests[id].location_id:
		return "Visita el lugar de la investigación."
	if not prerequisites(id,records,world.day):
		return "Resuelve primero los expedientes que aportan las pruebas necesarias."
	if not language_ready(world,id,world.day):
		return "Consolida los bloques anteriores y practica las formas de este expediente."
	if stage(id) == "complete":
		return "El expediente ya está resuelto."
	return ""

func available(world: RefCounted) -> Array:
	var result := []
	for id: String in quests:
		if prerequisites(id,records,world.day):
			result.append(id)
	return result

func models(id: String) -> Dictionary:
	var index: int = (int(id.trim_prefix("SX"))-1) % 9
	var name: String = artifacts[quests[id].artifact_id].name
	var card: Dictionary = practice[index]
	return {"access":"Quiero examinar la pieza «%s» con un testigo, por favor." % name,
		"supported":card.supported % name,"independent":card.independent[0] % name,
		"alternative":card.independent[1] % name,"recall":card.recall % name}

func choice_model(choice: String) -> String:
	return "Propondría publicar el expediente." if choice.ends_with("_public") else "Propondría proteger los datos personales."

func reward_item(world: RefCounted,id: String) -> String:
	for binding: Dictionary in world.equipment.catalog.reward_bindings:
		if binding.quest_id == id:
			return binding.item_id
	return ""

func encounter_definition(id: String) -> Dictionary:
	if not battles.has(id):
		return {}
	var definition: Dictionary = battles[id]
	var enemies: Array = []
	for stack: Dictionary in definition.enemy_stacks:
		enemies.append({"type":str(stack.unit),"count":int(stack.count)})
	return {"id":id,"name":definition.title,"location_id":definition.location_id,
		"requires":"","enemies":enemies,"reward":{}}

func can_battle(world: RefCounted,id: String) -> bool:
	return battles.has(id) and reason(world,battles[id].quest_id).is_empty() and stage(battles[id].quest_id) == "access" and world.encounters.get(id,{}).get("outcome","") != "victory"

func _same(world: RefCounted,a: String,b: String) -> bool:
	return world.learner.curriculum.normalized(a) == world.learner.curriculum.normalized(b)

func _valid(world: RefCounted,id: String,step: String,payload: Dictionary,ledger: Dictionary) -> bool:
	var node: Dictionary = quests[id]
	var day: int = int(payload.day)
	var proof: Dictionary = ledger.get(id,{}).get("progress",{})
	if step != "access" and (not payload.route.is_empty() or not payload.cipher.is_empty()):
		return false
	if step not in ["puzzle","choice"] and (not payload.choice.is_empty() or not payload.rejected.is_empty()):
		return false
	var phrases := models(id)
	match step:
		"access":
			if payload.route not in ["peaceful","battle"] or not _same(world,payload.answer,phrases.access):
				return false
			if node.has("access_puzzle"):
				if not _same(world,payload.cipher,node.access_puzzle.answer):
					return false
			elif not payload.cipher.is_empty():
				return false
			var encounter: Dictionary = battles[node.encounter_id]
			if payload.route == "battle":
				var victory: Dictionary = world.encounters.get(node.encounter_id,{})
				if victory.get("outcome","") != "victory" or int(victory.get("day",0)) > day:
					return false
			else:
				for artifact_id: String in encounter.peaceful_route.required_artifacts:
					var source: String = artifacts[artifact_id].found_in
					var inspection: Dictionary = ledger.get(source,{}).get("progress",{}).get("inspect",{})
					if inspection.is_empty() or int(inspection.day) > day:
						return false
		"inspect":
			return payload.answer.is_empty()
		"puzzle":
			return payload.answer.is_empty() and payload.choice == node.puzzle.answer_id and payload.rejected == node.puzzle.reject_id
		"supported":
			return _same(world,payload.answer,phrases.supported)
		"independent":
			return _same(world,payload.answer,phrases.independent) or _same(world,payload.answer,phrases.alternative)
		"recall":
			return day > int(proof.get("independent",{}).get("day",day)) and (_same(world,payload.answer,phrases.recall) or _same(world,payload.answer,phrases.supported) or _same(world,payload.answer,phrases.independent) or _same(world,payload.answer,phrases.alternative))
		"choice":
			return payload.rejected.is_empty() and payload.choice in node.final_choice and _same(world,payload.answer,choice_model(payload.choice))
	return true

func submit(world: RefCounted,id: String,answer := "",choice := "",rejected := "",route := "",cipher := "") -> Dictionary:
	var denied := reason(world,id)
	if not denied.is_empty():
		return {"ok":false,"message":denied}
	if answer.length() > 300 or cipher.length() > 40:
		return {"ok":false,"message":"Revisa la extensión de la respuesta."}
	var step := stage(id)
	var payload := {"day":world.day,"hero":world.party.active_id,"answer":answer.strip_edges(),"choice":choice,"rejected":rejected,"route":route,"cipher":cipher.strip_edges()}
	if not _valid(world,id,step,payload,records):
		return {"ok":false,"message":"Revisa la prueba, la comparación y la forma de la frase. El recuerdo requiere un día posterior."}
	var final: bool = step == stages(id).back()
	var reward := reward_item(world,id)
	if final and not reward.is_empty() and not world.equipment.can_grant(reward,world.party.active_id):
		return {"ok":false,"message":"No hay espacio para recibir el componente. Conservas tu progreso."}
	if not records.has(id):
		records[id] = {"progress":{},"reward":""}
	records[id].progress[step] = payload
	if final and not reward.is_empty():
		records[id].reward = world.equipment.grant(reward,world.party.active_id)
	return {"ok":true,"completed":final,"message":"Expediente resuelto; la prueba permanece en el archivo." if final else "Paso registrado. La investigación continúa."}

func snapshot() -> Dictionary:
	return records.duplicate(true)

func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func restore(data: Variant,world: RefCounted) -> bool:
	if not data is Dictionary or data.size() > quests.size() or (world.map_id != "province_160x120_v1" and not data.is_empty()):
		return false
	# Validate shape before following cross-case references.
	for id in data:
		if not quests.has(id) or not data[id] is Dictionary or data[id].size() != 2:
			return false
		if not data[id].get("progress") is Dictionary or not data[id].get("reward") is String:
			return false
		var proof: Dictionary = data[id].progress
		if proof.is_empty() or proof.size() > stages(id).size():
			return false
		var previous := 0
		for index in proof.size():
			var step: String = stages(id)[index]
			var payload: Variant = proof.get(step)
			if not payload is Dictionary or payload.size() != 7 or not _integer(payload.get("day"),1,world.day):
				return false
			if payload.day < previous or payload.get("hero") not in world.party.heroes:
				return false
			if not world.party.heroes[payload.hero].unlocked:
				return false
			for field in ["answer","choice","rejected","route","cipher"]:
				if not payload.get(field) is String or payload[field].length() > (40 if field == "cipher" else 300):
					return false
			previous = int(payload.day)
	var rewards := {}
	for id: String in data:
		var record: Dictionary = data[id]
		var first_day: int = int(record.progress.access.day)
		if not prerequisites(id,data,first_day):
			return false
		for step: String in record.progress:
			var payload: Dictionary = record.progress[step]
			if not language_ready(world,id,int(payload.day)) or not _valid(world,id,step,payload,data):
				return false
		var item := reward_item(world,id)
		if complete(id,data) and not item.is_empty():
			if record.reward.is_empty() or rewards.has(record.reward) or not world.equipment.instances.has(record.reward):
				return false
			if world.equipment.instances[record.reward].item != item:
				return false
			rewards[record.reward] = true
		elif not record.reward.is_empty():
			return false
	records = data.duplicate(true)
	return true
