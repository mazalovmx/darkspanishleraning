extends SceneTree
## Measurement probe, not a test: walks the mainline by real map paths and counts
## days, travel points and sentences to type. Prints a report.
## Run: godot --headless --path game --script res://tests/measure_critical_path.gd
const World = preload("res://src/world/world_state.gd")

var world: RefCounted
var cells := {}
var left := {}
var day := 1
var points := 0
var legs := 0
var unreachable: Array = []

func walk(hero: String, target: Vector2i) -> void:
	var path: Array = world.grid.get_id_path(cells[hero], target)
	if path.is_empty() and cells[hero] != target:
		unreachable.append([hero, target])
		return
	legs += 1
	for i in range(1, path.size()):
		var cost: int = world.terrain_cost(path[i])
		if left[hero] < cost:
			day += 1
			for id in left:
				left[id] = int(world.party.heroes[id].definition.movement_max)
		left[hero] -= cost
		points += cost
	cells[hero] = target

func location(id: String) -> Vector2i:
	for entry: Dictionary in world.locations:
		if entry.id == id:
			return Vector2i(entry.position[0], entry.position[1])
	return Vector2i(-1, -1)

func _initialize() -> void:
	world = World.new("province_160x120_v1")
	var proof := {}
	for id: String in world.evidence.definitions:
		var node: Dictionary = world.evidence.definitions[id]
		proof[id] = {"found_day": 1, "classification": node.classification, "spanish_note": node.language.sample}
	world.evidence.restore(proof, 1)
	world._sync_gates()
	for id: String in world.party.heroes:
		cells[id] = world.party.heroes[id].cell
		left[id] = int(world.party.heroes[id].definition.movement_max)
	var cards := 0
	var decisions := 0
	for id: String in world.campaign.definitions:
		var node: Dictionary = world.campaign.definitions[id]
		if node.get("optional", false):
			continue
		var hero: String = "inquisitor" if node.hero == "any" else node.hero
		if node.get("reunite", false):
			for member in cells:
				walk(member, location(node.location))
		else:
			walk(hero, location(node.location))
		if node.has("outcomes"):
			decisions += 1
		else:
			cards += 1
	# The ordered course: delayed recall needs later days.
	var course = world.learner.curriculum
	var course_day := 1
	var typed_lessons := 0
	var guard := 0
	while not course.completed() and guard < 1000:
		guard += 1
		var task: Dictionary = course.next_task(course_day)
		if task.stage == "wait":
			course_day += 1
		elif task.stage == "introduce":
			course.introduce(task.card.id, course_day)
		else:
			var answer: String = task.card.model if task.stage == "guided" else task.card.exercises[["first", "second", "recall"].find(task.stage)].answers[0]
			course.submit(task.card.id, answer, course_day)
			typed_lessons += 1
	var opening_notes: int = world.evidence.definitions.size()
	print("travel_days\t%d" % day)
	print("travel_points\t%d" % points)
	print("legs\t%d" % legs)
	print("unreachable\t%s" % str(unreachable))
	print("mainline_cards\t%d" % cards)
	print("mainline_decisions\t%d" % decisions)
	print("opening_evidence_steps\t%d" % opening_notes)
	print("lesson_sentences\t%d" % typed_lessons)
	print("course_min_days\t%d" % course_day)
	quit()
