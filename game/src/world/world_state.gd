extends RefCounted
## Canonical prototype state, independent of the map's visual nodes.

const COSTS := {"road": 1, "grass": 1, "field": 1, "forest": 2, "marsh": 3,
	"ruins": 2, "snow": 2, "mountain": 0, "water": 0}
enum Fog { UNKNOWN, EXPLORED, VISIBLE }
const MAPS := {"prototype_20x20_v1": "res://content/world/prototype.json",
	"province_160x120_v1": "res://content/world/province.json"}
var map_id := "prototype_20x20_v1"
var map_data: Dictionary = {}
const VIEW_RADIUS := 5
## Extra sight for a hero who carries lamp oil.
const LAMP_RADIUS := 2
## Movement lost waiting at a bridge post without the toll pass (salvoconducto).
const TOLL_WAIT := 4
const MOVEMENT_MAX := 18
## Daily movement of the active hero before equipment, with the game's movement scale.
static func movement_max() -> int:
	return MOVEMENT_MAX * maxi(1, preload("res://src/world/party_state.gd").movement_scale)
var ghosts = preload("res://src/world/ghost_state.gd").new()
var turn_notice := ""
var side_cases = preload("res://src/world/side_investigations.gd").new()
var equipment = preload("res://src/world/equipment_state.gd").new()
var economy = preload("res://src/economy/strategy_economy.gd").new()
var party = preload("res://src/world/party_state.gd").new()
var learner = preload("res://src/spanish/learner_profile.gd").new()
# npc id -> {count, last_day, topics}; facts about past talks, never generated prose.
var npc_memory: Dictionary = {}
var trade = preload("res://src/economy/trade_state.gd").new()
var campaign = preload("res://src/world/campaign_state.gd").new()
var evidence = preload("res://src/evidence/evidence_graph.gd").new()
const StackBattle = preload("res://src/combat/stack_battle.gd")
var army: Array:
	get:
		return party.active().army
	set(value):
		party.active().army = value
var resources := {"gold": 300, "wood": 5, "ore": 5, "mercury": 0, "sulfur": 0, "crystal": 0, "gems": 0}
var encounters: Dictionary = {}
var active_battle: RefCounted
var active_encounter := ""
var day := 1
var hero_cell: Vector2i:
	get:
		return party.active().cell
	set(value):
		party.active().cell = value
var movement_remaining: int:
	get:
		return party.active().movement_remaining
	set(value):
		party.active().movement_remaining = value
var terrain: Array = []
## Bridge cells (Vector2i -> true), derived from the terrain.
var bridges := {}
var grid := AStarGrid2D.new()
var known_grid := AStarGrid2D.new()
var fog: Dictionary = {}
var locations: Array = []

func _init(selected_map := "prototype_20x20_v1") -> void:
	assert(MAPS.has(selected_map), "Unknown authored map")
	map_id = selected_map
	trade.inventory = party.active().inventory
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MAPS[map_id]))
	map_data = data
	if data.has("hero_starts"):
		for id in party.heroes:
			var position: Array = data.hero_starts[id]
			party.heroes[id].cell = Vector2i(position[0], position[1])
			party.heroes[id].unlocked = id == "inquisitor"
	locations = data.get("locations", [])
	for row: String in data.rows:
		var cells: Array[String] = []
		for symbol in row:
			cells.append(data.legend[symbol])
		terrain.append(cells)
	grid.region = Rect2i(0, 0, terrain[0].size(), terrain.size())
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			var cell := Vector2i(x, y)
			var cost := terrain_cost(cell)
			grid.set_point_solid(cell, cost == 0)
			grid.set_point_weight_scale(cell, maxi(1, cost))

	# Bridges: road cells with water on both sides (province map only).
	if map_id == "province_160x120_v1":
		for y in range(1, grid.region.size.y - 1):
			for x in range(1, grid.region.size.x - 1):
				if terrain[y][x] == "road" and ((terrain[y][x - 1] == "water" and terrain[y][x + 1] == "water") or (terrain[y - 1][x] == "water" and terrain[y + 1][x] == "water")):
					bridges[Vector2i(x, y)] = true

	known_grid.region = grid.region
	known_grid.diagonal_mode = grid.diagonal_mode
	known_grid.default_compute_heuristic = grid.default_compute_heuristic
	known_grid.default_estimate_heuristic = grid.default_estimate_heuristic
	known_grid.update()
	for y in grid.region.size.y:
		for x in grid.region.size.x:
			known_grid.set_point_solid(Vector2i(x, y), true)
	_sync_gates()
	_reveal_from(hero_cell)

