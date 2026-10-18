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
	_check(get_tree().root.get_node("I18n").call("t", "over.restart") == "TRY AGAIN", "English strings resolve")
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
	var required_topics: Dictionary = {
		"easy": ["addition", "subtraction", "multiplication", "division", "fractions", "place_value", "number_patterns"],
		"medium": ["addition", "subtraction", "multiplication", "division", "fractions", "decimals", "percentages", "ratios", "order_of_operations"],
		"hard": ["integers", "fractions", "algebra", "quadratics", "exponents", "roots", "geometry", "trigonometry"],
	}
	for mode: String in MathQuestion.DIFFICULTIES:
		var seen_topics: Dictionary = {}
		for _i in 180:
			var question: Dictionary = MathQuestion.generate(rng, mode)
			var answers: Array[String] = [str(question.upper_answer), str(question.lower_answer)]
			var topic := str(question.topic)
			seen_topics[topic] = true
			_check(str(question.difficulty) == mode, "%s prompt keeps its selected level" % mode)
			_check(str(question.expression).contains("?"), "%s prompt shows a missing answer" % mode)
			_check(answers[0] != answers[1], "%s gate has two different answers" % mode)
			_check(answers.count(str(question.answer)) == 1, "%s gate has exactly one correct answer" % mode)
			var correct_option := str(question.upper_answer) if question.correct_lane == "upper" else str(question.lower_answer)
			_check(correct_option == str(question.answer), "%s correct lane matches the answer" % mode)
			_check(I18n.t("topic." + topic) != "topic." + topic, "%s topic has a learner-facing label" % topic)
			_check(I18n.t(str(question.hint_key)) != str(question.hint_key), "%s prompt has a translated learning hint" % topic)
			_check(int(question.value_den) > 0, "%s answer has a valid denominator" % mode)
			_validate_math_question(question, mode)
		for required_topic: String in required_topics[mode]:
			_check(seen_topics.has(required_topic), "%s curriculum includes %s" % [mode, required_topic])
	for level in range(0, 11):
		for group: String in MathQuestion.available_topic_groups(level):
			var filtered: Dictionary = MathQuestion.generate(rng, level, [group])
			_check(str(filtered.topic_group) == group, "level %d question follows the selected %s checkbox" % [level, group])
			_check(int(filtered.difficulty_level) == level, "question records the exact selected slider value")


