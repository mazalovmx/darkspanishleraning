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
			actors[id] = {"cell":[cell.x,cell.y],"next_day":world.day,"return_day":0,"active":true}
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

func _event(day: int,id: String,target: String,kind: String,expiry := 0) -> void:
	event_count += 1
	journal.append({"id":event_count,"day":day,"knight":id,"target":target,"kind":kind,
		"trace":str(definitions[id].intervention.trace),"expiry":expiry})
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
	_event(world.day,id,target,"counter")
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
