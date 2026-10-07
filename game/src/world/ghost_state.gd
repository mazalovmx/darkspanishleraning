extends RefCounted
## Bounded optional-story opposition. Never edits evidence, equipment or main claims.
const Turn = preload("res://src/world/simultaneous_turn.gd")
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/ghost_knights.json"))
var definitions: Dictionary = {}
var actors: Dictionary = {}
var effects: Dictionary = {}
var target_days: Dictionary = {}
var journal: Array = []
var event_count := 0
var last_resolved_day := 0
var plan: RefCounted
var countered: Array = []
const COUNTER_TAGS := [["hay"],["present"],["preterite"],["imperfect"],["relative_clauses"],["perfect"],["conditional","subjunctive_basic"]]
const REPLIES := {
	"NK01":"Veo la etiqueta original en «%s».",
	"NK02":"Pido un testigo para comprobar la entrega de «%s».",
	"NK03":"Comparé la hora original de «%s» con la hora nueva.",
	"NK04":"Todos repetían una versión de «%s», pero comparé la fuente original.",
	"NK05":"Pido el fragmento y presento la prueba «%s».",
	"NK06":"La copia perdió una parte; encontré otra versión en «%s».",
	"NK07":"Propondría revisar la promesa para que respete la prueba «%s».",
	"NK08":"La prueba «%s» no demuestra la causa que afirma el caballero."
}

func _init() -> void:
	for knight: Dictionary in catalog.knights:
		definitions[knight.id] = knight

func _cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]),int(value[1]))

func _location(world: RefCounted,id: String) -> Vector2i:
	for location: Dictionary in world.locations:
		if location.id == id:
			return _cell(location.position)
	return Vector2i(-1,-1)

func language_ready(world: RefCounted,id: String,day: int) -> bool:
	var block: int = int(definitions[id].minimum_curriculum_block)-1
	return world.campaign.language_ready(world,{"min_block":block,"grammar":COUNTER_TAGS[block]},day)

func _started(world: RefCounted,branch: String) -> bool:
	for id: String in world.side_cases.branches[branch].quest_ids:
		if world.side_cases.records.has(id):
			return not world.side_cases.complete(world.side_cases.branches[branch].final_quest,world.side_cases.records)
	return false

func _eligible(world: RefCounted,id: String) -> bool:
	if not language_ready(world,id,world.day):
		return false
	for branch: String in definitions[id].spawn.branch_ids:
		if _started(world,branch):
			return true
	return false

func _activate(world: RefCounted) -> void:
	for id in actors:
		actors[id].active = false
	var count := 0
	# Activate at most three eligible profiles in stable ID order.
	for id: String in definitions:
		if count >= 3:
			break
		if not _eligible(world,id) or (actors.has(id) and actors[id].active):
			continue
		if actors.has(id):
			actors[id].active = true
			count += 1
			continue
		var center := Vector2i(-1,-1)
		for branch: String in definitions[id].spawn.branch_ids:
			if _started(world,branch):
				center = _location(world,world.side_cases.branches[branch].location_id)
				break
		for offset in [Vector2i(-2,0),Vector2i(2,0),Vector2i(0,-2),Vector2i(0,2),Vector2i(-1,0),Vector2i(1,0)]:
			var cell: Vector2i = center + offset
			if world.terrain_cost(cell) == 0 or world.gate_at(cell).get("closed",false):
				continue
			var occupied := false
			for hero in world.party.heroes.values():
				occupied = occupied or (hero.unlocked and hero.cell == cell)
			for actor in actors.values():
				occupied = occupied or (actor.active and _cell(actor.cell) == cell)
			if occupied:
				continue
			actors[id] = {"cell":[cell.x,cell.y],"next_day":world.day,"return_day":0,"active":true,"born_day":world.day}
			count += 1
			break