func _validate_math_question(question: Dictionary, mode: String) -> void:
	var kind := str(question.kind)
	var topic := str(question.topic)
	var answer_text := str(question.answer)
	match kind:
		"integer_operation":
			var a := int(question.a)
			var b := int(question.b)
			var expected := 0
			match str(question.operator):
				"+":
					expected = a + b
				"-":
					expected = a - b
				"×":
					expected = a * b
				"÷":
					_check(b != 0 and a % b == 0, "%s division prompt is exact" % mode)
					expected = int(a / b)
			_check(answer_text == str(expected), "%s arithmetic answer is correct" % topic)
			if mode == "easy" and topic in ["addition", "subtraction"]:
				_check(a <= 100 and b <= 100 and expected >= 0 and expected <= 100, "Easy addition/subtraction stays within 100")
			if mode == "easy" and topic == "multiplication":
				_check(a <= 10 and b <= 10 and expected <= 100, "Easy multiplication stays within 10×10 and product 100")
			if mode == "easy" and topic == "division":
				_check(a <= 100 and b <= 10 and expected <= 10, "Easy division uses facts within 100")
		"fraction_of":
			var expected_fraction := int(question.numerator) * int(question.whole)
			_check(expected_fraction % int(question.denominator) == 0, "Easy fraction-of prompts have whole-number results")
			_check(answer_text == str(int(expected_fraction / int(question.denominator))), "fraction-of answer is correct")
			_check(int(question.whole) <= 80 and int(question.denominator) in [2, 4], "Easy fractions use familiar halves and quarters")
		"fraction_compare":
			var left_num := int(question.left_num)
			var left_den := int(question.left_den)
			var right_num := int(question.right_num)
			var right_den := int(question.right_den)
			var choose_left := left_num * right_den > right_num * left_den
			var expected_fraction := MathQuestion._format_fraction(left_num, left_den) if choose_left else MathQuestion._format_fraction(right_num, right_den)
			_check(answer_text == expected_fraction, "fraction comparison selects the larger value")
			_check(maxi(left_den, right_den) <= 4, "Easy fraction comparison uses small denominators")
		"place_value":
			_check(int(question.a) >= 10 and int(question.a) <= 99 and answer_text == str(int(int(question.a) / 10)), "place-value prompt identifies the tens digit")
		"number_pattern":
			_check(int(question.a) + 3 * int(question.b) == int(answer_text) and int(answer_text) <= 100, "Easy number pattern continues correctly within 100")
		"fraction_operation":
			var sign := 1 if str(question.operator) == "+" else -1
			var numerator := int(question.left_num) * int(question.right_den) + sign * int(question.right_num) * int(question.left_den)
			var denominator := int(question.left_den) * int(question.right_den)
			_check(int(question.value_num) * denominator == numerator * int(question.value_den), "fraction operation is arithmetically correct")
			_check(answer_text == MathQuestion._format_fraction(numerator, denominator), "fraction answer is shown in simplest form")
		"decimal_operation":
			var cents := int(question.a_cents) + int(question.b_cents) if str(question.operator) == "+" else int(question.a_cents) - int(question.b_cents)
			_check(answer_text == MathQuestion._format_decimal_cents(cents), "decimal operation keeps place values aligned")
		"percentage":
			var result := int(question.amount) * int(question.percent)
			_check(result % 100 == 0 and answer_text == str(int(result / 100)), "percentage-of-amount answer is exact")
		"ratio":
			_check(int(question.known) == int(question.a) * int(question.scale), "ratio known term uses the stated scale")
			_check(answer_text == str(int(question.b) * int(question.scale)), "ratio answer preserves equivalence")
		"order_operations":
			var expected := int(question.a) + int(question.b) * int(question.c)
			if int(question.form) == 1:
				expected = (int(question.a) + int(question.b)) * int(question.c)
			elif int(question.form) == 2:
				expected = int(question.a) * int(question.b) - int(question.c)
			_check(answer_text == str(expected), "medium order-of-operations answer is correct")
		"linear_equation":
			_check(int(question.coefficient) * int(question.solution) + int(question.intercept) == int(question.result), "linear equation balances")
			_check(answer_text == str(int(question.solution)), "linear equation reveals the correct x")
		"quadratic":
			var root := int(answer_text)
			_check(root * root - int(question.sum_roots) * root + int(question.product_roots) == 0, "quadratic answer is a root")
			_check(root == mini(int(question.root_a), int(question.root_b)), "quadratic answer is the requested smaller root")
		"exponent":
			var power_result := int(pow(float(question.base), float(question.power))) + int(question.offset)
			_check(answer_text == str(power_result), "exponent expression is correct")
		"square_root":
			_check(int(question.root) * int(question.root) == int(question.radicand), "square-root prompt uses a perfect square")
			_check(answer_text == str(int(question.root) + int(question.offset)), "square-root answer is correct")
		"pythagorean":
			var c := int(answer_text)
			_check(int(question.a) * int(question.a) + int(question.b) * int(question.b) == c * c, "right-triangle dimensions satisfy Pythagoras")
			_check(c == int(question.hypotenuse), "geometry answer is the hypotenuse")
		"trigonometry":
			_check(answer_text in ["1/2", "sqrt(2)/2", "sqrt(3)/2", "1"], "trigonometry uses a standard exact-angle value")
		_:
			_check(false, "unrecognized generated question type: %s" % kind)

