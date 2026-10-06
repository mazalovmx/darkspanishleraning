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
	first._execute(0, "attack", 1)
	check(first.stacks[1].retaliated, "Melee target marks its retaliation")
	var log_size: int = first.log.size()
	first._execute(0, "attack", 1)
	check(first.log.size() == log_size + 1, "Same target cannot retaliate twice in a round")
	first.start([{"type":"militia","count":5}], [{"type":"bandits","count":10}], 2)
	check(first.act("retreat") and first.outcome == "retreated", "Retreat works before attack")
	check(first.surviving_army()[0].count == 5, "Retreat keeps survivors")
	first.start([{"type":"militia","count":1}], [{"type":"bandits","count":30}], 2)
	first.act("defend")
	check(first.outcome == "defeat", "Defeat produces terminal outcome")
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
	arena.launch(battle.data.starting_army, battle.data.opening.enemies, 123, "Salteadores del camino")
	if DisplayServer.get_name() != "headless":
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("C:/dev/game/tools/local/stack-battle-preview.png")
	layer.queue_free()
	await process_frame
	print("Stack battle checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
