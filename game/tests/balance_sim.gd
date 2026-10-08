extends SceneTree
## Balance probe, not a test suite: auto-battles (attack the weakest enemy stack) of
## three reference armies against every guarded encounter, 20 seeds each.
## Run: godot --headless --path game --script res://tests/balance_sim.gd
const StackBattle = preload("res://src/combat/stack_battle.gd")
const World = preload("res://src/world/world_state.gd")
const ARMIES := {
	"start": [{"type": "militia", "count": 8}, {"type": "archers", "count": 4}],
	"mid": [{"type": "militia", "count": 24}, {"type": "archers", "count": 14}, {"type": "veteran_guard", "count": 6}],
	"strong": [{"type": "veteran_guard", "count": 20}, {"type": "archers", "count": 30}, {"type": "relic_sentinel", "count": 6}, {"type": "militia", "count": 30}]}

func fight(army: Array, enemies: Array, seed_value: int, script: Dictionary = {}) -> String:
	var battle := StackBattle.new()
	if not battle.start(army, enemies, seed_value, {}, script):
		return "invalid"
	var guard := 0
	while battle.outcome.is_empty() and guard < 500:
		guard += 1
		var target := -1
		for i in battle.stacks.size():
			if battle.stacks[i].side == 1 and battle.count_at(i) > 0 and (target < 0 or battle.stacks[i].stats.health < battle.stacks[target].stats.health):
				target = i
		if battle.current() < 0 or not battle.act("attack", target):
			break
	return battle.outcome

func _initialize() -> void:
	var world := World.new("province_160x120_v1")
	var encounters := {"opening": StackBattle.new().data.opening.enemies}
	for id: String in world.side_cases.battles:
		encounters[id] = world.side_cases.encounter_definition(id).enemies
	for id: String in world.ghosts.definitions:
		var battle: Dictionary = world.ghosts.definitions[id].battle
		var enemies: Array = []
		for stack: Dictionary in battle.enemy_stacks:
			enemies.append({"type": stack.unit, "count": int(stack.count)})
		encounters[id] = [enemies, battle.script]
	for site: Dictionary in world.map_data.resource_sites:
		if site.guarded:
			encounters["guard_" + site.id] = world.economy.catalog.mine_guards[site.resource]
		encounters["raid_" + site.id] = world.economy.raid_definition(world, "raid_" + site.id).enemies
	for id: String in world.economy.treasures:
		if world.economy.treasures[id].guarded:
			encounters[id] = world.economy.treasures[id].guards
	print("encounter\tstart\tmid\tstrong")
	for id: String in encounters:
		var enemies: Array = encounters[id][0] if encounters[id][0] is Array else encounters[id]
		var script: Dictionary = encounters[id][1] if encounters[id][0] is Array else {}
		var row := [id]
		for name: String in ARMIES:
			var wins := 0
			for seed_value in 20:
				wins += 1 if fight(ARMIES[name], enemies, seed_value + 1, script) == "victory" else 0
			row.append(str(wins * 5) + "%")
		print("\t".join(row))
	quit()