func fog_at(cell: Vector2i) -> int:
	return fog.get(cell, Fog.UNKNOWN)

## How far a hero sees: two cells more while carrying lamp oil.
func view_radius(id: String) -> int:
	var hero = party.heroes.get(id)
	return VIEW_RADIUS + (LAMP_RADIUS if hero != null and int(hero.inventory.get("lamp_oil", 0)) > 0 else 0)

func _reveal_from(center: Vector2i) -> void:
	for cell in fog:
		fog[cell] = Fog.EXPLORED
	var centers: Array = [[center, view_radius(party.active_id)]]
	for id in party.heroes:
		if id != party.active_id and party.heroes[id].unlocked:
			centers.append([party.heroes[id].cell, view_radius(id)])
	for pair: Array in centers:
		var origin: Vector2i = pair[0]
		var radius: int = pair[1]
		for y in range(origin.y - radius, origin.y + radius + 1):
			for x in range(origin.x - radius, origin.x + radius + 1):
				var cell := Vector2i(x, y)
				if grid.region.has_point(cell) and origin.distance_squared_to(cell) <= radius * radius:
					fog[cell] = Fog.VISIBLE
					known_grid.set_point_solid(cell, terrain_cost(cell) == 0 or gate_at(cell).get("closed", false))
					known_grid.set_point_weight_scale(cell, maxi(1, terrain_cost(cell)))

func location_at(cell: Vector2i) -> Dictionary:
	if fog_at(cell) == Fog.UNKNOWN:
		return {}
	for location: Dictionary in locations:
		if Vector2i(location.position[0], location.position[1]) == cell:
			return location
	return {}

func terrain_cost(cell: Vector2i) -> int:
	if not grid.region.has_point(cell):
		return 0
	return COSTS[terrain[cell.y][cell.x]]

func path_to(destination: Vector2i, discovered_only := false) -> Array[Vector2i]:
	_sync_gates()
	if terrain_cost(destination) == 0 or gate_at(destination).get("closed", false):
		return []
	if discovered_only:
		if fog_at(destination) == Fog.UNKNOWN:
			return []
		return known_grid.get_id_path(hero_cell, destination)
	return grid.get_id_path(hero_cell, destination)

## Movement a hero spends to enter a cell: its terrain, plus the wait at a bridge post
## for a hero without the toll pass. Knights and unknown ids pay terrain only.
func step_cost(cell: Vector2i, hero_id := "") -> int:
	var cost := terrain_cost(cell)
	var id: String = party.active_id if hero_id.is_empty() else hero_id
	if cost > 0 and bridges.has(cell) and party.heroes.has(id) and int(party.heroes[id].inventory.get("salvoconducto", 0)) == 0:
		cost += TOLL_WAIT
	return cost

func path_cost(path: Array[Vector2i]) -> int:
	var cost := 0
	for i in range(1, path.size()):
		cost += step_cost(path[i])
	return cost

func move_to(destination: Vector2i, discovered_only := false) -> bool:
	if active_battle != null or not ghosts.pending_encounter.is_empty() or (map_id == "province_160x120_v1" and (not trade.pending.is_empty() or not economy.pending.is_empty())):
		return false
	if map_id == "province_160x120_v1":
		var fresh: bool = ghosts.plan == null
		var actors: Dictionary = ghosts.actors.duplicate(true)
		if ghosts.prepare(self) and ghosts.plan.plan_move(self,party.active_id,destination):
			return true
		# A rejected destination must not leave the day's orders frozen.
		if fresh:
			ghosts.plan = null
			ghosts.actors = actors
		return false
	var path := path_to(destination, discovered_only)
	if path.size() < 2:
		return false
	var cost := path_cost(path)
	if cost > movement_remaining:
		return false
	for cell in path:
		_reveal_from(cell)
	hero_cell = destination
	movement_remaining -= cost
	return true

# Hands troops (key = army index) or supplies (key = item id) to a hero on the same cell.
func transfer(kind: String, to_id: String, key: Variant, quantity: int) -> bool:
	if planning_active() or active_battle != null or not trade.pending.is_empty() or not economy.pending.is_empty():
		return false
	if kind == "stack":
		return party.transfer_stack(party.active_id, to_id, int(key), quantity)
	return party.transfer_supply(party.active_id, to_id, str(key), quantity)

