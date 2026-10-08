extends RefCounted
## One frozen daily plan; resolution is pure until the world applies its result.
var day := 0
var actors: Dictionary = {}
var orders: Dictionary = {}
var known: Dictionary = {}
var definitions: Dictionary = {}

func _init() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/ghost_knights.json"))
	for knight: Dictionary in catalog.knights:
		definitions[knight.id] = knight

func _cell(value: Array) -> Vector2i:
	return Vector2i(int(value[0]),int(value[1]))

func _key(value: Array) -> String:
	return "%d,%d" % [value[0],value[1]]

func _integer(value: Variant,low: int,high: int) -> bool:
	return (value is int or value is float) and is_finite(value) and value == floor(value) and value >= low and value <= high

func _valid_cell(value: Variant,world: RefCounted) -> bool:
	return value is Array and value.size() == 2 and _integer(value[0],0,world.grid.region.size.x-1) and _integer(value[1],0,world.grid.region.size.y-1) and world.terrain_cost(_cell(value)) > 0 and not world.gate_at(_cell(value)).get("closed",false)

func freeze(world: RefCounted,knight_positions: Dictionary,ai_orders: Dictionary) -> bool:
	if day == world.day or knight_positions.size() > 3 or ai_orders.size() != knight_positions.size():
		return false
	var candidate := {"day":world.day,"actors":{},"orders":{},"known":{}}
	for id: String in world.party.heroes:
		var member = world.party.heroes[id]
		if member.unlocked:
			var position := [member.cell.x,member.cell.y]
			candidate.actors[id] = {"side":0,"cell":position,"movement":member.movement_remaining,"initiative":10}
			candidate.orders[id] = {"kind":"guard","path":[position],"target":""}
	for id in knight_positions:
		if not definitions.has(id) or not ai_orders.has(id) or not ai_orders[id] is Dictionary:
			return false
		candidate.actors[id] = {"side":1,"cell":knight_positions[id],"movement":18,"initiative":int(definitions[id].orders.initiative)}
		candidate.orders[id] = ai_orders[id].duplicate(true)
	for cell: Vector2i in world.fog:
		if world.fog_at(cell) != world.Fog.UNKNOWN:
			candidate.known["%d,%d" % [cell.x,cell.y]] = true
	return restore(candidate,world)

func _valid_order(world: RefCounted,id: String,actor: Dictionary,order: Variant,visibility: Dictionary) -> bool:
	if not order is Dictionary or order.size() != 3 or order.get("kind") not in ["move","guard","intervene","recover"] or not order.get("target") is String:
		return false
	if not order.get("path") is Array or order.path.is_empty() or order.path.size() > 25:
		return false
	if order.path[0] != actor.cell:
		return false
	if actor.side == 0 and order.kind not in ["move","guard"]:
		return false
	if order.kind != "move" and order.path.size() != 1:
		return false
	if order.kind == "move" and order.path.size() < 2:
		return false
	if order.kind in ["guard","recover"] and not order.target.is_empty():
		return false
	if not order.target.is_empty() and not world.side_cases.quests.has(order.target):
		return false
	if order.kind == "intervene" and order.target.is_empty():
		return false
	var spent := 0
	for i in order.path.size():
		var point: Variant = order.path[i]
		if not _valid_cell(point,world) or (actor.side == 0 and not visibility.has(_key(point))):
			return false
		if i > 0:
			var difference: Vector2i = _cell(point)-_cell(order.path[i-1])
			if absi(difference.x)+absi(difference.y) != 1:
				return false
			spent += world.step_cost(_cell(point), id)
	if spent > int(actor.movement):
		return false
	return not id.is_empty()

func snapshot() -> Dictionary:
	return {"day":day,"actors":actors.duplicate(true),"orders":orders.duplicate(true),"known":known.duplicate()}

func restore(data: Variant,world: RefCounted) -> bool:
	if not data is Dictionary or data.size() != 4 or not _integer(data.get("day"),world.day,world.day):
		return false
	if not data.get("actors") is Dictionary or not data.get("orders") is Dictionary or not data.get("known") is Dictionary:
		return false
	if data.actors.is_empty() or data.actors.size() > 6 or data.orders.size() != data.actors.size() or data.known.size() > world.grid.region.size.x*world.grid.region.size.y:
		return false
	# Build canonical visible keys once instead of parsing up to 19,200 coordinate
	# strings on every validation. Membership still rejects hidden/out-of-map cells
	# and noncanonical spellings; this is local to this call, never a stale cache.
	var visible_keys := {}
	for cell: Vector2i in world.fog:
		if world.grid.region.has_point(cell) and world.fog_at(cell) != world.Fog.UNKNOWN:
			visible_keys["%d,%d" % [cell.x, cell.y]] = true
	for key in data.known:
		if not key is String or not data.known[key] is bool or data.known[key] != true or not visible_keys.has(key):
			return false
	var knights := 0
	for id in data.actors:
		var actor: Variant = data.actors[id]
		if not id is String or not actor is Dictionary or actor.size() != 4 or not _valid_cell(actor.get("cell"),world):
			return false
		if not _integer(actor.get("side"),0,1) or not _integer(actor.get("movement"),0,24) or not _integer(actor.get("initiative"),1,10):
			return false
		if actor.side == 0:
			if not world.party.heroes.has(id) or not world.party.heroes[id].unlocked or world.party.heroes[id].cell != _cell(actor.cell) or actor.initiative != 10 or actor.movement != world.party.heroes[id].movement_remaining:
				return false
		else:
			knights += 1
			if not definitions.has(id) or actor.initiative != definitions[id].orders.initiative or actor.movement != 18:
				return false
		if not _valid_order(world,id,actor,data.orders.get(id),data.known):
			return false
	if knights > 3:
		return false
	for id in world.party.heroes:
		if world.party.heroes[id].unlocked and not data.actors.has(id):
			return false
	day = int(data.day)
	actors = data.actors.duplicate(true)
	orders = data.orders.duplicate(true)
	known = data.known.duplicate()
	for id in actors:
		for field in ["side","movement","initiative"]:
			actors[id][field] = int(actors[id][field])
		var position := _cell(actors[id].cell)
		actors[id].cell = [position.x,position.y]
		for index in orders[id].path.size():
			position = _cell(orders[id].path[index])
			orders[id].path[index] = [position.x,position.y]
	return true

