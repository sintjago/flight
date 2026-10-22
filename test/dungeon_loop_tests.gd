extends RefCounted
## Deterministic checks for grid movement, question-driven combat, room progression and the boss.

const DungeonWorld = preload("res://scripts/dungeon/dungeon_world.gd")


static func run(check: Callable, tree: SceneTree) -> void:
	var world := DungeonWorld.new()
	world.name = "DungeonLoopTestWorld"
	tree.root.add_child(world)
	_check_question_generation_for_all_subjects(world, check)
	_check_full_run_and_defeat(world, check)
	world.queue_free()


static func _check_question_generation_for_all_subjects(world: Node2D, check: Callable) -> void:
	for area: String in ["math", "reading", "russian", "spanish", "science"]:
		world.call("set_practice_area", area)
		world.call("set_math_track", "math_1")
		world.call("set_difficulty", 3)
		world.call("set_selected_topics", [])
		world.call("start_run")
		var moved_once := bool(world.call("move_player", Vector2i.RIGHT))
		var moved_twice := bool(world.call("move_player", Vector2i.RIGHT))
		check.call(moved_once and moved_twice and str(world.get("state")) == "combat", "%s begins combat by moving next to its foe" % area)
		var question := _check_two_choice_question(world, area, check)
		if not question.is_empty():
			var correct_index := int(question.get("correct_index", -1))
			var wrong_index := 1 - correct_index
			world.call("submit_answer", wrong_index)
			check.call(int(world.get("hearts")) == 2 and str(world.get("state")) == "feedback", "%s incorrect answer costs exactly one heart and shows feedback" % area)
			check.call(str(world.get("failure_answer")) == str(question.get("answer", "")) and not str(world.get("failure_hint_key")).is_empty(), "%s feedback retains the right answer and a teaching hint" % area)
		world.call("reset_ready")


static func _check_full_run_and_defeat(world: Node2D, check: Callable) -> void:
	world.call("set_practice_area", "math")
	world.call("set_math_track", "math_1")
	world.call("set_difficulty", 2)
	world.call("set_selected_topics", [])
	world.call("start_run")
	check.call(int(world.get("hearts")) == 3 and int(world.get("room_index")) == 0, "a new run starts with three hearts in chamber one")
	check.call(not bool(world.call("move_player", Vector2i.LEFT)), "grid walls block movement outside the chamber")
	world.call("move_player", Vector2i.RIGHT)
	world.call("move_player", Vector2i.RIGHT)
	var first_question := _check_two_choice_question(world, "math", check)
	if first_question.is_empty():
		world.queue_free()
		return
	var wrong_index := 1 - int(first_question.get("correct_index", -1))
	world.call("submit_answer", wrong_index)
	check.call(int(world.get("hearts")) == 2 and world.get("answer_history").size() == 1, "one wrong answer reduces the heart count once and is recorded")
	world.call("continue_after_wrong")
	var retry_question: Dictionary = world.get("current_question")
	world.call("submit_answer", int(retry_question.get("correct_index", -1)))
	check.call(int(world.get("score")) == 1 and not bool(world.get("enemy_alive")) and bool(world.get("exit_unlocked")), "a correct answer defeats the chamber foe and unlocks its exit")
	_walk(world, [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT], check, "chamber one exit path")
	check.call(int(world.get("room_index")) == 1 and int(world.get("rooms_cleared")) == 1, "reaching the open exit advances to chamber two")

	_walk(world, [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP], check, "chamber two route")
	_check_two_choice_question(world, "math", check)
	_clear_current_foe(world, check, "chamber two")
	_walk(world, [Vector2i.RIGHT, Vector2i.RIGHT], check, "chamber two exit path")
	check.call(int(world.get("room_index")) == 2 and int(world.get("rooms_cleared")) == 2, "the second open exit advances to chamber three")

	_walk(world, [Vector2i.DOWN, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT], check, "chamber three route")
	_check_two_choice_question(world, "math", check)
	_clear_current_foe(world, check, "chamber three")
	_walk(world, [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.UP], check, "chamber three exit path")
	check.call(int(world.get("room_index")) == 3 and int(world.get("rooms_cleared")) == 3, "three chambers lead to the final boss room")

	_walk(world, [Vector2i.RIGHT, Vector2i.RIGHT, Vector2i.RIGHT], check, "boss approach")
	_check_two_choice_question(world, "math", check)
	var boss_question: Dictionary = world.get("current_question")
	world.call("submit_answer", int(boss_question.get("correct_index", -1)))
	check.call(bool(world.get("enemy_alive")) and int(world.get("enemy_hp")) == 1 and str(world.get("state")) == "combat", "the boss survives its first correct answer and takes one hit")
	var second_boss_question: Dictionary = world.get("current_question")
	world.call("submit_answer", int(second_boss_question.get("correct_index", -1)))
	check.call(str(world.get("state")) == "won" and int(world.get("rooms_cleared")) == 3, "a second correct answer defeats the boss and wins the run")
	check.call(int(world.get("score")) == 5 and world.get("answer_history").size() == 6, "the complete run records correct strikes and the earlier mistake")

	world.call("start_run")
	world.call("move_player", Vector2i.RIGHT)
	world.call("move_player", Vector2i.RIGHT)
	for attempt in range(3):
		var question: Dictionary = world.get("current_question")
		var wrong_answer := 1 - int(question.get("correct_index", -1))
		world.call("submit_answer", wrong_answer)
		if attempt < 2:
			world.call("continue_after_wrong")
	check.call(str(world.get("state")) == "defeated" and int(world.get("hearts")) == 0, "three incorrect answers end the run at zero hearts")
	check.call(bool(world.get("_run_finalized")), "a defeated dungeon run is finalized exactly once")


static func _check_two_choice_question(world: Node2D, area: String, check: Callable) -> Dictionary:
	var question: Dictionary = world.get("current_question")
	var options: Array = question.get("answer_options", [])
	var correct_index := int(question.get("correct_index", -1))
	var answer := str(question.get("answer", ""))
	check.call(str(question.get("practice_area", "")) == area and not str(question.get("expression", "")).is_empty(), "%s question comes from its selected subject" % area)
	check.call(options.size() == 2 and options[0] != options[1], "%s encounter offers two distinct answer choices" % area)
	check.call(correct_index >= 0 and correct_index < options.size() and str(options[correct_index]) == answer, "%s correct-choice index matches the answer text" % area)
	return question.duplicate(true)


static func _clear_current_foe(world: Node2D, check: Callable, room_label: String) -> void:
	if str(world.get("state")) != "combat":
		check.call(false, "%s route reaches a combat encounter" % room_label)
		return
	var question: Dictionary = world.get("current_question")
	world.call("submit_answer", int(question.get("correct_index", -1)))
	check.call(not bool(world.get("enemy_alive")) and bool(world.get("exit_unlocked")), "%s correct answer clears the foe" % room_label)


static func _walk(world: Node2D, directions: Array, check: Callable, path_label: String) -> void:
	for step: Variant in directions:
		var moved := bool(world.call("move_player", step))
		check.call(moved, "%s accepts step %s" % [path_label, str(step)])
