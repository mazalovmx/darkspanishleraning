extends "res://tests/stack_battle_test.gd"
func run() -> void:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://content/scenario/ghost_knights.json"))
	var expected_targets := [1,2,1,0,1,1,0,1]
	for number in catalog.knights.size():
		var knight: Dictionary = catalog.knights[number]
		var enemies: Array = []
		for stack: Dictionary in knight.battle.enemy_stacks:
			enemies.append({"type":stack.unit,"count":int(stack.count)})
		var army := [{"type":"militia","count":10},{"type":"archers","count":20},{"type":"relic_sentinel","count":5}]
		var battle := Battle.new()
		check(battle.start(army,enemies,71,{"army_initiative":5},knight.battle.script),"Knight script starts: " + str(knight.id))
		check(battle._script_target(3) == expected_targets[number],"Knight selects its authored target policy")
		if knight.id == "NK07":
			battle._strike(2,3)
			check(battle._script_target(3) == 2,"Knight retaliates against actual last attacker")
		var repeated := Battle.new()
		repeated.start(army,enemies,71,{"army_initiative":5},knight.battle.script)
		# Restart after the direct targeting probe before reproducibility checks.
		battle.start(army,enemies,71,{"army_initiative":5},knight.battle.script)
		for turn in 3:
			battle.act("defend")
			repeated.act("defend")
		check(battle.log == repeated.log,"Knight tactics remain seeded and reproducible")
		for i in range(3,battle.stacks.size()):
			if knight.battle.script.first_round == "DEFEND":
				check(battle.stacks[i].defending,"First-round guard is executed")
			elif knight.battle.script.first_round == "ABILITY":
				check(battle.stacks[i].ability_used,"First-round special is executed")
		var turns := 0
		while battle.outcome.is_empty() and battle.round_number < 4 and turns < 100:
			check(battle.act("defend"),"Scripted encounter advances")
			turns += 1
		check(turns < 100,"Script cannot stall the battle")
		var before: int = battle.stacks[0].stats.health
		var bad: Dictionary = knight.battle.script.duplicate(true)
		bad.target = "invented"
		check(not battle.start(army,enemies,1,{},bad) and battle.stacks[0].stats.health == before,"Invalid tactic rejected atomically")
		bad = knight.battle.script.duplicate(true)
		bad.ability_uses = true
		check(not battle.start(army,enemies,1,{},bad),"Boolean cannot forge ability allowance")
		check(battle.start(army,enemies,71) and battle.enemy_script.is_empty(),"Ordinary battle clears previous knight tactic")
	var arena = load("res://src/combat/stack_arena.tscn").instantiate()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(arena)
	await process_frame
	var preview := Battle.new()
	var knight: Dictionary = catalog.knights[0]
	preview.start([{"type":"militia","count":10}],[{"type":"watchman","count":3}],7,{},knight.battle.script)
	arena.present(preview,knight.name)
	check(arena.visible and arena.battle.enemy_script == knight.battle.script,"Battle scene retains knight behavior")
	layer.queue_free()
	await process_frame
	print("Ghost battle checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