func plan_move(world: RefCounted,id: String,destination: Vector2i) -> bool:
	if day != world.day or not actors.has(id) or actors[id].side != 0:
		return false
	world._sync_gates()
	if not world.grid.region.has_point(destination) or world.known_grid.is_point_solid(destination):
		return false
	var path: Array[Vector2i] = world.known_grid.get_id_path(_cell(actors[id].cell),destination)
	var route: Array = []
	for point in path:
		route.append([point.x,point.y])
	var candidate := {"kind":"move","path":route,"target":""}
	if not _valid_order(world,id,actors[id],candidate,known):
		return false
	orders[id] = candidate
	return true

func cancel_move(id: String) -> bool:
	if not actors.has(id) or actors[id].side != 0:
		return false
	orders[id] = {"kind":"guard","path":[actors[id].cell.duplicate()],"target":""}
	return true

func resolve(world: RefCounted) -> Dictionary:
	# Revalidate into a separate object so failure cannot change the prepared plan.
	var validation = get_script().new()
	if not validation.restore(snapshot(),world):
		return {"ok":false,"error":"El mapa cambió; revisa las órdenes."}
	var positions := {}
	var spent := {}
	var indices := {}
	var remaining := {}
	var stopped := {}
	var encounter := {}
	for id in actors:
		positions[id] = actors[id].cell.duplicate()
		spent[id] = 0
		indices[id] = 0
		remaining[id] = world.step_cost(_cell(orders[id].path[1]), id) if orders[id].path.size() > 1 else 0
	for tick in range(1,25):
		var proposed: Dictionary = positions.duplicate(true)
		for id in actors:
			if stopped.has(id) or int(indices[id])+1 >= orders[id].path.size():
				continue
			remaining[id] -= 1
			if remaining[id] == 0:
				proposed[id] = orders[id].path[int(indices[id])+1].duplicate()
		var contacts: Array = []
		for hero in actors:
			if actors[hero].side != 0:
				continue
			for knight in actors:
				if actors[knight].side != 1 or orders[knight].kind == "recover" or (stopped.has(hero) and stopped.has(knight)):
					continue
				var same: bool = proposed[hero] == proposed[knight]
				var edge: bool = positions[hero] == proposed[knight] and positions[knight] == proposed[hero] and positions[hero] != positions[knight]
				if same or edge:
					contacts.append({"hero":hero,"knight":knight,"kind":"destination" if same else "edge","tick":tick})
		contacts.sort_custom(func(a: Dictionary,b: Dictionary):
			if actors[a.knight].initiative != actors[b.knight].initiative:
				return actors[a.knight].initiative > actors[b.knight].initiative
			return str(a.knight)+str(a.hero) < str(b.knight)+str(b.hero))
		if not contacts.is_empty():
			for contact: Dictionary in contacts:
				stopped[contact.hero] = true
				stopped[contact.knight] = true
			if encounter.is_empty():
				encounter = contacts[0].duplicate()
				encounter["hero_previous"] = positions[encounter.hero].duplicate()
				if encounter.kind == "destination":
					for id: String in [encounter.hero,encounter.knight]:
						if proposed[id] != positions[id]:
							spent[id] += world.step_cost(_cell(proposed[id]), id)
						positions[id] = proposed[id].duplicate()
				encounter["hero_cell"] = positions[encounter.hero].duplicate()
				encounter["knight_cell"] = positions[encounter.knight].duplicate()
		for id in actors:
			if stopped.has(id) or proposed[id] == positions[id]:
				continue
			positions[id] = proposed[id].duplicate()
			spent[id] += world.step_cost(_cell(positions[id]), id)
			indices[id] += 1
			remaining[id] = world.step_cost(_cell(orders[id].path[int(indices[id])+1]), id) if int(indices[id])+1 < orders[id].path.size() else 0
	return {"ok":true,"positions":positions,"spent":spent,"stopped":stopped,"encounter":encounter}
