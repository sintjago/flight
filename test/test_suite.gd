extends Node

const FlightWorld = preload("res://scripts/flight/flight_world.gd")
const MathQuestion = preload("res://scripts/flight/math_question.gd")

var _failures := PackedStringArray()
var _checks := 0
var _saved_user_files: Dictionary = {}
var _crash_events := 0
var _score_events := 0
var _question_events := 0


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	for path: String in [SaveStore.SAVE_PATH]:
		_saved_user_files[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	SaveStore.set("_data", SaveStore.call("_default_data"))
	_test_autoloads_and_schema()
	_test_geometry()
	_test_math_questions()
	await _test_simulation()
	_test_fairness_bot()
	_test_save_store()
	await _test_runtime_scene()
	_restore_user_files()
	if _failures.is_empty():
		print("[paper-glide-tests] PASS: %d checks" % _checks)
		get_tree().quit(0)
		return
	for failure: String in _failures:
		push_error("[paper-glide-tests] " + failure)
	get_tree().quit(1)


func _test_autoloads_and_schema() -> void:
	for node_name: String in ["I18n", "TuningStore", "SaveStore", "AudioDirector"]:
		_check(get_tree().root.get_node_or_null(node_name) != null, "%s autoload must exist" % node_name)
	var tuning := get_tree().root.get_node("TuningStore")
	tuning.call("reset_defaults")
	_check(is_equal_approx(float(tuning.call("get_active_value", "gameplay.physics.gravity")), 1500.0), "default gravity")
	_check(is_equal_approx(float(tuning.call("get_active_value", "gameplay.course.gap_size")), 180.0), "default answer gap size")
	_check(get_tree().root.get_node("I18n").call("t", "over.restart") == "FLY AGAIN", "English strings resolve")
	for setting: Dictionary in tuning.call("get_settings"):
		_check(get_tree().root.get_node("I18n").call("t", str(setting.label_key)) != str(setting.label_key), "label for %s" % setting.id)


func _test_geometry() -> void:
	var rect := Rect2(100.0, 100.0, 50.0, 50.0)
	_check(FlightWorld.circle_hits_rect(Vector2(95.0, 125.0), 8.0, rect), "circle overlapping a rect edge hits")
	_check(not FlightWorld.circle_hits_rect(Vector2(80.0, 125.0), 8.0, rect), "circle clear of a rect misses")
	var rects := FlightWorld.gate_rects(500.0, 240.0, 490.0, 150.0)
	_check(rects.size() == 3, "a two-answer gate has upper, middle, and lower solid sections")
	_check(not FlightWorld.circle_hits_rect(Vector2(500.0, 240.0), 12.0, rects[0]), "upper answer lane remains open")
	_check(not FlightWorld.circle_hits_rect(Vector2(500.0, 490.0), 12.0, rects[2]), "lower answer lane remains open")
	_check(FlightWorld.circle_hits_rect(Vector2(500.0, 365.0), 12.0, rects[1]), "solid divider separates the answer lanes")


func _test_math_questions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 918273
	for mode: String in MathQuestion.DIFFICULTIES:
		var seen_operators: Dictionary = {}
		for _i in 60:
			var question: Dictionary = MathQuestion.generate(rng, mode)
			var expected := 0
			match str(question.operator):
				"+":
					expected = int(question.a) + int(question.b)
				"-":
					expected = int(question.a) - int(question.b)
				"×":
					expected = int(question.a) * int(question.b)
				"÷":
					_check(int(question.a) % int(question.b) == 0, "hard division is exact")
					expected = int(int(question.a) / int(question.b))
			seen_operators[str(question.operator)] = true
			var answers: Array[int] = [int(question.upper_answer), int(question.lower_answer)]
			_check(str(question.expression).contains("= ?"), "%s equation has a visible blank" % mode)
			_check(int(question.answer) == expected, "%s equation answer is arithmetically correct" % mode)
			_check(answers[0] != answers[1], "%s gate has two different answers" % mode)
			_check(answers.count(int(question.answer)) == 1, "%s gate has exactly one correct answer" % mode)
			_check(answers[0 if question.correct_lane == "upper" else 1] == int(question.answer), "%s correct lane matches the answer" % mode)
		var required_operators := ["+", "-"] if mode == "easy" else (["+", "-", "×"] if mode == "medium" else ["+", "-", "×", "÷"])
		for operator: String in required_operators:
			_check(seen_operators.has(operator), "%s mode includes %s problems" % [mode, operator])


func _make_world() -> Node2D:
	var world: Node2D = FlightWorld.new()
	add_child(world)
	_crash_events = 0
	_score_events = 0
	_question_events = 0
	world.connect("crashed", func(_total: int, _ground: bool) -> void: _crash_events += 1)
	world.connect("scored", func(_total: int) -> void: _score_events += 1)
	world.connect("question_changed", func(_expression: String, _difficulty: String) -> void: _question_events += 1)
	return world


func _set_pipes(world: Node2D, items: Array) -> void:
	var pipes: Array = world.get("pipes")
	pipes.clear()
	for item in items:
		pipes.append(item)


func _make_gate(x: float, upper_y: float, gap: float, correct_lane: String) -> Dictionary:
	var answer := 42
	var distractor := 17
	return {
		"x": x,
		"upper_y": upper_y,
		"lower_y": upper_y + 250.0,
		"gap": gap,
		"expression": "6 × 7 = ?",
		"answer": answer,
		"distractor": distractor,
		"upper_answer": answer if correct_lane == "upper" else distractor,
		"lower_answer": distractor if correct_lane == "upper" else answer,
		"correct_lane": correct_lane,
		"passed": false,
	}


func _test_simulation() -> void:
	var world := _make_world()
	_check(world.get("state") == "ready", "world starts waiting for the first tap")
	world.call("flap")
	_check(world.get("state") == "playing", "first flap starts the run")
	_check(is_equal_approx(float(world.get("plane_vy")), -float(world.get("flap_speed"))), "flap sets upward speed")
	var start_y: float = world.get("plane_y")
	for i in 10:
		world.call("step", 1.0 / 60.0)
	_check(float(world.get("plane_y")) < start_y, "a flap carries the plane upward against gravity")
	for i in 400:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "dead", "an untouched plane falls to the ground and crashes")
	_check(_crash_events == 1, "crash is reported exactly once")
	for i in 60:
		world.call("step", 1.0 / 60.0)
	_check(_crash_events == 1, "dead world does not re-report crashes")
	world.queue_free()

	world = _make_world()
	world.call("flap")
	world.set("gravity", 0.0)
	world.set("plane_vy", 0.0)
	var initial_question: Dictionary = world.get("current_question")
	var initial_gates: Array = world.get("pipes")
	var initial_gate: Dictionary = initial_gates[0]
	_check(str(initial_question.expression).contains("= ?"), "a new run creates an active equation")
	_check(initial_gate.has("upper_answer") and initial_gate.has("lower_answer"), "every obstacle shows two answers")
	world.set("plane_y", 240.0)
	_set_pipes(world, [_make_gate(FlightWorld.PLANE_X + 120.0, 240.0, 190.0, "upper")])
	for i in 90:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "playing", "flying through the correct answer lane is safe")
	_check(int(world.get("score")) == 1 and _score_events == 1, "passing a correct answer gate scores once")
	_check(_question_events >= 2, "the next gate refreshes the active equation")
	world.queue_free()

	world = _make_world()
	world.call("flap")
	world.set("gravity", 0.0)
	world.set("plane_vy", 0.0)
	world.set("plane_y", 240.0)
	_set_pipes(world, [_make_gate(FlightWorld.PLANE_X + 120.0, 240.0, 190.0, "lower")])
	for i in 90:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "dead" and _crash_events == 1, "choosing the wrong answer ends the run")
	_check(world.get("failure_reason") == "wrong_answer", "wrong-answer feedback is distinguished from a collision")
	_check(str(world.get("failure_answer")) == "42", "wrong-answer state reveals the correct answer")
	_check(int(world.get("score")) == 0, "a wrong answer does not score")
	world.queue_free()

	world = _make_world()
	world.call("flap")
	world.set("gravity", 0.0)
	world.set("plane_vy", 0.0)
	world.set("plane_y", 365.0)
	_set_pipes(world, [_make_gate(FlightWorld.PLANE_X + 120.0, 240.0, 190.0, "upper")])
	for i in 90:
		world.call("step", 1.0 / 60.0)
	_check(world.get("state") == "dead" and world.get("failure_reason") == "collision", "the center divider remains solid")
	_check(int(world.get("score")) == 0, "a collision does not score")
	world.queue_free()

	world = _make_world()
	world.call("set_difficulty", "easy")
	var easy_gap := float(world.get("base_gap"))
	world.call("set_difficulty", "medium")
	var medium_gap := float(world.get("base_gap"))
	world.call("set_difficulty", "hard")
	var hard_gap := float(world.get("base_gap"))
	_check(easy_gap > medium_gap and medium_gap > hard_gap, "difficulty modes adjust answer-lane clearance")
	_check(world.call("current_gap", 0) > world.call("current_gap", 12), "gaps tighten as the run goes on")
	_check(world.call("current_gap", 500) >= float(world.get("base_gap")) * 0.84 - 0.01, "gap shrink has a floor")
	world.queue_free()
	await get_tree().process_frame