func _perceived_locations(world: RefCounted,cell: Vector2i) -> Array:
	var visible: Array = []
	for location: Dictionary in world.locations:
		var position := _cell(location.position)
		if world.fog_at(position) != world.Fog.UNKNOWN:
			visible.append({"id":location.id,"distance":cell.distance_squared_to(position)})
	visible.sort_custom(func(a: Dictionary,b: Dictionary):
		return a.distance < b.distance if a.distance != b.distance else a.id < b.id)
	var result := []
	for index in mini(3,visible.size()):
		result.append(visible[index].id)
	return result

func _score(world: RefCounted,knight: String,id: String) -> int:
	var node: Dictionary = world.side_cases.quests[id]
	var proof: Dictionary = world.side_cases.records.get(id,{}).get("progress",{})
	var score := 10 if not proof.is_empty() else 0
	match knight:
		"NK01": score += 40 if not proof.has("puzzle") else 0
		"NK02": score += 40 if node.investigation.source_kind in ["document","record"] else 0
		"NK03": score += 40 if node.investigation.source_kind == "testimony" else 0
		"NK04": score += 40 if node.investigation.source_kind in ["testimony","comparison"] else 0
		"NK05": score += 60 if not world.side_cases.reward_item(world,id).is_empty() else -1000
		"NK06": score += 40 if node.investigation.source_kind in ["document","record"] and not proof.has("inspect") else 0
		"NK07": score += 60 if not node.final_choice.is_empty() else -1000
		"NK08": score += 40 if not proof.has("puzzle") and node.investigation.source_kind in ["experiment","dossier"] else 0
	return score

func targets(world: RefCounted,id: String) -> Array:
	var perceived := _perceived_locations(world,_cell(actors[id].cell))
	var result := []
	for quest_id: String in world.side_cases.quests:
		var node: Dictionary = world.side_cases.quests[quest_id]
		if node.branch_id not in definitions[id].spawn.branch_ids or node.location_id not in perceived or not _started(world,node.branch_id):
			continue
		if world.side_cases.complete(quest_id,world.side_cases.records) or not world.side_cases.prerequisites(quest_id,world.side_cases.records,world.day) or not world.side_cases.language_ready(world,quest_id,world.day):
			continue
		if id == "NK05":
			var item: String = world.side_cases.reward_item(world,quest_id)
			if item.is_empty() or not world.equipment.can_grant(item,world.party.active_id):
				continue
		if _score(world,id,quest_id) >= 0:
			result.append(quest_id)
	result.sort_custom(func(a: String,b: String):
		var left := _score(world,id,a)
		var right := _score(world,id,b)
		return left > right if left != right else a < b)
	return result

func _order(world: RefCounted,id: String) -> Dictionary:
	var actor: Dictionary = actors[id]
	var cell := _cell(actor.cell)
	var result := {"kind":"guard","path":[actor.cell.duplicate()],"target":""}
	if actor.return_day > world.day:
		result.kind = "recover"
		return result
	var candidates := targets(world,id)
	if candidates.is_empty():
		return result
	var target: String = candidates[0]
	var node: Dictionary = world.side_cases.quests[target]
	var destination := _location(world,node.location_id)
	if cell.distance_squared_to(destination) <= 4:
		if actor.next_day <= world.day and world.day - int(target_days.get(target,-3)) >= 3 and not effects.has(node.branch_id):
			result.kind = "intervene"
			result.target = target
		return result
	world._sync_gates()
	var path: Array[Vector2i] = world.grid.get_id_path(cell,destination)
	var budget := 18
	var route: Array = [actor.cell.duplicate()]
	for index in range(1,path.size()):
		var cost: int = world.terrain_cost(path[index])
		if cost > budget:
			break
		budget -= cost
		route.append([path[index].x,path[index].y])
	if route.size() > 1:
		result = {"kind":"move","path":route,"target":target}
	return result

func prepare(world: RefCounted) -> bool:
	if world.map_id != "province_160x120_v1" or last_resolved_day >= world.day:
		return false
	if plan != null:
		return plan.day == world.day
	var original := actors.duplicate(true)
	_activate(world)
	var positions := {}
	var ai := {}
	for id: String in actors:
		if actors[id].active:
			positions[id] = actors[id].cell.duplicate()
			ai[id] = _order(world,id)
	var candidate := Turn.new()
	if not candidate.freeze(world,positions,ai):
		actors = original
		return false
	plan = candidate
	return true

