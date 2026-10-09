extends SceneTree
const Battle = preload("res://src/combat/stack_battle.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	run.call_deferred()
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1280, 720)
	var battle := Battle.new()
	for bad in [[], [{"type":"invented","count":1}], [{"type":"militia","count":0}], [{"type":"militia","count":1.5}], [{"type":"militia","count":true}]]:
		check(not battle.start(bad, [{"type":"bandits","count":1}]), "Invalid army rejected")
	var seven: Array = []
	for i in 7:
		seven.append({"type":"militia","count":1})
	check(battle.start(seven, [{"type":"bandits","count":1}]), "Seven stack slots supported")
	seven.append({"type":"militia","count":1})
	check(not battle.start(seven, [{"type":"bandits","count":1}]), "Eighth stack rejected")
	check(battle.start(battle.data.starting_army, battle.data.opening.enemies, 123), "Opening armies start")
	check(battle.current() == 1, "Initiative selects archers first")
	var hp: int = battle.stacks[2].stats.health
	check(not battle.act("attack", 0), "Friendly fire rejected")
	check(not battle.act("attack", 99), "Unknown target rejected")
	check(not battle.act("invented", 2), "Unknown action rejected")
	check(battle.stacks[2].stats.health == hp and battle.current() == 1, "Invalid commands are atomic")
	check(battle.act("ability", 2), "Ranged ability acts")
	check(battle.stacks[1].ability_used, "Ability use tracked")
	check(battle.stacks[1].stats.health == 28, "Ranged hit avoids retaliation")
	if battle.outcome.is_empty():
		check(battle.act("ability", 2), "Militia brace acts")
		check(battle.stacks[0].stats.defense == 7, "Brace uses retained stats")
	var steps := 0
	while battle.outcome.is_empty() and steps < 100:
		var target := -1
		for i in battle.stacks.size():
			if battle.stacks[i].side == 1 and battle.count_at(i) > 0:
				target = i
				break
		check(battle.act("attack", target), "Player action and enemy turn progress")
		steps += 1
	check(battle.outcome == "victory", "Opening battle winnable")
	check(not battle.act("attack", 2), "Finished combat rejects commands")
	for stack in battle.surviving_army():
		check(stack.count > 0, "Survivor army contains living units only")
	var repeat := Battle.new()
	var first := Battle.new()
	first.start([{"type":"militia","count":10}], [{"type":"bandits","count":10}], 45)
	repeat.start([{"type":"militia","count":10}], [{"type":"bandits","count":10}], 45)
	first.act("attack", 1)
	repeat.act("attack", 1)
	check(first.log == repeat.log, "Seed reproduces combat")
	first.start([{"type":"militia","count":10}], [{"type":"bandits","count":30}], 45)
	first.stacks[0].cell = Vector2i(5, 3)
	first.stacks[1].cell = Vector2i(6, 3)
	first._execute(0, "attack", 1)
	check(first.stacks[1].retaliated, "Melee target marks its retaliation")
	var log_size: int = first.log.size()
	first._execute(0, "attack", 1)
	check(first.log.size() == log_size + 1, "Same target cannot retaliate twice in a round")
	first.start([{"type":"militia","count":5}], [{"type":"bandits","count":10}], 2)
	check(first.act("retreat") and first.outcome == "retreated", "Retreat works before attack")
	check(first.surviving_army()[0].count == 5, "Retreat keeps survivors")
	first.start([{"type":"militia","count":1}], [{"type":"bandits","count":30}], 2)
	for turn in 6:
		if first.outcome.is_empty():
			first.act("defend")
	check(first.outcome == "defeat", "Defeat produces terminal outcome")
	# Hex field (master spec 13): positions, speed, rocks, moving, shooting, flying.
	var field := Battle.new()
	field.start([{"type":"militia","count":10}, {"type":"archers","count":10}], [{"type":"bandits","count":10}], 9)
	check(field.stacks[0].cell.x == 0 and field.stacks[1].cell.x == 0 and field.stacks[2].cell.x == Battle.COLUMNS - 1, "Armies start in the outer columns")
	check(not field.obstacles.is_empty() and field.obstacles.size() <= 4, "Rocks are placed on the field")
	check(Battle.distance(Vector2i(0, 0), Vector2i(3, 0)) == 3 and Battle.distance(Vector2i(0, 0), Vector2i(0, 2)) == 2 and Battle.distance(Vector2i(1, 1), Vector2i(1, 2)) == 1, "Hex distance on offset rows")
	for cell: Vector2i in field.reachable(1):
		check(Battle.distance(field.stacks[1].cell, cell) <= field.stacks[1].speed and cell not in field.obstacles, "Reachable within speed and off rocks")
	check(field.current() == 1, "Archers act first")
	var target_hp: int = field.stacks[2].stats.health
	check(field.act("attack", 2) and field.stacks[2].stats.health < target_hp and field.stacks[1].cell.x == 0, "Archers shoot across the field without moving")
	check(field.events.any(func(event: Dictionary): return event.kind == "strike" and event.shot), "Shot recorded for the battle screen")
	check(field.current() == 0, "Militia acts next")
	check(not field.act("move", -1, Vector2i(9, 0)), "Move beyond speed rejected")
	var step: Vector2i = Vector2i(2, field.stacks[0].cell.y)
	if step in field.obstacles or not field.reachable(0).has(step):
		step = field.reachable(0).keys().filter(func(cell: Vector2i): return cell.x > 0)[0]
	check(field.act("move", -1, step) and field.stacks[0].cell == step, "Move command walks to a reachable hex")
	check(field.events[0].kind == "move" and field.events[0].stack == 0, "Walk recorded for the battle screen")
	var melee := Battle.new()
	melee.start([{"type":"militia","count":10}], [{"type":"enforcer","count":10}], 4)
	var before: int = melee.stacks[1].stats.health
	check(melee.act("attack", 1) and melee.stacks[1].stats.health == before and melee.stacks[0].cell.x > 0, "Out of reach: the stack advances instead of striking")
	melee.stacks[0].cell = Vector2i(5, 3)
	melee.stacks[1].cell = Vector2i(7, 3)
	melee.obstacles.clear()
	while melee.current() != 0 and melee.outcome.is_empty():
		melee.act("defend")
	before = melee.stacks[1].stats.health
	check(melee.act("attack", 1, Vector2i(6, 3)) and melee.stacks[0].cell == Vector2i(6, 3) and melee.stacks[1].stats.health < before, "Melee walks next to the target and strikes from the chosen hex")
	var blocked := Battle.new()
	blocked.start([{"type":"archers","count":10}], [{"type":"bandits","count":10}, {"type":"bandits","count":10}], 4)
	blocked.stacks[0].cell = Vector2i(5, 3)
	blocked.stacks[1].cell = Vector2i(6, 3)
	blocked.stacks[2].cell = Vector2i(10, 0)
	var far: int = blocked.stacks[2].stats.health
	check(not blocked.can_strike(0, 2) and blocked.can_strike(0, 1), "An adjacent enemy stops shooting")
	check(blocked.act("attack", 2) and blocked.stacks[2].stats.health == far and blocked.stacks[1].stats.health < blocked.stacks[1].stats.max_health, "A blocked shooter fights the adjacent enemy")
	var flyer := Battle.new()
	flyer.start([{"type":"ghost_guard","count":5}], [{"type":"bandits","count":5}], 4)
	flyer.stacks[0].cell = Vector2i(0, 3)
	flyer.obstacles = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(0, 2), Vector2i(0, 4), Vector2i(1, 4)]
	check(flyer.reachable(0).has(Vector2i(4, 3)), "Flyers ignore rocks between hexes")
	# Wait: once per round, the stack acts after everyone else.
	var waiting := Battle.new()
	waiting.start([{"type":"archers","count":5}, {"type":"militia","count":5}], [{"type":"enforcer","count":5}], 4)
	check(waiting.current() == 0, "Archers act first")
	check(waiting.act("wait") and waiting.current() == 1 and waiting.stacks[0].waited, "Waiting passes the turn to the next stack")
	check(waiting.queue.back() == 0, "The waiting stack moves to the end of the round")
	waiting.act("defend")
	check(waiting.current() == 0 and not waiting.act("wait"), "A stack waits only once per round")
	waiting.act("defend")
	check(waiting.round_number == 2 and not waiting.stacks[0].waited, "Waiting resets each round")
	# Range: shots beyond FULL_RANGE hexes deal half damage.
	var close_shot := Battle.new()
	var long_shot := Battle.new()
	for model in [close_shot, long_shot]:
		model.start([{"type":"archers","count":20}], [{"type":"enforcer","count":50}], 8)
		model.obstacles.clear()
	close_shot.stacks[1].cell = Vector2i(Battle.FULL_RANGE, close_shot.stacks[0].cell.y)
	long_shot.stacks[1].cell = Vector2i(Battle.FULL_RANGE + 1, long_shot.stacks[0].cell.y)
	check(not close_shot.far_shot(0, 1) and long_shot.far_shot(0, 1), "Range threshold at FULL_RANGE hexes")
	var near_hp: int = close_shot.stacks[1].stats.health
	var far_hp: int = long_shot.stacks[1].stats.health
	close_shot.act("attack", 1)
	long_shot.act("attack", 1)
	var near_damage: int = near_hp - close_shot.stacks[1].stats.health
	var far_damage: int = far_hp - long_shot.stacks[1].stats.health
	check(absi(far_damage * 2 - near_damage) <= 1, "Far shot deals half damage (same seed, same roll)")
	first.start([{"type":"archers","count":4}], [{"type":"bandits","count":50}], 2)
	first.stacks[0].stats.health = 8
	check(first.count_at(0) == 2, "Partial damage converts aggregate HP to stack count")
	first.stacks[0].stats.health = 0
	check(first.count_at(0) == 0, "Dead stack count is zero")
	var arena = load("res://src/combat/stack_arena.tscn").instantiate()
	var layer := CanvasLayer.new()
	root.add_child(layer)
	layer.add_child(arena)
	await process_frame
	check(arena.launch(battle.data.starting_army, battle.data.opening.enemies, 123, "Salteadores del camino"), "Reused arena launches")
	await process_frame
	check(Rect2(Vector2.ZERO, root.size).encloses(arena.attack_button.get_global_rect()), "Battle controls fit viewport")
	check(arena.enemies.get_child_count() == 1 and arena.allies.get_child_count() == 2, "Stack cards rendered")
	check(arena.selected_target == 2, "Enemy target preselected")
	arena.ability_button.pressed.emit()
	check(arena.battle.stacks[1].ability_used, "UI ability wired")
	var emitted: Array = []
	arena.finished.connect(func(result: String, army: Array): emitted.append([result, army]))
	arena.retreat_button.pressed.emit()
	check(arena.finish_button.visible, "Return becomes available after retreat")
	arena.finish_button.pressed.emit()
	arena.finish_button.pressed.emit()
	check(emitted.size() == 1 and emitted[0][0] == "retreated", "Result emitted exactly once")
	# Hovering an enemy in reach lights the hex the acting melee stack would strike from.
	arena.launch([{"type":"militia","count":10}], [{"type":"enforcer","count":10}], 4, "Prueba")
	arena.battle.obstacles.clear()
	arena.battle.stacks[0].cell = Vector2i(3, 3)
	arena.battle.stacks[1].cell = Vector2i(6, 3)
	arena._layout()
	arena._on_hover(Vector2i(6, 3))
	check(Battle.distance(arena.field.strike_from, Vector2i(6, 3)) == 1 and arena.battle.reachable(0).has(arena.field.strike_from), "Hover shows the hex to strike from")
	arena._on_hover(Vector2i(0, 0))
	check(arena.field.strike_from == Battle.NOWHERE, "No strike hex away from enemies")
	arena.launch(battle.data.starting_army, battle.data.opening.enemies, 123, "Salteadores del camino")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://stack-battle-preview.png")
	layer.queue_free()
	await process_frame
	# Forecast (docs/UI_PLAN.md, stage 5): what is promised before the order is what happens.
	for seed_value in [1, 7, 123, 999]:
		var trial := Battle.new()
		trial.start(trial.data.starting_army, trial.data.opening.enemies, seed_value)
		for turn in 12:
			var actor: int = trial.current()
			if actor < 0 or not trial.outcome.is_empty() or trial.stacks[actor].side != 0:
				break
			var enemy := -1
			for i in trial.stacks.size():
				if trial.stacks[i].side == 1 and trial.count_at(i) > 0:
					enemy = i
					break
			if enemy < 0:
				break
			var healths: Array = trial.stacks.map(func(stack: Dictionary) -> int: return stack.stats.health)
			var promise: Dictionary = trial.forecast(actor, enemy)
			check(trial.stacks.map(func(stack: Dictionary) -> int: return stack.stats.health) == healths and trial.current() == actor, "A forecast changes nothing")
			check(not promise.is_empty() and promise.low <= promise.high if promise.get("reach", false) else promise.has("reach"), "A forecast always answers for a living enemy")
			var count_before: int = trial.count_at(enemy)
			check(trial.act("attack", enemy), "The forecast order is accepted")
			var blow: Dictionary = {}
			for event: Dictionary in trial.events:
				if event.kind == "strike" and event.actor == actor and blow.is_empty():
					blow = event
			if not promise.reach:
				check(blow.is_empty(), "Out of reach means no blow this turn")
				continue
			var top: int = promise.high * (2 if promise.lucky else 1)
			check(not blow.is_empty() and blow.target == promise.target and blow.amount >= promise.low and blow.amount <= top, "The blow lands inside the promised range: %s vs %s" % [blow, promise])
			if not promise.lucky:
				var lost: int = count_before - (trial.count_at(promise.target) if promise.target == enemy else count_before)
				check(promise.target != enemy or (lost >= promise.losses_low and lost <= promise.losses_high) or promise.answer > 0, "Losses stay inside the promised range unless the fight went on")
			var answered := false
			for event: Dictionary in trial.events:
				answered = answered or (event.kind == "strike" and event.actor == promise.target and event.target == actor)
			check(not answered or promise.answer > 0, "No answer comes that was not announced")
	check(battle.forecast(-1, 0).is_empty() and battle.forecast(0, 0).is_empty() and battle.forecast(0, 99).is_empty(), "No forecast for nobody, for an ally or for a missing stack")
	print("Stack battle checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
