extends SceneTree
const World = preload("res://src/world/world_state.gd")
const Turn = preload("res://src/world/simultaneous_turn.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool,message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func fixture() -> RefCounted:
	var world := World.new()
	world.party.heroes.smuggler.cell = Vector2i(2,8)
	world.party.heroes.survivor.cell = Vector2i(2,12)
	world._reveal_from(world.hero_cell)
	return world
func order(path: Array,kind := "move") -> Dictionary:
	return {"kind":kind,"path":path,"target":""}
func run() -> void:
	var world = fixture()
	var plan := Turn.new()
	var ai := {"NK01":order([[6,10],[5,10],[4,10]])}
	check(plan.freeze(world,{"NK01":[6,10]},ai),"Freeze shared start snapshot")
	ai.NK01.path[1] = [6,9]
	check(plan.orders.NK01.path[1] == [5,10],"Caller cannot mutate frozen AI order")
	check(plan.plan_move(world,"inquisitor",Vector2i(4,10)),"Hero queues known affordable route")
	check(world.hero_cell == Vector2i(2,10) and world.movement_remaining == 18 and world.day == 1,"Planning does not move actors or advance time")
	check(not plan.freeze(world,{"NK01":[6,10]},{"NK01":order([[6,10]],"guard")}),"Cannot refreeze AI after player plans")
	var saved := plan.snapshot()
	var result := plan.resolve(world)
	check(result.ok and result.encounter.kind == "destination" and result.encounter.tick == 2,"Simultaneous destination encounter")
	check(result.positions.inquisitor == [4,10] and result.positions.NK01 == [4,10],"Both reach shared encounter cell")
	check(result.spent.inquisitor == 2 and result.spent.NK01 == 2,"Each actor pays its own movement")
	check(plan.resolve(world) == result and plan.snapshot() == saved,"Repeated resolution is deterministic and pure")
	check(world.hero_cell == Vector2i(2,10),"Resolving draft does not mutate world")
	var restored := Turn.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(saved)),world) and restored.resolve(world) == result,"Serialized plan cannot reroll AI or collisions")
	for fault in ["budget","teleport","hidden","unknown_actor","duplicate_order","wrong_day","boolean"]:
		var bad := saved.duplicate(true)
		match fault:
			"budget": bad.actors.inquisitor.movement = 24
			"teleport": bad.orders.NK01.path = [[6,10],[4,10]]
			"hidden": bad.known["19,19"] = true
			"unknown_actor": bad.actors.NK99 = bad.actors.NK01
			"duplicate_order": bad.orders.NK99 = bad.orders.NK01
			"wrong_day": bad.day = 2
			"boolean": bad.actors.NK01.movement = true
		check(not restored.restore(bad,world) and restored.snapshot() == saved,"Bad plan rejected atomically: " + fault)
	check(not plan.plan_move(world,"NK01",Vector2i(5,10)),"Player cannot replace knight order")
	check(not plan.plan_move(world,"inquisitor",Vector2i(19,19)),"Hidden destination cannot be queued")
	check(plan.cancel_move("inquisitor") and plan.orders.inquisitor.kind == "guard","Player can replace own route with guard")
	plan = Turn.new()
	check(plan.freeze(world,{"NK01":[3,10]},{"NK01":order([[3,10],[2,10]])}),"Opposite-edge fixture")
	plan.plan_move(world,"inquisitor",Vector2i(3,10))
	result = plan.resolve(world)
	check(result.encounter.kind == "edge","Opposite edges cannot phase through")
	check(result.positions.inquisitor == [2,10] and result.positions.NK01 == [3,10],"Edge encounter retains both sides of edge")
	plan = Turn.new()
	check(plan.freeze(world,{"NK02":[3,9],"NK01":[4,10]},
		{"NK02":order([[3,9],[3,10]]),"NK01":order([[4,10],[3,10]])}),"Multiple knight collision fixture")
	plan.plan_move(world,"inquisitor",Vector2i(3,10))
	result = plan.resolve(world)
	check(result.encounter.knight == "NK01" and result.stopped.has("NK02"),"Higher fixed initiative gets sole encounter; other knight guards")
	check(result.positions.NK02 == [3,9],"Nonselected knight spends no second order")
	# Moving into a stationary hero also creates an encounter.
	plan = Turn.new()
	plan.freeze(world,{"NK01":[3,10]},{"NK01":order([[3,10],[2,10]])})
	result = plan.resolve(world)
	check(result.encounter.hero == "inquisitor" and result.positions.inquisitor == [2,10],"Guarding hero cannot be phased through")
	# A later-arriving actor cannot pass through the participants of an earlier encounter.
	world.party.heroes.smuggler.cell = Vector2i(5,10)
	world._reveal_from(world.hero_cell)
	plan = Turn.new()
	plan.freeze(world,{"NK01":[3,10]},{"NK01":order([[3,10],[2,10]])})
	plan.plan_move(world,"inquisitor",Vector2i(3,10))
	plan.plan_move(world,"smuggler",Vector2i(2,10))
	result = plan.resolve(world)
	check(result.stopped.has("smuggler") and result.positions.smuggler == [4,10],"Later traveller stops before occupied collision")
	world = fixture()
	var old_terrain: String = world.terrain[10][3]
	world.terrain[10][3] = "forest"
	world._reveal_from(world.hero_cell)
	plan = Turn.new()
	plan.freeze(world,{"NK01":[4,10]},{"NK01":order([[4,10],[3,10]])})
	plan.plan_move(world,"inquisitor",Vector2i(3,10))
	result = plan.resolve(world)
	check(result.encounter.tick == 2 and result.spent.inquisitor == 2,"Terrain cost delays edge traversal in ticks")
	world.terrain[10][3] = old_terrain
	world._reveal_from(world.hero_cell)
	var too_long: Array = [[6,10]]
	for i in 20:
		too_long.append([5 if i % 2 == 0 else 6,10])
	plan = Turn.new()
	check(not plan.freeze(world,{"NK01":[6,10]},{"NK01":order(too_long)}),"Knight cannot exceed own allowance")
	check(not plan.freeze(world,{"NK01":[6,10]},{"NK01":false}),"Malformed AI order fails without mutation")
	plan = Turn.new()
	plan.freeze(world,{"NK01":[6,10]},{"NK01":order([[6,10]],"guard")})
	plan.plan_move(world,"inquisitor",Vector2i(3,10))
	world.terrain[10][3] = "water"
	check(not plan.resolve(world).ok and world.hero_cell == Vector2i(2,10),"Revalidation cancels changed impassable route atomically")
	print("Simultaneous turn checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