func _event(day: int,id: String,target: String,kind: String,expiry := 0,proof: Dictionary = {}) -> void:
	event_count += 1
	journal.append({"id":event_count,"day":day,"knight":id,"target":target,"kind":kind,
		"trace":str(definitions[id].intervention.trace),"expiry":expiry,"proof":proof.duplicate(true)})
	if journal.size() > 100:
		journal.pop_front()

func resolve(world: RefCounted) -> Dictionary:
	if not prepare(world):
		return {"ok":false}
	var effective := Turn.new()
	if not effective.restore(plan.snapshot(),world):
		return {"ok":false}
	for id in actors:
		if actors[id].active and actors[id].return_day > world.day:
			effective.orders[id] = {"kind":"recover","path":[effective.actors[id].cell.duplicate()],"target":""}
	var result: Dictionary = effective.resolve(world)
	if not result.ok:
		return result
	var next_day: int = world.day+1
	for branch: String in effects.keys():
		if int(effects[branch].expiry) <= next_day:
			_event(next_day,effects[branch].knight,effects[branch].target,"expired")
			effects.erase(branch)
	for id: String in actors:
		if actors[id].active:
			actors[id].cell = result.positions[id].duplicate()
	var applied := 0
	var ids: Array = plan.orders.keys().filter(func(id: String): return definitions.has(id))
	ids.sort_custom(func(a: String,b: String):
		if actors[a].next_day != actors[b].next_day:
			return actors[a].next_day < actors[b].next_day
		return definitions[a].orders.initiative > definitions[b].orders.initiative if definitions[a].orders.initiative != definitions[b].orders.initiative else a < b)
	for id: String in ids:
		var order: Dictionary = plan.orders[id]
		if order.kind != "intervene" or id in countered or result.stopped.has(id) or applied >= 2:
			continue
		var target: String = order.target
		var node: Dictionary = world.side_cases.quests[target]
		if world.side_cases.complete(target,world.side_cases.records) or effects.has(node.branch_id):
			continue
		if id == "NK05" and not world.equipment.can_grant(world.side_cases.reward_item(world,target),world.party.active_id):
			continue
		var effect: String = definitions[id].orders.effect_id
		var expiry: int = next_day+int(catalog.effects[effect].max_turns)
		effects[node.branch_id] = {"knight":id,"target":target,"start":next_day,"expiry":expiry}
		actors[id].next_day = next_day+3
		target_days[target] = next_day
		_event(next_day,id,target,"intervention",expiry)
		applied += 1
	last_resolved_day = world.day
	plan = null
	countered.clear()
	return result

func blocked(world: RefCounted,id: String) -> String:
	var branch: String = world.side_cases.quests[id].branch_id
	if not effects.has(branch) or effects[branch].target != id or effects[branch].expiry <= world.day:
		return ""
	var knight: String = effects[branch].knight
	var step: String = world.side_cases.stage(id)
	var affected := false
	match definitions[knight].orders.effect_id:
		"ambiguous_label","fragment_escrow": affected = step == str(world.side_cases.stages(id).back())
		"custody_disputed","meeting_shifted","copy_redacted": affected = step in ["access","inspect"]
		"rumor_pressure","causal_claim_contested": affected = step == "puzzle"
		"promise_contested": affected = step == "choice"
	return knight if affected else ""

func sources(world: RefCounted,target: String) -> Array:
	var result := []
	var branch: String = world.side_cases.quests[target].branch_id
	for id: String in world.side_cases.branches[branch].quest_ids:
		if world.side_cases.records.get(id,{}).get("progress",{}).has("inspect"):
			result.append(world.side_cases.quests[id].artifact_id)
	return result

func counter_model(world: RefCounted,id: String,artifact: String) -> String:
	if not definitions.has(id) or not world.side_cases.artifacts.has(artifact):
		return ""
	return str(REPLIES[id]) % world.side_cases.artifacts[artifact].name

