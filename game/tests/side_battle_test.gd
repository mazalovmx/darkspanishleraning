extends "res://tests/stack_battle_test.gd"
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/side_investigations.json"))
	var battle := Battle.new()
	for encounter: Dictionary in catalog.battles:
		var enemies: Array = []
		for stack: Dictionary in encounter.enemy_stacks:
			enemies.append({"type":stack.unit,"count":int(stack.count)})
		check(battle.start([{"type":"archers","count":1000}],enemies,17),"Authored encounter armies start: " + str(encounter.id))
		check(battle.stacks.size() == enemies.size()+1,"All authored stacks preserved")
		check(battle.act("retreat") and battle.surviving_army()[0].count == 1000,"Retreat preserves troops before enemy action")
	check(catalog.battles.size() == 108,"All 108 authored encounters checked")
	battle.start([{"type":"hired_blade","count":20}],[{"type":"enforcer","count":100}],5)
	battle.stacks[1].defending = true
	battle.stacks[1].brace_active = true
	var defended: int = battle._damage(0,1,false)
	check(battle._damage(0,1,false,true) > defended,"Feint bypasses defensive reductions")
	check(battle.act("ability",1) and battle.stacks[0].ability_used,"Feint uses one battle charge")
	check(not battle.act("ability",1),"Feint cannot be reused")
	battle.start([{"type":"watchman","count":100}],[{"type":"enforcer","count":100}],5,{"army_initiative":5})
	var normal: int = battle._damage(1,0,false)
	battle._execute(0,"ability",1)
	check(battle.stacks[0].brace_active and battle._damage(1,0,false) == roundi(normal*0.5),"Temporary brace halves incoming damage")
	var defense: int = battle.stacks[0].stats.defense
	battle._advance()
	battle._run_enemies()
	check(not battle.stacks[0].brace_active and battle.stacks[0].stats.defense == defense,"Brace expires on next turn without permanent defense")
	battle.start([{"type":"archers","count":100}],[{"type":"crossbow_guard","count":100}],5)
	battle.act("defend")
	check(battle.stacks[1].ability_used,"Crossbow guard uses aimed shot")
	battle.start([{"type":"archers","count":100}],[{"type":"hired_blade","count":100}],5)
	battle.act("defend")
	check(battle.stacks[1].ability_used,"Hired blade uses feint against defending target")
	var arena = load("res://src/combat/stack_arena.tscn").instantiate()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(arena)
	await process_frame
	check(arena.launch([{"type":"archers","count":10}],[{"type":"watchman","count":3},{"type":"hired_blade","count":2}],2,"Disputa del archivo"),"Expanded units render in battle scene")
	check(arena.enemies.get_child_count() == 2,"Separate enemy stacks rendered")
	layer.queue_free()
	await process_frame
	print("Side battle checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
