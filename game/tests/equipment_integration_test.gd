extends "res://tests/equipment_state_test.gd"
const Battle = preload("res://src/combat/stack_battle.gd")
func run() -> void:
	var battle := Battle.new()
	var army := [{"type":"archers","count":10}]
	var enemies := [{"type":"bandits","count":1000}]
	check(battle.start(army,enemies,23,{"army_hp_percent":50,"army_attack":4,"army_defense":3,"army_initiative":2}),"Bonus battle starts")
	check(battle.count_at(0) == 10 and battle.stacks[0].unit_hp == 11,"Bonus HP preserves troop count")
	check(battle.stacks[0].stats.attack == int(battle.data.units.archers.attack)+4,"Attack applies to allies")
	check(battle.stacks[0].stats.defense == int(battle.data.units.archers.defense)+3,"Defense applies to allies")
	check(battle.stacks[1].unit_hp == int(battle.data.units.bandits.hp),"Enemy health unaffected")
	battle.stacks[0].stats.health = 12
	check(battle.count_at(0) == 2,"Wounded enhanced stack uses enhanced per-unit HP")
	var health: int = battle.stacks[0].stats.health
	for invalid in [{"army_attack":21},{"army_luck":true},{"army_morale":-1},{"army_hp_percent":1.5},{"invented":2}]:
		check(not battle.start(army,enemies,1,invalid) and battle.stacks[0].stats.health == health,"Invalid bonus rejected atomically")
	var plain := Battle.new()
	plain.start(army,enemies,23)
	battle.start(army,enemies,23,{"ranged_damage_percent":50})
	check(battle._damage(0,1,false) == roundi(plain._damage(0,1,false)*1.5),"Ranged bonus changes damage")
	var lucky := false
	var spirited := false
	for seed_value in range(1,101):
		battle.start(army,enemies,seed_value,{"army_luck":3,"army_morale":3})
		var repeated := Battle.new()
		repeated.start(army,enemies,seed_value,{"army_luck":3,"army_morale":3})
		battle.act("attack",1)
		repeated.act("attack",1)
		check(battle.log == repeated.log and battle.queue == repeated.queue,"Luck and morale reproduce with seed")
		for line: String in battle.log:
			lucky = lucky or line.contains("fortuna")
			spirited = spirited or line.contains("moral")
		if battle.stacks[0].morale_round == battle.round_number:
			var current_round: int = battle.round_number
			battle.act("attack",1)
			check(battle.round_number > current_round or battle.current() != 0,"Morale cannot chain extra turns")
	check(lucky and spirited,"Seed sample exercises luck and morale")
	var state := World.new()
	var gear = state.equipment
	var boots: String = gear.grant("EQ043","inquisitor")
	state.movement_remaining = 4
	check(gear.equip(state,boots,"feet") and state.movement_remaining == 4,"Equipping does not refill movement")
	state.end_turn()
	check(state.movement_remaining == 20,"Next day includes equipped movement bonus")
	var saved := Save.snapshot(state)
	var restored := Save.decode(saved)
	check(restored.has("state"),"Save v9 accepts legitimate enhanced movement")
	if restored.has("state"):
		check(restored.state.equipment.snapshot() == gear.snapshot() and restored.state.movement_remaining == 20,"Equipment and movement round trip")
	var bad := saved.duplicate(true)
	bad.strategy.equipment.instances[boots].slot = ""
	check(not Save.decode(bad).has("state"),"Movement without its worn item rejected")
	check(gear.unequip(state,boots) and state.movement_remaining == 18,"Removing boots clamps remaining movement")
	check(gear.equip(state,boots,"feet") and state.movement_remaining == 18,"Re-equipping cannot restore removed movement")
	var old := Save.snapshot(World.new())
	old.version = 8
	old.erase("npc_memory")
	old.strategy.erase("equipment")
	old.strategy.erase("side_cases")
	old.strategy.erase("ghosts")
	restored = Save.decode(old)
	check(restored.has("state") and restored.state.equipment.instances.is_empty(),"V8 migrates with empty equipment")
	check(gear.unequip(state,boots),"Free feet slot for soul component")
	learn(state)
	for part: Dictionary in gear.sets.SA01.components:
		var id: String = gear.grant(part.item_id,"inquisitor")
		check(gear.equip(state,id,part.slot),"Equip soul components for save")
	ritual(gear,state,"SA01")
	check(gear.assemble(state,"SA01"),"Assemble after actual language stages")
	restored = Save.decode(Save.snapshot(state))
	check(restored.has("state"),"Soul proof and assembly survive full world decode")
	if restored.has("state"):
		check(restored.state.equipment.snapshot() == gear.snapshot(),"Consent and component identities retained")
	complete_opening(state)
	visit(state,"LOC11")
	state.end_turn()
	check(state.begin_encounter("opening_road"),"World battle starts with equipped gear")
	if state.active_battle != null:
		var expected: int = int(state.active_battle.data.units.militia.defense) + int(gear.bonuses("inquisitor").army_defense)
		check(state.active_battle.stacks[0].stats.defense == expected,"World passes actual owner equipment into battle")
		check(not gear.unequip(state,boots),"Battle locks equipment")
		state.active_battle.act("retreat")
		check(state.settle_encounter(),"Enhanced army settles after retreat")
	print("Equipment integration checks: %d, failures: %d" % [checks,failures])
	quit(1 if failures else 0)