func counter(world: RefCounted,id: String,target: String,answer: String,proof: Array,use_soul := false) -> bool:
	if not definitions.has(id) or not world.side_cases.quests.has(target) or world.active_battle != null or not world.trade.pending.is_empty() or not world.economy.pending.is_empty():
		return false
	var branch: String = world.side_cases.quests[target].branch_id
	var active: bool = effects.has(branch) and effects[branch].knight == id and effects[branch].target == target and effects[branch].expiry > world.day
	var planned: bool = plan != null and plan.orders.has(id) and plan.orders[id].kind == "intervene" and plan.orders[id].target == target and id not in countered
	if not active and not planned:
		return false
	if world.hero_cell != _location(world,world.side_cases.quests[target].location_id) or not language_ready(world,id,world.day):
		return false
	var required := 2 if id in ["NK02","NK03","NK04","NK08"] and not use_soul else 1
	if proof.size() != required or (proof.size() == 2 and proof[0] == proof[1]) or answer.length() > 300:
		return false
	var available := sources(world,target)
	for artifact in proof:
		if not artifact is String or artifact not in available:
			return false
	if world.learner.curriculum.normalized(answer) != world.learner.curriculum.normalized(counter_model(world,id,proof[0])):
		return false
	if use_soul:
		var set_id: Variant = definitions[id].counter.soul_set
		if not set_id is String or world.equipment.consume_special(world,set_id).is_empty():
			return false
	if active:
		effects.erase(branch)
	if planned:
		countered.append(id)
	_event(world.day,id,target,"counter",0,{"answer":answer.strip_edges(),"sources":proof.duplicate(),"soul":use_soul,"hero":world.party.active_id})
	return true

func defeat(world: RefCounted,id: String) -> bool:
	if not actors.has(id) or not actors[id].active:
		return false
	actors[id].return_day = world.day+3
	actors[id].next_day = maxi(int(actors[id].next_day),world.day+3)
	for branch: String in effects.keys():
		if effects[branch].knight == id:
			effects.erase(branch)
	if plan != null and id not in countered:
		countered.append(id)
	_event(world.day,id,"","defeated")
	return true

func encounter_definition(id: String) -> Dictionary:
	if not definitions.has(id) or not actors.has(id) or not actors[id].active:
		return {}
	var enemies := []
	for stack: Dictionary in definitions[id].battle.enemy_stacks:
		enemies.append({"type":str(stack.unit),"count":int(stack.count)})
	return {"id":id,"name":definitions[id].name,"position":actors[id].cell.duplicate(),
		"enemies":enemies,"requires":"","reward":{},"script":definitions[id].battle.script.duplicate(true)}

func snapshot() -> Dictionary:
	return {"actors":actors.duplicate(true),"effects":effects.duplicate(true),"target_days":target_days.duplicate(),
		"journal":journal.duplicate(true),"event_count":event_count,"last_resolved_day":last_resolved_day,
		"plan":{} if plan == null else plan.snapshot(),"countered":countered.duplicate()}

func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func _counter_proof(world: RefCounted,id: String,target: String,day: int,proof: Variant) -> bool:
	if not proof is Dictionary or proof.size() != 4 or not proof.get("answer") is String or proof.answer.length() > 300:
		return false
	if not proof.get("soul") is bool or proof.get("hero") not in world.party.heroes or not proof.get("sources") is Array:
		return false
	if not language_ready(world,id,day):
		return false
	var required := 2 if id in ["NK02","NK03","NK04","NK08"] and not proof.soul else 1
	if proof.sources.size() != required or (required == 2 and proof.sources[0] == proof.sources[1]):
		return false
	var branch: String = world.side_cases.quests[target].branch_id
	for artifact in proof.sources:
		if not artifact is String or not world.side_cases.artifacts.has(artifact) or world.side_cases.artifacts[artifact].branch_id != branch:
			return false
		var quest: String = world.side_cases.artifacts[artifact].found_in
		var inspection: Dictionary = world.side_cases.records.get(quest,{}).get("progress",{}).get("inspect",{})
		if inspection.is_empty() or int(inspection.day) > day:
			return false
	if world.learner.curriculum.normalized(proof.answer) != world.learner.curriculum.normalized(counter_model(world,id,proof.sources[0])):
		return false
	if proof.soul:
		var set_id: Variant = definitions[id].counter.soul_set
		if not set_id is String:
			return false
		var consent_day: int = int(world.equipment.rituals.get(proof.hero,{}).get(set_id,{}).get("consent",{}).get("day",0))
		if consent_day < 1 or consent_day > day or int(world.equipment.special_used.get(set_id,0)) < day:
			return false
	return true