## A simple tap-when-below-target bot must be able to clear a long stretch of generated pipes.
func _test_fairness_bot() -> void:
	for seed_value in [1, 2, 3]:
		var world := _make_world()
		world.rng.seed = seed_value
		world.call("flap")
		var steps := 0
		while world.get("state") == "playing" and steps < 60 * 90:
			var target := 360.0
			for gate: Dictionary in world.get("pipes"):
				if not gate.passed:
					target = float(gate.upper_y) if gate.correct_lane == "upper" else float(gate.lower_y)
					break
			if float(world.get("plane_y")) > target and float(world.get("plane_vy")) > -50.0:
				world.call("flap")
			world.call("step", 1.0 / 60.0)
			steps += 1
		var detail := "reason=%s y=%.1f vy=%.1f" % [str(world.get("failure_reason")), float(world.get("plane_y")), float(world.get("plane_vy"))]
		_check(int(world.get("score")) >= 15, "generated courses are passable (seed %d scored %d; %s)" % [seed_value, int(world.get("score")), detail])
		world.queue_free()


func _test_save_store() -> void:
	SaveStore.set("_data", SaveStore.call("_default_data"))
	_check(SaveStore.record_run(7, true, "medium"), "first scoring run sets a best")
	_check(SaveStore.get_best_score("medium") == 7, "best score persists for its difficulty")
	_check(not SaveStore.record_run(5, true, "medium"), "a lower score is not a new best")
	_check(SaveStore.record_run(3, true, "easy"), "a separate difficulty starts its own best")
	_check(SaveStore.get_best_score("easy") == 3 and SaveStore.get_best_score("medium") == 7, "difficulty bests do not overwrite each other")
	_check(not SaveStore.record_run(99, false, "hard"), "practice runs never set the best")
	_check(SaveStore.get_best_score() == 7, "overall best persists across modes")
	_check(SaveStore.get_games_played() == 4, "every run is counted")


