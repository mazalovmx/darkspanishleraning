extends "res://tests/campaign_test.gd"
## Optional supplies affect play (master spec 12): food and water on the road, bandages,
## horse feed, and weakness below half health.
func run() -> void:
	var state := World.new("province_160x120_v1")
	var hero = state.party.active()
	var full: int = int(hero.definition.movement_max)
	hero.movement_remaining = full - 3
	state.end_turn()
	check(hero.health == 90 and state.turn_notice.contains("sin pan") and state.turn_notice.contains("sin agua"), "Travelling without bread and water costs health")
	hero.inventory.bread = 2
	hero.inventory.water = 2
	hero.movement_remaining = full - 1
	state.end_turn()
	check(hero.health == 90 and hero.inventory.bread == 1 and hero.inventory.water == 1, "Food and water are eaten on the road")
	state.end_turn()
	check(hero.health == 95, "A day without travel heals")
	hero.health = 60
	hero.inventory.medicine = 1
	state.end_turn()
	check(hero.health == 90 and hero.inventory.medicine == 0 and state.turn_notice.contains("venda"), "A bandage treats a wounded hero")
	hero.inventory.horse_feed = 1
	hero.movement_remaining = full - 2
	state.end_turn()
	check(hero.movement_remaining == full + 2 and hero.inventory.horse_feed == 0, "Horse feed adds two points after a day on the road")
	hero.health = 40
	state.end_turn()
	check(hero.movement_remaining == full - full / 4 and state.turn_notice.contains("débil"), "Below half health the hero moves a quarter less")
	check(Save.decode(Save.snapshot(state)).has("state"), "Supplies and health survive a save")
	var prototype := World.new()
	var walker = prototype.party.active()
	walker.movement_remaining = 1
	prototype.end_turn()
	check(walker.health == 100, "The prototype map keeps its old rules")
	print("Supply checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