func restore(data: Variant,world: RefCounted) -> bool:
	if not data is Dictionary or data.size() != 8:
		return false
	for key in ["actors","effects","target_days","plan"]:
		if not data.get(key) is Dictionary:
			return false
	if not data.get("journal") is Array or not data.get("countered") is Array or data.countered.size() > 3:
		return false
	if not _integer(data.get("event_count"),0,1000000) or not _integer(data.get("last_resolved_day"),0,maxi(0,world.day-1)):
		return false
	if data.actors.size() > 8 or data.effects.size() > 4 or data.journal.size() != mini(100,int(data.event_count)):
		return false
	if world.map_id != "province_160x120_v1" and (not data.actors.is_empty() or not data.effects.is_empty() or not data.plan.is_empty() or data.event_count != 0 or not data.target_days.is_empty() or data.last_resolved_day != 0):
		return false
	var active := 0
	for id in data.actors:
		var actor: Variant = data.actors[id]
		if not definitions.has(id) or not actor is Dictionary or actor.size() != 5 or not actor.get("active") is bool:
			return false
		if not actor.get("cell") is Array or actor.cell.size() != 2 or not _integer(actor.cell[0],0,world.grid.region.size.x-1) or not _integer(actor.cell[1],0,world.grid.region.size.y-1):
			return false
		if world.terrain_cost(_cell(actor.cell)) == 0 or not _integer(actor.get("born_day"),1,world.day) or not _integer(actor.get("next_day"),1,world.day+3) or not _integer(actor.get("return_day"),0,world.day+3):
			return false
		if not language_ready(world,id,int(actor.born_day)):
			return false
		var witnessed := false
		for branch: String in definitions[id].spawn.branch_ids:
			for quest: String in world.side_cases.branches[branch].quest_ids:
				var access: Dictionary = world.side_cases.records.get(quest,{}).get("progress",{}).get("access",{})
				witnessed = witnessed or (not access.is_empty() and int(access.day) <= actor.born_day)
		if not witnessed:
			return false
		if actor.return_day > world.day:
			var victory: Dictionary = world.encounters.get(id,{})
			if victory.get("outcome","") != "victory" or int(victory.get("day",0))+3 != actor.return_day:
				return false
		active += 1 if actor.active else 0
	if active > 3:
		return false
	for target in data.target_days:
		if not world.side_cases.quests.has(target) or not _integer(data.target_days[target],1,world.day):
			return false
	var previous_day := 0
	var counts := {}
	var previous_targets := {}
	var recent_effects := {}
	var interrupted := {}
	for index in data.journal.size():
		var event: Variant = data.journal[index]
		if not event is Dictionary or event.size() != 8 or not _integer(event.get("id"),int(data.event_count)-data.journal.size()+index+1,int(data.event_count)-data.journal.size()+index+1):
			return false
		if not _integer(event.get("day"),1,world.day) or event.day < previous_day or not definitions.has(event.get("knight")) or event.get("kind") not in ["intervention","expired","counter","defeated"]:
			return false
		if not data.actors.has(event.knight) or event.day < data.actors[event.knight].born_day or event.get("trace") != definitions[event.knight].intervention.trace or not event.get("proof") is Dictionary:
			return false
		if event.kind == "defeated":
			if event.get("target") != "":
				return false
		elif not world.side_cases.quests.has(event.get("target")) or world.side_cases.quests[event.target].branch_id not in definitions[event.knight].spawn.branch_ids:
			return false
		if event.kind == "intervention":
			var duration: int = int(catalog.effects[definitions[event.knight].orders.effect_id].max_turns)
			if not _integer(event.get("expiry"),int(event.day)+duration,int(event.day)+duration) or not language_ready(world,event.knight,int(event.day)):
				return false
			counts[int(event.day)] = int(counts.get(int(event.day),0))+1
			if counts[int(event.day)] > 2 or int(event.day)-int(previous_targets.get(event.target,-3)) < 3:
				return false
			previous_targets[event.target] = int(event.day)
			recent_effects[event.knight+"/"+event.target] = event
		elif event.get("expiry") != 0:
			return false
		if event.kind == "counter":
			if not _counter_proof(world,event.knight,event.target,int(event.day),event.proof):
				return false
		elif not event.proof.is_empty():
			return false
		if event.kind in ["counter","expired"]:
			recent_effects.erase(event.knight+"/"+event.target)
		elif event.kind == "defeated":
			for key: String in recent_effects.keys():
				if key.begins_with(event.knight+"/"):
					recent_effects.erase(key)
		if event.kind in ["counter","defeated"] and event.day == world.day:
			interrupted[event.knight] = true
		previous_day = int(event.day)
	for target in previous_targets:
		if data.target_days.get(target,0) != previous_targets[target]:
			return false
	for branch in data.effects:
		var effect: Variant = data.effects[branch]
		if not world.side_cases.branches.has(branch) or not effect is Dictionary or effect.size() != 4 or not data.actors.has(effect.get("knight")) or not world.side_cases.quests.has(effect.get("target")):
			return false
		if world.side_cases.quests[effect.target].branch_id != branch or not _integer(effect.get("start"),1,world.day) or not _integer(effect.get("expiry"),world.day+1,world.day+2):
			return false
		var event: Dictionary = recent_effects.get(effect.knight+"/"+effect.target,{})
		if event.is_empty() or effect.start != event.day or effect.expiry != event.expiry or data.target_days.get(effect.target,0) != effect.start:
			return false
		if data.actors[effect.knight].next_day < effect.start+3:
			return false
	var restored_plan: RefCounted
	if not data.plan.is_empty():
		restored_plan = Turn.new()
		if not restored_plan.restore(data.plan,world):
			return false
		for id in data.actors:
			if data.actors[id].active:
				if not restored_plan.actors.has(id) or _cell(restored_plan.actors[id].cell) != _cell(data.actors[id].cell):
					return false
		for id in restored_plan.actors:
			if restored_plan.actors[id].side == 1:
				if not data.actors.has(id) or not data.actors[id].active:
					return false
				var target: String = restored_plan.orders[id].target
				if not target.is_empty() and world.side_cases.quests[target].branch_id not in definitions[id].spawn.branch_ids:
					return false
	elif not data.countered.is_empty():
		return false
	var seen := {}
	for id in data.countered:
		if not id is String or seen.has(id) or not interrupted.has(id) or restored_plan == null or not restored_plan.orders.has(id):
			return false
		seen[id] = true
	actors = data.actors.duplicate(true)
	for id in actors:
		var cell := _cell(actors[id].cell)
		actors[id].cell = [cell.x,cell.y]
		for field in ["born_day","next_day","return_day"]:
			actors[id][field] = int(actors[id][field])
	effects = data.effects.duplicate(true)
	for effect: Dictionary in effects.values():
		effect.start = int(effect.start)
		effect.expiry = int(effect.expiry)
	target_days = data.target_days.duplicate()
	for id in target_days:
		target_days[id] = int(target_days[id])
	journal = data.journal.duplicate(true)
	for event: Dictionary in journal:
		for field in ["id","day","expiry"]:
			event[field] = int(event[field])
	event_count = int(data.event_count)
	last_resolved_day = int(data.last_resolved_day)
	plan = restored_plan
	countered = data.countered.duplicate()
	return true