func remember(npc_id: String, intent: String, on_day: int) -> void:
	var entry: Dictionary = npc_memory.get(npc_id, {"count": 0, "last_day": on_day, "topics": []})
	entry.count = mini(int(entry.count) + 1, 100000)
	entry.last_day = on_day
	if intent != "unknown" and intent not in entry.topics:
		entry.topics.append(intent)
	npc_memory[npc_id] = entry

## Survival dialogues of master spec 30, in the spec's order: key -> [name, where].
const SURVIVAL := {
	"food": ["Comida: «¿Tiene pan?»", "el posadero de la Venta del Perro Negro"],
	"water": ["Agua: «¿Hay agua potable?»", "el posadero de la Venta del Perro Negro"],
	"medicine": ["Medicina: «Necesito vendas.»", "la doctora Valera en el hospital de Miralba"],
	"inn": ["Posada: «Necesito una habitación para esta noche.»", "el posadero de la Venta del Perro Negro"],
	"directions": ["Direcciones: «¿Cómo llego al monasterio?»", "el posadero o la doctora Valera"],
	"road": ["Seguridad del camino: «¿Es seguro el camino del norte?»", "el posadero de la Venta del Perro Negro"],
	"stable": ["Establo: «Necesito comida para el caballo.»", "el posadero de la Venta del Perro Negro"],
	"complaint": ["Queja: «Pedí aceite, no vino.»", "el posadero de la Venta del Perro Negro"],
	"permission": ["Permiso: «Necesito entrar.»", "Fermín Cuesta en el Archivo Episcopal"]}
const SURVIVAL_TOPIC := "survival:"

## Marks a survival exchange as carried through with this character (after remember()).
func note_survival(npc_id: String, key: String) -> void:
	if not SURVIVAL.has(key) or not npc_memory.has(npc_id):
		return
	if SURVIVAL_TOPIC + key not in npc_memory[npc_id].topics:
		npc_memory[npc_id].topics.append(SURVIVAL_TOPIC + key)

## Survival exchanges carried through with anyone, as SURVIVAL keys.
func survival_done() -> Array:
	var done: Array = []
	for key: String in SURVIVAL:
		for npc_id: String in npc_memory:
			if SURVIVAL_TOPIC + key in npc_memory[npc_id].get("topics", []):
				done.append(key)
				break
	return done

func planning_active() -> bool:
	return ghosts.plan != null or not ghosts.pending_encounter.is_empty()

func end_turn() -> void:
	turn_notice = ""
	if active_battle != null or not ghosts.pending_encounter.is_empty() or (map_id == "province_160x120_v1" and (not trade.pending.is_empty() or not economy.pending.is_empty())):
		return
	if map_id == "province_160x120_v1":
		if not ghosts.prepare(self):
			turn_notice = "No se pudo preparar el turno."
			return
		var routes: Dictionary = ghosts.plan.orders.duplicate(true)
		var resolved: Dictionary = ghosts.resolve(self)
		if not resolved.ok:
			turn_notice = resolved.get("error","Revisa las órdenes antes de resolver.")
			return
		for id: String in party.heroes:
			if resolved.positions.has(id):
				party.heroes[id].cell = Vector2i(resolved.positions[id][0],resolved.positions[id][1])
		for id: String in party.heroes:
			if not routes.has(id):
				continue
			var last: int = routes[id].path.find(resolved.positions[id])
			for index in range(last+1):
				_reveal_from(Vector2i(routes[id].path[index][0],routes[id].path[index][1]))
		ghosts.pending_encounter = resolved.encounter.duplicate(true)
		if not ghosts.pending_encounter.is_empty():
			party.select(ghosts.pending_encounter.hero)
			trade.inventory = party.active().inventory
		_reveal_from(hero_cell)
	var travelled := {}
	for id in party.heroes:
		var hero = party.heroes[id]
		travelled[id] = hero.unlocked and hero.movement_remaining < int(hero.definition.movement_max) + int(equipment.bonuses(id).world_movement)
	day += 1
	party.end_day()
	for id in party.heroes:
		party.heroes[id].movement_remaining += int(equipment.bonuses(id).world_movement)
	if map_id == "province_160x120_v1":
		_use_supplies(travelled)
	economy.advance_day(self)
	if not ghosts.pending_encounter.is_empty() and army.is_empty():
		encounters[ghosts.pending_encounter.knight] = {"outcome":"defeat","day":day}
		_retreat_from_ghost()
		turn_notice = "Sin escolta, el héroe cede el paso y pierde su movimiento de hoy."

