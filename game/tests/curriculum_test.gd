extends SceneTree
const Course = preload("res://src/spanish/curriculum.gd")
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
	var course := Course.new()
	check(course.blocks.size() == 7 and course.index() == 0, "Seven ordered blocks")
	check(not course.allowed_grammar().has("preterite"), "Past tense not available initially")
	check(not course.introduce("conditional", 1), "Cannot skip to advanced card")
	check(not course.submit("identity", course.blocks[0].cards[0].exercises[0].answers[0], 1).ok, "Introduction required")
	var day := 1
	var previous_index := 0
	var visits := {}
	var snapshots: Array = []
	var iterations := 0
	while not course.completed() and iterations < 300:
		iterations += 1
		var task := course.next_task(day)
		if task.stage == "wait":
			check(course.index() == previous_index, "Same-day practice cannot waive delayed recall")
			day += 1
			continue
		check(course.index() <= previous_index + 1, "Blocks advance only one at a time")
		previous_index = course.index()
		visits[previous_index] = true
		if task.stage == "introduce":
			check(course.introduce(task.card.id, day), "Lesson introduction")
		else:
			check(not course.submit(task.card.id, "sí", day).ok, "Non-answer cannot earn progression")
			var answer: String = task.card.model if task.stage == "guided" else task.card.exercises[["first", "second", "recall"].find(task.stage)].answers[0]
			check(course.submit(task.card.id, answer, day).ok, "Authored transfer or recall accepted")
		var snapshot := course.snapshot()
		var loaded := Course.new()
		check(loaded.restore(snapshot, day), "Every intermediate lesson state restores")
		check(loaded.block_id() == course.block_id(), "Restore derives the same block")
		if course.index() > previous_index:
			snapshots.append(snapshot)
	check(course.completed() and visits.size() == 7 and day >= 8, "All blocks require spaced practice")
	check(course.records.size() == 31, "All 31 topics completed")
	check(course.allowed_grammar().has("subjunctive_basic") and course.allowed_grammar().has("future_simple"), "Advanced grammar arrives after foundations")
	var total_contexts := {}
	var verbs := {}
	for block: Dictionary in course.blocks:
		var contexts := {}
		for card: Dictionary in block.cards:
			contexts[card.context] = true
			check(card.tag in block.grammar, "Each lesson has a current-block grammar target")
			check(card.exercises.size() == 3, "Two transfer questions and delayed recall")
			# Player level (spec 1.3): a refresher for a B1 learner, not beginner drills.
			check(str(card.rule).length() >= 60 and str(card.model).split(" ").size() >= 5, "Lesson has a real rule reminder and a full-sentence model: " + card.id)
			for exercise: Dictionary in card.exercises:
				check(str(exercise.answers[0]).split(" ").size() >= 4 and course.normalized(exercise.answers[0]) != course.normalized(card.model), "Exercise asks for a full sentence that is not the model: " + card.id)
				for accepted: String in exercise.answers:
					check(not course.normalized(card.rule).contains(course.normalized(accepted)) and not course.normalized(exercise.prompt).contains(course.normalized(accepted)), "Neither rule nor prompt gives the answer away: " + card.id)
			check(card.exercises[0].answers != card.exercises[1].answers and card.exercises[1].answers != card.exercises[2].answers, "Transfer prompts change answer")
		check(contexts.size() >= 3, "Each block spans at least three contexts")
		for verb in block.verbs:
			verbs[verb] = true
	check(verbs.size() == 25, "All target irregular verbs represented")
	var before := course.snapshot()
	var bad := before.duplicate(true)
	bad.records.identity.recall.day = bad.records.identity.second.day
	check(not course.restore(bad, day) and course.snapshot() == before, "Same-day recall forgery rejected transactionally")
	bad = before.duplicate(true)
	bad.records.erase("existence")
	check(not Course.new().restore(bad, day), "Cannot restore skipped early topic")
	bad = before.duplicate(true)
	bad.records.identity.first.answer = "Estoy investigador"
	check(not Course.new().restore(bad, day), "Forged independent production rejected")
	var modes := {"weak_review": 0, "current": 0, "stretch": 0}
	course.cursor = 0
	for i in 20:
		var focus := course.select_focus({}, {})
		modes[focus.mode] += 1
		check(focus.tag in course.allowed_grammar(), "Scheduler never selects untaught grammar")
	check(modes == {"weak_review": 12, "current": 5, "stretch": 3}, "Consolidated schedule is 60/25/15")
	var early := Course.new()
	early.cursor = 17
	check(early.select_focus({}, {}).mode == "current", "Early consolidation suppresses stretch")
	var a: String = early.select_focus({}, {}).tag
	var b: String = early.select_focus({}, {}).tag
	check(a != b, "Avoid immediate focus repetition when alternatives exist")
	var old_dimensions: Dictionary = early.dimensions.duplicate()
	early.observe_difficulty(true, 0.4)
	check(early.dimensions == old_dimensions, "Uncertain evaluation cannot change difficulty")
	for i in 3:
		early.observe_difficulty(true, 0.9)
	var changed := 0
	for axis in early.dimensions:
		if early.dimensions[axis] != old_dimensions[axis]:
			changed += 1
	check(changed == 1, "Three successes adjust exactly one dimension")
	for i in 30:
		early.observe_difficulty(true, 0.9)
	var total := 0.0
	for axis in early.dimensions:
		total += absf(early.dimensions[axis] - old_dimensions[axis])
	check(total <= 0.100001, "Conversation adjustment capped at 0.10")
	early.begin_conversation()
	old_dimensions = early.dimensions.duplicate()
	early.observe_difficulty(false, 0.9)
	early.observe_difficulty(false, 0.9)
	check(early.dimensions != old_dimensions, "Two comprehension failures reduce pressure")
	check(early.index() == 0, "Adaptive difficulty cannot advance curriculum")
	print("Curriculum checks: %d, failures: %d" % [checks, failures])
	quit(1 if failures else 0)