func _make_world() -> Node2D:
	var world: Node2D = FlightWorld.new()
	add_child(world)
	_crash_events = 0
	_score_events = 0
	_question_events = 0
	world.connect("crashed", func(_total: int, _ground: bool) -> void: _crash_events += 1)
	world.connect("scored", func(_total: int) -> void: _score_events += 1)
	world.connect("question_changed", func(_question: Dictionary) -> void: _question_events += 1)
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
		"topic": "multiplication",
		"hint_key": "hint.multiplication",
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
	_check(str(initial_question.expression).contains("?"), "a new run creates an active math prompt")
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
	var easy_speed := float(world.get("base_speed"))
	var easy_spacing := float(world.get("pipe_spacing"))
	world.call("set_difficulty", "medium")
	var medium_gap := float(world.get("base_gap"))
	var medium_speed := float(world.get("base_speed"))
	var medium_spacing := float(world.get("pipe_spacing"))
	world.call("set_difficulty", "hard")
	var hard_gap := float(world.get("base_gap"))
	var hard_speed := float(world.get("base_speed"))
	var hard_spacing := float(world.get("pipe_spacing"))
	_check(easy_gap > medium_gap and medium_gap > hard_gap, "difficulty modes adjust answer-lane clearance")
	_check(easy_speed < medium_speed and medium_speed < hard_speed, "math difficulty increases flight speed gradually")
	_check(easy_spacing > medium_spacing and medium_spacing > hard_spacing, "Easy gives a child more time between answer gates")
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
	var slider: HSlider = main.get("_difficulty_slider")
	_check(slider != null and slider.min_value == 0.0 and slider.max_value == 10.0 and slider.step == 1.0, "title offers the requested 0–10 difficulty slider")
	var topic_checkboxes: Dictionary = main.get("_topic_checkboxes")
	_check(topic_checkboxes.size() == MathQuestion.TOPIC_GROUPS.size(), "title shows checkboxes for math content categories")
	slider.value = 7.0
	_check(int(main.get("_selected_level")) == 7 and str(main.get("_selected_difficulty")) == "hard", "slider selects an exact high-school difficulty level")
	var algebra_checkbox: CheckBox = topic_checkboxes["algebra"]
	_check(not algebra_checkbox.disabled, "high-school topics unlock at the Hard band")
	main.call("_on_topic_toggled", true, "algebra")
	algebra_checkbox.set_pressed_no_signal(true)
	var selected_groups: Array = main.call("_selected_topic_groups")
	_check("algebra" in selected_groups and "fractions" in selected_groups, "multiple math topics can be selected together")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	main.call("_unhandled_input", click)
	await get_tree().process_frame
	_check(main.get("_state") == "playing", "a tap on the title starts flying")
	_check(not bool((main.get("_title_screen") as Control).visible), "title hides once flying")
	_check((main.get("_world") as Node2D).get("state") == "playing", "world is running after the first tap")
	_check((main.get("_world") as Node2D).get("difficulty") == "hard", "selected difficulty band reaches the flight world")
	_check(int((main.get("_world") as Node2D).get("difficulty_level")) == 7, "exact slider value reaches the flight world")
	_check("algebra" in (main.get("_world") as Node2D).get("selected_topic_groups"), "selected content reaches the question generator")
	_check(bool((main.get("_question_bar") as Control).visible), "equation bar appears during flight")
	_check(str((main.get("_question_label") as Label).text).contains("?"), "equation bar shows the active question")
	_check(not str((main.get("_question_hint_label") as Label).text).is_empty(), "equation bar shows a learning hint")
	_check(str((main.get("_question_difficulty_label") as Label).text).begins_with("LEVEL 7/10 · HARD · "), "question bar identifies the exact level and topic")
	main.call("_set_paused", true)
	_check(get_tree().paused and main.get("_state") == "paused", "pause freezes the tree")
	main.call("_set_paused", false)
	_check(not get_tree().paused and main.get("_state") == "playing", "resume continues the run")
	var world: Node2D = main.get("_world")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	_check(main.get("_state") == "over", "crash moves the game to the over state")
	await get_tree().create_timer(0.8).timeout
	_check(bool((main.get("_over_screen") as Control).visible), "crash screen presents the recovery choices")
	_check(main.get("_over_again_button") is Button and main.get("_over_easier_button") is Button and main.get("_over_home_button") is Button, "crash screen has Try Again, Lower Difficulty, and Home actions")
	(main.get("_over_easier_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(main.get("_state") == "playing" and int(main.get("_selected_level")) == 6 and int(world.get("score")) == 0, "Lower Difficulty decreases one step and starts a fresh run")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	await get_tree().create_timer(0.8).timeout
	(main.get("_over_home_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(main.get("_state") == "title" and bool((main.get("_title_screen") as Control).visible), "Home returns to content selection")
	_check(bool(algebra_checkbox.button_pressed), "Home preserves checked content for later selection")
	slider.value = 0.0
	main.call("_begin_from_title")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	await get_tree().create_timer(0.8).timeout
	_check((main.get("_over_easier_button") as Button).disabled, "Lower Difficulty is disabled at level zero")
	(main.get("_over_again_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(main.get("_state") == "playing" and int(main.get("_selected_level")) == 0, "Try Again restarts at the same slider level")
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