## Optional supplies (master spec 12): a travelling hero eats bread and drinks water or
## loses health; resting heals; bandages treat; horse feed adds two points; below half
## health the hero moves a quarter less; lamp oil lets the hero see two cells farther and
## a flask burns per day of travel; a booked room at the inn heals 30 on a day of rest.
func _use_supplies(travelled: Dictionary) -> void:
	var notes: PackedStringArray = []
	for id: String in party.heroes:
		var hero = party.heroes[id]
		if not hero.unlocked:
			continue
		var name: String = str(hero.definition.short_name)
		var ceiling: int = int(hero.definition.movement_max) + int(equipment.catalog.effects.world_movement.cap)
		if travelled.get(id, false):
			for item in ["bread", "water"]:
				if int(hero.inventory.get(item, 0)) > 0:
					hero.inventory[item] -= 1
				else:
					hero.health = maxi(30, hero.health - 5)
					notes.append("%s viaja sin %s y pierde salud." % [name, "pan" if item == "bread" else "agua"])
			if int(hero.inventory.get("lamp_oil", 0)) > 0:
				hero.inventory.lamp_oil -= 1
				if hero.inventory.lamp_oil == 0:
					notes.append("%s se queda sin aceite para la lámpara." % name)
			if int(hero.inventory.get("horse_feed", 0)) > 0:
				hero.inventory.horse_feed -= 1
				hero.movement_remaining = mini(ceiling, hero.movement_remaining + 2)
		elif str(location_at(hero.cell).get("id", "")) == "LOC11" and int(hero.inventory.get("room", 0)) > 0:
			# A booked night at the roadside inn rests far better than the open road.
			hero.inventory.room -= 1
			hero.health = mini(100, hero.health + 30)
			notes.append("%s duerme en una habitación de la venta y recupera fuerzas." % name)
		else:
			hero.health = mini(100, hero.health + 5)
		if hero.health <= 70 and int(hero.inventory.get("medicine", 0)) > 0:
			hero.inventory.medicine -= 1
			hero.health = mini(100, hero.health + 25)
			notes.append("%s usa una venda." % name)
		if hero.health < 50:
			hero.movement_remaining = maxi(1, hero.movement_remaining - int(hero.definition.movement_max) / 4)
			notes.append("%s está débil y avanza menos." % name)
	if not notes.is_empty():
		turn_notice = (turn_notice + " " if not turn_notice.is_empty() else "") + " ".join(notes)

func begin_encounter(id: String) -> bool:
	var is_ghost: bool = ghosts.definitions.has(id)
	var forced: bool = not ghosts.pending_encounter.is_empty() and ghosts.pending_encounter.knight == id
	if ghosts.plan != null or (not ghosts.pending_encounter.is_empty() and not forced):
		return false
	if active_battle != null or army.is_empty() or (movement_remaining < 2 and not forced) or not economy.pending.is_empty() or not trade.pending.is_empty():
		return false
	if side_cases.battles.has(id) and not side_cases.can_battle(self,id):
		return false
	var model := StackBattle.new()
	var encounter := encounter_definition(id)
	if encounter.is_empty():
		return false
	if is_ghost:
		if not ghosts.actors[id].active or ghosts.actors[id].return_day > day or hero_cell.distance_squared_to(Vector2i(encounter.position[0],encounter.position[1])) > 4:
			return false
	elif encounter.has("location_id"):
		if location_at(hero_cell).get("id", "") != encounter.location_id:
			return false
	elif hero_cell != Vector2i(encounter.position[0],encounter.position[1]):
		return false
	if (not str(encounter.requires).is_empty() and not evidence.has_evidence(encounter.requires)) or (not is_ghost and encounters.get(id, {}).get("outcome", "") == "victory"):
		return false
	model.data["opening"] = encounter
	if not model.start(army, encounter.enemies, day * 1009 + hero_cell.x * 31 + hero_cell.y, equipment.bonuses(party.active_id),encounter.get("script",{})):
		return false
	active_battle = model
	active_encounter = id
	if not forced:
		movement_remaining -= 2
	return true