func _test_runtime_scene() -> void:
	var tuning := get_tree().root.get_node("TuningStore")
	tuning.call("reset_defaults")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null, "main scene must load")
	if packed == null:
		return
	var main: Control = packed.instantiate()
	get_tree().root.add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(bool((main.get("_title_screen") as Control).visible), "title screen shows on boot")
	_check(main.get("_state") == "title", "game boots into the title state")
	var difficulty_buttons: Dictionary = main.get("_difficulty_buttons")
	_check(difficulty_buttons.has("easy") and difficulty_buttons.has("medium") and difficulty_buttons.has("hard"), "title offers Easy, Medium, and Hard")
	main.call("_select_difficulty", "hard")
	_check(main.get("_selected_difficulty") == "hard", "selected math difficulty is remembered")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.call("_unhandled_input", click)
	await get_tree().process_frame
	_check(main.get("_state") == "playing", "a tap on the title starts flying")
	_check(not bool((main.get("_title_screen") as Control).visible), "title hides once flying")
	_check((main.get("_world") as Node2D).get("state") == "playing", "world is running after the first tap")
	_check((main.get("_world") as Node2D).get("difficulty") == "hard", "selected difficulty reaches the flight world")
	_check(bool((main.get("_question_bar") as Control).visible), "equation bar appears during flight")
	_check(str((main.get("_question_label") as Label).text).contains("= ?"), "equation bar shows the active equation")
	main.call("_set_paused", true)
	_check(get_tree().paused and main.get("_state") == "paused", "pause freezes the tree")
	main.call("_set_paused", false)
	_check(not get_tree().paused and main.get("_state") == "playing", "resume continues the run")
	var world: Node2D = main.get("_world")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	_check(main.get("_state") == "over", "crash moves the game to the over state")
	main.set("_over_unlock_ms", 0)
	main.call("_unhandled_input", click)
	await get_tree().process_frame
	_check(main.get("_state") == "playing" and int(world.get("score")) == 0, "one tap restarts a fresh run")
	get_tree().paused = false
	main.queue_free()
	await get_tree().process_frame


func _restore_user_files() -> void:
	for path: String in _saved_user_files:
		var content: Variant = _saved_user_files[path]
		if content == null:
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		else:
			var file := FileAccess.open(path, FileAccess.WRITE)
			if file != null:
				file.store_buffer(content)
				file.close()


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
