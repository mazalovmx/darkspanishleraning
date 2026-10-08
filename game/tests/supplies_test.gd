extends "res://tests/campaign_test.gd"
## Optional supplies affect play (master spec 12): food and water on the road, bandages,
## horse feed, lamp oil, and weakness below half health.
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
	# Lamp oil: two more cells of sight while carried; a flask burns per day of travel.
	hero.health = 100
	check(state.view_radius(state.party.active_id) == state.VIEW_RADIUS, "Without oil the hero sees the normal radius")
	hero.inventory.lamp_oil = 1
	check(state.view_radius(state.party.active_id) == state.VIEW_RADIUS + state.LAMP_RADIUS, "Lamp oil widens sight")
	state._reveal_from(state.hero_cell)
	var far := state.hero_cell + Vector2i(state.VIEW_RADIUS + 1, 0)
	check(not state.grid.region.has_point(far) or state.fog_at(far) == World.Fog.VISIBLE, "A cell beyond the normal radius is visible with the lamp")
	hero.movement_remaining = full - 2
	state.end_turn()
	check(hero.inventory.lamp_oil == 0 and state.turn_notice.contains("aceite"), "A day on the road burns a flask")
	state._reveal_from(state.hero_cell)
	check(not state.grid.region.has_point(far) or state.fog_at(far) == World.Fog.EXPLORED, "Without oil the far cell fades back to explored")
	check(Save.decode(Save.snapshot(state)).has("state"), "Supplies and health survive a save")
	var prototype := World.new()
	var walker = prototype.party.active()
	walker.movement_remaining = 1
	prototype.end_turn()
	check(walker.health == 100, "The prototype map keeps its old rules")
	print("Supply checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