func settle_encounter() -> bool:
	if active_battle == null or active_battle.outcome.is_empty():
		return false
	var result: String = active_battle.outcome
	army = active_battle.surviving_army()
	if result == "victory":
		var reward: Dictionary = encounter_definition(active_encounter).reward
		for resource in reward:
			resources[resource] += int(reward[resource])
	elif result in ["defeat", "retreated"]:
		movement_remaining = 0
	encounters[active_encounter] = {"outcome": result, "day": day}
	if ghosts.definitions.has(active_encounter):
		if result == "victory":
			ghosts.defeat(self,active_encounter)
			ghosts.pending_encounter.clear()
		elif not ghosts.pending_encounter.is_empty():
			_retreat_from_ghost()
	active_battle = null
	active_encounter = ""
	return true

func select_hero(id: String) -> bool:
	if active_battle != null or not ghosts.pending_encounter.is_empty() or not trade.pending.is_empty() or not economy.pending.is_empty() or not party.select(id):
		return false
	trade.inventory = party.active().inventory
	_reveal_from(hero_cell)
	return true

func gate_at(cell: Vector2i) -> Dictionary:
	for gate: Dictionary in map_data.get("gates", []):
		if cell == Vector2i(gate.position[0], gate.position[1]):
			var result := gate.duplicate()
			result["closed"] = not evidence.has_evidence(gate.requires)
			return result
	return {}

func _sync_gates() -> void:
	for gate: Dictionary in map_data.get("gates", []):
		var cell := Vector2i(gate.position[0], gate.position[1])
		var closed := not evidence.has_evidence(gate.requires)
		grid.set_point_solid(cell, closed)
		if known_grid.is_in_boundsv(cell):
			known_grid.set_point_solid(cell, closed or fog_at(cell) == Fog.UNKNOWN)

func region_at(cell: Vector2i) -> String:
	for region: Dictionary in map_data.get("regions", []):
		var b: Array = region.bounds
		if Rect2i(b[0], b[1], b[2], b[3]).has_point(cell):
			return region.name
	return ""
func resource_at(cell: Vector2i) -> Dictionary:
	if fog_at(cell) == Fog.UNKNOWN:
		return {}
	for entry: Dictionary in map_data.get("resource_sites",[]):
		if cell == Vector2i(entry.position[0],entry.position[1]):
			return entry
	return economy.treasure_at(self, cell)

func encounter_definition(id: String) -> Dictionary:
	if map_id == "province_160x120_v1" and ghosts.definitions.has(id):
		return ghosts.encounter_definition(id)
	if map_id == "province_160x120_v1" and side_cases.battles.has(id):
		return side_cases.encounter_definition(id)
	if id == "opening_road":
		return StackBattle.new().data.opening.duplicate(true)
	if map_id == "province_160x120_v1" and id.begins_with(economy.RAID_PREFIX):
		return economy.raid_definition(self, id)
	var cache: Dictionary = economy.treasure(self, id)
	if not cache.is_empty():
		return {} if not cache.guarded else {"id": id, "name": "Guardianes: " + str(cache.name),
			"position": cache.position.duplicate(), "enemies": cache.guards.duplicate(true), "requires": "", "reward": {}}
	var entry: Dictionary = economy.site(self,id)
	if entry.is_empty() or not entry.guarded:
		return {}
	return {"id":id,"name":"Guardianes de la mina de " + str(economy.catalog.resource_names[entry.resource]),
		"position":entry.position.duplicate(),"enemies":entry.get("guards",economy.catalog.mine_guards.get(entry.resource,[])).duplicate(true),
		"requires":"","reward":{}}
func _retreat_from_ghost() -> void:
	var preferred: Array = ghosts.pending_encounter.get("hero_previous",[hero_cell.x,hero_cell.y])
	var frontier: Array[Vector2i] = [Vector2i(preferred[0],preferred[1]),hero_cell]
	var visited := {}
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_front()
		if visited.has(cell) or terrain_cost(cell) == 0 or fog_at(cell) == Fog.UNKNOWN or gate_at(cell).get("closed",false):
			continue
		visited[cell] = true
		var occupied := false
		for actor in ghosts.actors.values():
			occupied = occupied or (actor.active and actor.return_day <= day and cell == Vector2i(actor.cell[0],actor.cell[1]))
		if not occupied:
			hero_cell = cell
			break
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			frontier.append(cell+offset)
	movement_remaining = 0
	ghosts.pending_encounter.clear()
	_reveal_from(hero_cell)
