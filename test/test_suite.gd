extends Node

const FlightWorld = preload("res://scripts/flight/flight_world.gd")
const MathQuestion = preload("res://scripts/flight/math_question.gd")
const LearningQuestion = preload("res://scripts/flight/learning_question.gd")

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
	_test_learning_questions()
	_test_question_rotation()
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
	var required_groups: Dictionary = {
		1: ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability"],
		2: ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability"],
		3: ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability", "decimals", "percentages", "ratios", "order_of_operations", "statistics"],
		4: ["integers", "algebra", "exponents", "roots", "geometry", "measurement", "probability", "statistics"],
		5: ["quadratics", "trigonometry", "measurement", "probability", "statistics", "geometry"],
	}
	_check(MathQuestion.difficulty_level_for("easy") == 2 and MathQuestion.difficulty_level_for("medium") == 3 and MathQuestion.difficulty_level_for("hard") == 4, "legacy score bands map safely into the new five-point scale")
	for level: int in range(1, 6):
		var mode := MathQuestion.band_for_level(level)
		var seen_groups: Dictionary = {}
		for _i in 200:
			var question: Dictionary = MathQuestion.generate(rng, level)
			var answers: Array[String] = [str(question.upper_answer), str(question.lower_answer)]
			var topic := str(question.topic)
			seen_groups[str(question.topic_group)] = true
			_check(str(question.difficulty) == mode and int(question.difficulty_level) == level, "question records its selected level %d" % level)
			_check(str(question.expression).contains("?"), "%s prompt shows a missing answer" % mode)
			_check(answers[0] != answers[1], "%s gate has two different answers" % mode)
			_check(answers.count(str(question.answer)) == 1, "%s gate has exactly one correct answer" % mode)
			var correct_option := str(question.upper_answer) if question.correct_lane == "upper" else str(question.lower_answer)
			_check(correct_option == str(question.answer), "%s correct lane matches the answer" % mode)
			_check(I18n.t("topic." + topic) != "topic." + topic, "%s topic has a learner-facing label" % topic)
			_check(I18n.t(str(question.hint_key)) != str(question.hint_key), "%s prompt has a translated learning hint" % topic)
			_check(int(question.value_den) > 0, "%s answer has a valid denominator" % mode)
			_validate_math_question(question, mode, level)
		for required_group: String in required_groups[level]:
			_check(seen_groups.has(required_group), "level %d curriculum includes %s" % [level, required_group])
		for group: String in MathQuestion.available_topic_groups(level):
			var filtered: Dictionary = MathQuestion.generate(rng, level, [group])
			_check(str(filtered.topic_group) == group, "level %d question follows the selected %s checkbox" % [level, group])
			_check(int(filtered.difficulty_level) == level, "question keeps the exact selected level")
	for level: int in range(1, 6):
		_check(MathQuestion.topic_unlock_level("quadratics") == 5 or level < 5, "high-school topics have a level-five unlock")
	_test_extended_question_forms(rng)


func _test_learning_questions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 58291
	_check(LearningQuestion.PRACTICE_AREAS.size() == 4, "four additional learner packs are available")
	for area: String in LearningQuestion.PRACTICE_AREAS:
		_check(I18n.t("practice." + area) != "practice." + area, "%s practice area has a learner-facing name" % area)
		for level: int in range(1, 6):
			var pool: Array = LearningQuestion.questions_for(area, level)
			_check(pool.size() >= 10, "%s level %d has an expanded question bank" % [area, level])
			if area == "science" and level <= 2:
				for template: Dictionary in pool:
					var easy_prompt := str(template.get("expression", "")).to_lower()
					_check(not easy_prompt.contains("photosynthesis") and not easy_prompt.contains("transpiration"), "basic Science levels avoid specialist plant terms")
			var seen_prompts: Dictionary = {}
			for template: Dictionary in pool:
				var topic_key := "topic." + str(template.get("topic", ""))
				var hint_key := str(template.get("hint_key", ""))
				var prompt := str(template.get("expression", ""))
				_check(not prompt.is_empty() and not seen_prompts.has(prompt), "%s level %d prompts are present and varied" % [area, level])
				seen_prompts[prompt] = true
				_check(str(template.get("answer", "")) != str(template.get("distractor", "")), "%s level %d has distinct answer choices" % [area, level])
				_check(I18n.t(topic_key) != topic_key, "%s prompt topic is labeled" % area)
				_check(not hint_key.is_empty() and I18n.t(hint_key) != hint_key, "%s prompt has a translated learning hint" % area)
				for text_value: String in [prompt, str(template.get("answer", "")), str(template.get("distractor", ""))]:
					for char_index: int in text_value.length():
						_check(ThemeDB.fallback_font.has_char(text_value.unicode_at(char_index)), "%s question and answer font supports its lesson characters" % area)
				for answer_text: String in [str(template.get("answer", "")), str(template.get("distractor", ""))]:
					var font_size := FlightWorld.fit_answer_font_size(answer_text, 104.0)
					var measured_width := ThemeDB.fallback_font.get_string_size(answer_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
					_check(measured_width <= 104.0, "%s gate answer '%s' fits at %.1f px" % [area, answer_text, measured_width])
			var history: Array = []
			var cycle_prompts: Dictionary = {}
			for _cycle_index in pool.size():
				var cycle_question: Dictionary = LearningQuestion.generate_with_history(rng, area, level, history)
				var cycle_prompt := str(cycle_question.expression)
				_check(not cycle_prompts.has(cycle_prompt), "%s level %d has no prompt repeats inside a cycle" % [area, level])
				cycle_prompts[cycle_prompt] = true
			_check(history.size() == pool.size(), "%s level %d tracks the complete question cycle" % [area, level])
			LearningQuestion.generate_with_history(rng, area, level, history)
			_check(history.size() == 1, "%s level %d reshuffles after exhausting its bank" % [area, level])
			for _sample in 40:
				var question: Dictionary = LearningQuestion.generate(rng, area, level)
				var answers: Array[String] = [str(question.upper_answer), str(question.lower_answer)]
				var correct_option := str(question.upper_answer) if question.correct_lane == "upper" else str(question.lower_answer)
				_check(str(question.practice_area) == area and int(question.difficulty_level) == level, "%s question keeps its pack and selected level" % area)
				_check(str(question.difficulty) == MathQuestion.band_for_level(level), "%s question records the matching score band" % area)
				_check(answers[0] != answers[1] and answers.count(str(question.answer)) == 1, "%s gate has two choices and one correct answer" % area)
				_check(correct_option == str(question.answer), "%s correct lane matches the teaching answer" % area)


func _test_question_rotation() -> void:
	var math_world := FlightWorld.new()
	add_child(math_world)
	math_world.call("set_selected_topics", ["addition", "multiplication", "fractions"])
	var first_cycle: Dictionary = {}
	var last_selected_group := ""
	for _index in 3:
		var group := str(math_world.call("_next_math_topic_group"))
		_check(group in ["addition", "multiplication", "fractions"], "Math rotation honors selected topics")
		_check(not first_cycle.has(group), "Math shows each selected topic once before repeating")
		first_cycle[group] = true
		last_selected_group = group
	var next_group := str(math_world.call("_next_math_topic_group"))
	_check(next_group != last_selected_group, "Math starts a fresh shuffled topic cycle")
	remove_child(math_world)
	math_world.free()

	var science_world := FlightWorld.new()
	add_child(science_world)
	science_world.call("set_practice_area", "science")
	science_world.call("set_difficulty", 1)
	var seen_science_prompts: Dictionary = {}
	for index in 10:
		science_world.call("_spawn_gate", 2000.0 + float(index) * 500.0)
		var question: Dictionary = science_world.get("current_question")
		var prompt := str(question.get("expression", ""))
		_check(not seen_science_prompts.has(prompt), "Science flight does not repeat a prompt in the first cycle")
		seen_science_prompts[prompt] = true
	_check(seen_science_prompts.size() == 10, "Science flight uses the expanded basic bank")
	science_world.call("_start_run")
	var history_state: Dictionary = science_world.get("_learning_prompt_history")
	var active_history: Array = history_state.get("science:1", [])
	_check(active_history.size() == 1, "starting a new run resets the learning question cycle")
	remove_child(science_world)
	science_world.free()


func _test_extended_question_forms(rng: RandomNumberGenerator) -> void:
	for level: int in range(1, 6):
		for group: String in MathQuestion.available_topic_groups(level):
			var seen_kinds: Dictionary = {}
			var seen_forms: Dictionary = {}
			var seen_operations: Dictionary = {}
			var seen_statistics: Dictionary = {}
			var seen_measurements: Dictionary = {}
			for _sample in 80:
				var question: Dictionary = MathQuestion.generate(rng, level, [group])
				_check(str(question.topic_group) == group, "filtered subject %s never leaks another topic" % group)
				_validate_math_question(question, MathQuestion.band_for_level(level), level)
				seen_kinds[str(question.kind)] = true
				seen_forms[str(question.get("form_type", ""))] = true
				seen_operations[str(question.get("operator", question.get("trig_function", "")))] = true
				seen_statistics[str(question.get("statistic", ""))] = true
				seen_measurements[str(question.get("conversion", ""))] = true
			if group == "measurement" and level == 1:
				_check(seen_kinds.has("money_sum") and seen_kinds.has("unit_conversion") and seen_kinds.has("measurement_sum"), "level one measurement includes money, time, and length practice")
			if group == "measurement" and level == 2:
				_check(seen_measurements.has("meters_to_cm") and seen_measurements.has("kilograms_to_g") and seen_measurements.has("hours_to_minutes") and seen_measurements.has("cm_to_m"), "level two measurement includes metric and time conversions in both directions")
			if group == "measurement" and level == 3:
				_check(seen_kinds.has("measurement_rate"), "level three measurement includes distance, time, and speed")
			if group == "geometry" and level == 2:
				_check(seen_kinds.has("rectangle_perimeter") and seen_kinds.has("rectangle_area"), "level two geometry teaches rectangle perimeter and area")
			if group == "geometry" and level == 3:
				_check(seen_kinds.has("triangle_area") and seen_kinds.has("triangle_angle"), "level three geometry teaches triangle area and angle sums")
			if group == "geometry" and level == 5:
				_check(seen_kinds.has("circle_area_factor") and seen_kinds.has("box_volume"), "level five geometry includes circle area and volume")
			if group == "fractions" and level == 4:
				_check(seen_operations.has("×"), "level four fractions include multiplication")
			if group == "fractions" and level == 5:
				_check(seen_operations.has("×") and seen_operations.has("÷"), "level five fractions include multiplication and division")
			if group == "statistics" and level == 3:
				_check(seen_statistics.has("mean") and seen_statistics.has("median") and seen_statistics.has("range"), "level three statistics include mean, median, and range")
			if group == "statistics" and level >= 4:
				_check(seen_statistics.has("mode"), "upper-level statistics include mode")
			if group == "algebra" and level == 4:
				_check(seen_forms.has("basic") and seen_forms.has("parentheses"), "level four algebra includes inverse-operation and parentheses forms")
			if group == "algebra" and level == 5:
				_check(seen_forms.has("both_sides"), "level five algebra includes x on both sides")
			if group == "quadratics" and level == 5:
				_check(seen_forms.has("expanded") and seen_forms.has("factored"), "level five quadratics include expanded and factorized forms")
			if group == "trigonometry" and level == 5:
				_check(seen_forms.has("special_angle") and seen_forms.has("triangle_ratio") and seen_operations.has("tan"), "trigonometry includes special-angle tangent and triangle ratios")
			if group == "decimals" and level >= 4:
				_check(seen_kinds.has("decimal_operation_advanced") and seen_operations.has("×") and seen_operations.has("÷"), "upper-level decimals include multiplication and division")
			if group == "percentages" and level == 4:
				_check(seen_forms.has("discount") and seen_forms.has("increase"), "level four percentages include discounts and increases")
			if group == "percentages" and level == 5:
				_check(seen_forms.has("reverse") and (seen_forms.has("discount") or seen_forms.has("increase")), "level five percentages include reverse-percent and change problems")
			if group == "ratios" and level == 4:
				_check(seen_kinds.has("unit_rate"), "level four ratios include unit rates")
			if group == "ratios" and level == 5:
				_check(seen_kinds.has("ratio_proportion"), "level five ratios include word proportions")
			if group == "order_of_operations" and level == 4:
				_check(seen_forms.has("exact_division_chain"), "level four order of operations includes exact division chains")
			if group == "order_of_operations" and level == 5:
				_check(seen_forms.has("powers_first"), "level five order of operations includes exponent precedence")


func _validate_math_question(question: Dictionary, mode: String, level: int) -> void:
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
				var add_limit := 20 if level == 1 else 100
				_check(a <= add_limit and b <= add_limit and expected >= 0 and expected <= add_limit, "beginner addition/subtraction stays within its level range")
			if mode == "easy" and topic == "multiplication":
				var multiply_limit := 5 if level == 1 else 10
				_check(a <= multiply_limit and b <= multiply_limit and expected <= multiply_limit * multiply_limit, "easy multiplication respects its selected times-table range")
			if mode == "easy" and topic == "division":
				var divide_limit := 5 if level == 1 else 10
				_check(a <= divide_limit * divide_limit and b <= divide_limit and expected <= divide_limit, "easy division uses exact facts for its selected level")
		"fraction_of":
			var expected_fraction := int(question.numerator) * int(question.whole)
			_check(expected_fraction % int(question.denominator) == 0, "Easy fraction-of prompts have whole-number results")
			_check(answer_text == str(int(expected_fraction / int(question.denominator))), "fraction-of answer is correct")
			_check(int(question.whole) <= 80 and int(question.denominator) in [2, 4], "Easy fractions use familiar halves and quarters")
			if level == 1:
				_check(int(question.denominator) == 2, "level one fraction prompts use halves")
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
			var limit := 20 if level == 1 else 100
			_check(int(question.a) + 3 * int(question.b) == int(answer_text) and int(answer_text) <= limit, "number pattern fits its selected easy level")
		"fraction_operation":
			var numerator := 0
			var denominator := 1
			match str(question.operator):
				"+":
					numerator = int(question.left_num) * int(question.right_den) + int(question.right_num) * int(question.left_den)
					denominator = int(question.left_den) * int(question.right_den)
				"-":
					numerator = int(question.left_num) * int(question.right_den) - int(question.right_num) * int(question.left_den)
					denominator = int(question.left_den) * int(question.right_den)
				"×":
					numerator = int(question.left_num) * int(question.right_num)
					denominator = int(question.left_den) * int(question.right_den)
				_:
					numerator = int(question.left_num) * int(question.right_den)
					denominator = int(question.left_den) * int(question.right_num)
			_check(int(question.value_num) * denominator == numerator * int(question.value_den), "fraction operation is arithmetically correct")
			_check(answer_text == MathQuestion._format_fraction(numerator, denominator), "fraction answer is shown in simplest form")
		"money_sum", "measurement_sum":
			_check(int(question.a) + int(question.b) == int(answer_text), "measurement addition answer is correct")
		"unit_conversion":
			var input_value := int(question.input_value)
			var expected_conversion := 0
			match str(question.conversion):
				"hours_to_minutes":
					expected_conversion = input_value * 60
				"meters_to_cm":
					expected_conversion = input_value * 100
				"kilograms_to_g":
					expected_conversion = input_value * 1000
				"cm_to_m":
					expected_conversion = int(input_value / 100)
			_check(answer_text == str(expected_conversion), "measurement conversion answer is correct")
		"measurement_rate":
			var time_hours := int(question.time_hours)
			_check(time_hours > 0 and int(question.distance) % time_hours == 0, "distance divided by time is exact")
			_check(int(int(question.distance) / time_hours) == int(question.speed) and answer_text == str(int(question.speed)), "measurement rate answer is correct")
		"probability":
			_check(int(question.favorable) >= 0 and int(question.outcomes) > 0 and int(question.favorable) <= int(question.outcomes), "probability counts valid outcomes")
			_check(answer_text == MathQuestion._format_fraction(int(question.favorable), int(question.outcomes)), "probability is shown as the reduced favorable-to-total fraction")
		"statistic":
			var data: Array = question["values"]
			var ordered: Array = data.duplicate()
			ordered.sort()
			var expected_stat := 0
			match str(question.statistic):
				"mean":
					var total := 0
					for value: Variant in data:
						total += int(value)
					_check(total % data.size() == 0, "mean exercise has a whole-number average")
					expected_stat = int(total / data.size())
				"median":
					expected_stat = int(ordered[int(ordered.size() / 2)])
				"range":
					expected_stat = int(ordered[-1]) - int(ordered[0])
				_:
					var frequencies: Dictionary = {}
					for value: Variant in data:
						frequencies[int(value)] = int(frequencies.get(int(value), 0)) + 1
					var greatest_frequency := 0
					for value: Variant in frequencies:
						if int(frequencies[value]) > greatest_frequency:
							greatest_frequency = int(frequencies[value])
							expected_stat = int(value)
			_check(answer_text == str(expected_stat), "data statistic answer is correct")
		"geometry_shape_sides":
			_check(int(question.sides) == int(answer_text), "shape question counts the correct number of sides")
		"rectangle_perimeter":
			_check(int(question.a) * 2 + int(question.b) * 2 == int(answer_text), "rectangle perimeter uses both pairs of sides")
		"rectangle_area":
			_check(int(question.a) * int(question.b) == int(answer_text), "rectangle area multiplies length by width")
		"triangle_area":
			_check(int(question.a) * int(question.b) / 2 == int(answer_text), "triangle area is half base times height")
		"triangle_angle":
			_check(180 - int(question.a) - int(question.b) == int(answer_text), "triangle interior angles sum to 180 degrees")
		"circle_area_factor":
			_check(int(question.radius) * int(question.radius) == int(answer_text), "circle area divided by pi uses radius squared")
		"box_volume":
			_check(int(question.a) * int(question.b) * int(question.side_c) == int(answer_text), "box volume multiplies its three dimensions")
		"decimal_operation":
			var cents := int(question.a_cents) + int(question.b_cents) if str(question.operator) == "+" else int(question.a_cents) - int(question.b_cents)
			_check(answer_text == MathQuestion._format_decimal_cents(cents), "decimal operation keeps place values aligned")
		"decimal_operation_advanced":
			var left_scaled := int(question.left_scaled)
			var right_scaled := int(question.right_scaled)
			var answer_scale := int(question.answer_scale)
			var expected_numerator := left_scaled * right_scaled * answer_scale if str(question.operator) == "×" else left_scaled * int(question.right_scale) * answer_scale
			var expected_denominator := int(question.left_scale) * int(question.right_scale) if str(question.operator) == "×" else int(question.left_scale) * right_scaled
			_check(expected_denominator > 0 and expected_numerator % expected_denominator == 0, "decimal multiplication/division is exact")
			var expected_scaled := int(expected_numerator / expected_denominator)
			var decimal_places := 1 if answer_scale == 10 else 2
			_check(answer_text == MathQuestion._format_scaled_decimal(expected_scaled, decimal_places), "advanced decimal answer uses the correct place value")
		"percentage":
			var result := int(question.amount) * int(question.percent)
			_check(result % 100 == 0 and answer_text == str(int(result / 100)), "percentage-of-amount answer is exact")
		"percentage_change":
			var base_amount := int(question.base_amount)
			var percent_change := int(base_amount * int(question.percent) / 100)
			var expected_amount := base_amount - percent_change if str(question.change_type) == "discount" else base_amount + percent_change
			_check(int(question.amount_change) == percent_change and answer_text == str(expected_amount), "percentage increase/discount answer is correct")
		"percentage_reverse":
			_check(int(question.known_part) * 100 == int(question.value_num) * int(question.percent), "reverse-percent answer scales back to 100 percent")
		"ratio":
			_check(int(question.known) == int(question.a) * int(question.scale), "ratio known term uses the stated scale")
			_check(answer_text == str(int(question.b) * int(question.scale)), "ratio answer preserves equivalence")
		"unit_rate":
			_check(int(question.total_cost) == int(question.item_count) * int(question.unit_rate), "unit rate multiplies back to the stated total")
			_check(answer_text == str(int(question.unit_rate)), "unit rate answer is cost per one item")
		"ratio_proportion":
			_check(int(question.cups) * int(question.scale) == int(answer_text), "recipe proportion scales the ingredient amount")
			_check(int(question.base_servings) * int(question.scale) == int(question.target_servings), "recipe proportion scales servings by the same factor")
		"order_operations":
			var expected := int(question.a) + int(question.b) * int(question.c)
			if int(question.form) == 1:
				expected = (int(question.a) + int(question.b)) * int(question.c)
			elif int(question.form) == 2:
				expected = int(question.a) * int(question.b) - int(question.c)
			_check(answer_text == str(expected), "medium order-of-operations answer is correct")
		"order_operations_extended":
			var expected_extended := 0
			if str(question.form_type) == "exact_division_chain":
				_check(int(question.dividend) % int(question.divisor) == 0, "order-of-operations division is exact")
				expected_extended = int(question.addend) + int(int(question.dividend) / int(question.divisor)) * int(question.multiplier)
			else:
				expected_extended = int(pow(float(question.base), float(question.exponent))) + int(question.left_factor) * int(question.right_factor)
			_check(answer_text == str(expected_extended), "advanced order-of-operations answer respects precedence")
		"linear_equation":
			if str(question.form_type) == "both_sides":
				var left_result := int(question.left_coefficient) * int(question.solution) + int(question.left_constant)
				var right_result := int(question.right_coefficient) * int(question.solution) + int(question.right_constant)
				_check(left_result == right_result, "both-sides linear equation balances")
			else:
				_check(int(question.coefficient) * int(question.solution) + int(question.intercept) == int(question.result), "linear equation balances")
			_check(answer_text == str(int(question.solution)), "linear equation reveals the correct x")
		"quadratic":
			var root := int(answer_text)
			_check(root * root - int(question.sum_roots) * root + int(question.product_roots) == 0, "quadratic answer is a root")
			var requested := maxi(int(question.root_a), int(question.root_b)) if str(question.requested_root) == "larger" else mini(int(question.root_a), int(question.root_b))
			_check(root == requested, "quadratic answer matches the requested root")
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
			if str(question.form_type) == "triangle_ratio":
				_check(answer_text == MathQuestion._format_fraction(int(question.ratio_top), int(question.ratio_bottom)), "right-triangle trig ratio uses the correct sides")
			else:
				var special_values := {
					"sin_30": "1/2", "sin_45": "sqrt(2)/2", "sin_60": "sqrt(3)/2", "sin_90": "1",
					"cos_0": "1", "cos_30": "sqrt(3)/2", "cos_45": "sqrt(2)/2", "cos_60": "1/2",
					"tan_30": "sqrt(3)/3", "tan_45": "1", "tan_60": "sqrt(3)",
				}
				var special_key := "%s_%d" % [str(question.trig_function), int(question.angle)]
				_check(answer_text == str(special_values.get(special_key, "")), "special-angle trig value is exact")
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
	world.call("set_difficulty", 1)
	var gentle_gap := float(world.get("base_gap"))
	var level_one_speed := float(world.get("base_speed"))
	var level_one_spacing := float(world.get("pipe_spacing"))
	world.call("set_difficulty", 3)
	var steady_gap := float(world.get("base_gap"))
	_check(is_equal_approx(float(world.get("base_speed")), level_one_speed), "math challenge does not change flight speed")
	_check(is_equal_approx(float(world.get("pipe_spacing")), level_one_spacing), "math challenge does not change gate distance")
	world.call("set_difficulty", 5)
	var stretch_gap := float(world.get("base_gap"))
	_check(gentle_gap > steady_gap and steady_gap > stretch_gap, "five-point math challenge adjusts answer-lane clearance")
	var hardest_gap := stretch_gap
	world.call("set_speed_level", 1)
	var calm_speed := float(world.get("base_speed"))
	var calm_spacing := float(world.get("pipe_spacing"))
	_check(calm_speed < 193.0, "default pace is slower than the previous default flight speed")
	_check(calm_spacing > 532.0, "default pace spaces answer gates farther apart than the previous default")
	world.call("set_speed_level", 5)
	var fast_speed := float(world.get("base_speed"))
	var fast_spacing := float(world.get("pipe_spacing"))
	_check(calm_speed < fast_speed and calm_spacing > fast_spacing, "flight-pace options independently change speed and gate spacing")
	_check(is_equal_approx(float(world.get("base_gap")), hardest_gap), "changing flight pace does not change math difficulty")
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
	_check(SaveStore.record_run(4, true, "medium", "reading"), "reading starts its own subject best")
	_check(SaveStore.get_best_score("medium", "reading") == 4 and SaveStore.get_best_score("medium", "math") == 7, "subject bests stay separate at the same challenge band")
	_check(not SaveStore.record_run(3, true, "medium", "reading"), "a lower reading score is not a new subject best")
	_check(SaveStore.get_best_score() == 7, "overall best persists across modes")
	_check(SaveStore.get_games_played() == 6, "every run is counted")


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
	_check(bool((main.get("_title_screen") as Control).visible), "practice-area screen shows on boot")
	_check(main.get("_state") == "title", "game boots into the first practice-choice step")
	var practice_buttons: Dictionary = main.get("_practice_buttons")
	_check(practice_buttons.size() == 5, "first setup step offers math, reading, Russian, Spanish, and science")
	_check(not (practice_buttons["math"] as Button).disabled, "math knowledge pack is available")
	for area: String in ["reading", "russian", "spanish", "science"]:
		var pack_button: Button = practice_buttons[area]
		_check(not pack_button.disabled and pack_button.text == I18n.t("practice." + area), "%s is an enabled, clearly named learning pack" % area)
	var tap := InputEventMouseButton.new()
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	main.call("_unhandled_input", tap)
	_check(main.get("_state") == "title", "tapping the practice chooser does not accidentally start flight")
	main.call("_begin_from_title")
	_check(main.get("_state") == "topics" and bool((main.get("_topic_screen") as Control).visible), "choosing Math opens its own subject step")
	var topic_checkboxes: Dictionary = main.get("_topic_checkboxes")
	_check(topic_checkboxes.size() == MathQuestion.TOPIC_GROUPS.size(), "math subject step shows checkboxes for every selectable topic")
	_check(topic_checkboxes.has("addition") and topic_checkboxes.has("subtraction") and topic_checkboxes.has("multiplication") and topic_checkboxes.has("division"), "addition, subtraction, multiplication, and division are separate choices")
	var algebra_checkbox: CheckBox = topic_checkboxes["algebra"]
	_check(not algebra_checkbox.disabled, "all math topics can be chosen before the challenge step")
	main.call("_on_topic_toggled", true, "algebra")
	algebra_checkbox.set_pressed_no_signal(true)
	var selected_groups: Array = main.call("_selected_topic_groups")
	_check("algebra" in selected_groups and "fractions" in selected_groups, "multiple math topics can be selected together")
	main.call("_continue_to_difficulty")
	_check(main.get("_state") == "difficulty" and bool((main.get("_difficulty_screen") as Control).visible), "math topics lead to a separate challenge step")
	var difficulty_buttons: Dictionary = main.get("_difficulty_buttons")
	_check(difficulty_buttons.size() == 5, "challenge step offers exactly five difficulty choices")
	main.call("_set_difficulty_level", 1)
	_check(int(main.get("_selected_level")) == 1 and str(main.get("_selected_difficulty")) == "easy", "level one is the gentlest, age-friendly math band")
	_check(str((main.get("_difficulty_summary") as Label).text).contains("unlock at higher levels"), "difficulty step explains when selected advanced topics are unlocked")
	main.call("_show_topic_selection")
	_check(bool(algebra_checkbox.button_pressed), "going back preserves math subject choices")
	main.call("_continue_to_difficulty")
	main.call("_set_difficulty_level", 5)
	_check(int(main.get("_selected_level")) == 5 and str(main.get("_selected_difficulty")) == "hard", "level five selects the high-school challenge band")
	var topic_selection: Dictionary = main.get("_topic_selection")
	var saved_topic_selection: Dictionary = topic_selection.duplicate()
	topic_selection.clear()
	topic_selection["trigonometry"] = true
	_check(bool(main.call("_has_selected_topic_at_level", 5)) and not bool(main.call("_has_selected_topic_at_level", 4)), "lowering cannot silently replace a learner's only selected high-school subject")
	topic_selection.clear()
	for group: Variant in saved_topic_selection:
		topic_selection[group] = saved_topic_selection[group]
	main.call("_continue_to_speed")
	_check(main.get("_state") == "speed" and bool((main.get("_speed_screen") as Control).visible), "challenge selection leads to its own flight-pace step")
	var speed_buttons: Dictionary = main.get("_speed_buttons")
	_check(speed_buttons.size() == 5 and int(main.get("_selected_speed")) == 1, "flight pace has five choices and defaults to the calmest setting")
	_check(str((main.get("_speed_description") as Label).text).contains("widest spaces"), "default pace explains its slow flight and wider gate spacing")
	main.call("_set_speed_level", 2)
	main.call("_show_difficulty_selection")
	_check(main.get("_state") == "difficulty" and int(main.get("_selected_speed")) == 2, "back navigation preserves the separately chosen pace")
	main.call("_continue_to_speed")
	main.call("_start_from_setup")
	_check(main.get("_state") == "playing", "starting practice opens a fresh run after all four setup steps")
	var world: Node2D = main.get("_world")
	_check(world.get("state") == "ready", "Start Practice leaves the plane waiting for the learner's first tap")
	_check(world.get("difficulty") == "hard" and int(world.get("difficulty_level")) == 5, "five-point math challenge reaches the flight world")
	_check(int(world.get("speed_level")) == 2, "chosen flight pace reaches the flight world")
	_check("algebra" in world.get("selected_topic_groups"), "selected math topics reach the question generator")
	main.call("_flap_input")
	_check(world.get("state") == "playing", "the first tap after setup launches the paper plane")
	_check(bool((main.get("_question_bar") as Control).visible), "equation bar appears during flight")
	_check(str((main.get("_question_label") as Label).text).contains("?"), "equation bar shows the active question")
	_check(not str((main.get("_question_hint_label") as Label).text).is_empty(), "equation bar shows a learning hint")
	var hud_mode_text := str((main.get("_question_difficulty_label") as Label).text)
	_check(hud_mode_text.begins_with("LEVEL 5/5") and hud_mode_text.contains("HARD") and hud_mode_text.contains("MATH") and hud_mode_text.contains("LEISURELY") and hud_mode_text.split("·").size() == 5, "question bar identifies challenge level, learning area, topic, and pace")
	main.call("_set_paused", true)
	_check(get_tree().paused and main.get("_state") == "paused", "pause freezes the tree")
	main.call("_set_paused", false)
	_check(not get_tree().paused and main.get("_state") == "playing", "resume continues the run")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	_check(main.get("_state") == "over", "crash moves the game to the over state")
	await get_tree().create_timer(0.8).timeout
	_check(bool((main.get("_over_screen") as Control).visible), "crash screen presents the recovery choices")
	_check(main.get("_over_again_button") is Button and main.get("_over_easier_button") is Button and main.get("_over_home_button") is Button, "crash screen has Try Again, Lower Difficulty, and Home actions")
	(main.get("_over_easier_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(main.get("_state") == "playing" and int(main.get("_selected_level")) == 4 and int(world.get("score")) == 0, "Lower Difficulty decreases one step and starts a fresh run")
	_check(int(world.get("speed_level")) == 2, "Lower Difficulty keeps the independently chosen flight pace")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	await get_tree().create_timer(0.8).timeout
	(main.get("_over_home_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(main.get("_state") == "title" and bool((main.get("_title_screen") as Control).visible), "Home returns to practice-area selection")
	_check(bool(algebra_checkbox.button_pressed), "Home preserves checked content for later selection")
	main.call("_begin_from_title")
	main.call("_continue_to_difficulty")
	main.call("_set_difficulty_level", 1)
	main.call("_continue_to_speed")
	main.call("_set_speed_level", 1)
	main.call("_start_from_setup")
	main.call("_flap_input")
	_check(float(world.get("base_speed")) < 193.0 and float(world.get("pipe_spacing")) > 532.0, "calmest setup remains slower and more spacious than the previous default")
	world.set("plane_y", FlightWorld.GROUND_Y)
	world.call("step", 1.0 / 60.0)
	await get_tree().create_timer(0.8).timeout
	_check((main.get("_over_easier_button") as Button).disabled, "Lower Difficulty is disabled at level one")
	(main.get("_over_again_button") as Button).emit_signal("pressed")
	await get_tree().process_frame
	_check(main.get("_state") == "playing" and int(main.get("_selected_level")) == 1 and int(world.get("speed_level")) == 1, "Try Again restarts with the same challenge and flight pace")
	for area: String in ["reading", "russian", "spanish", "science"]:
		main.call("_show_title")
		var pack_button: Button = practice_buttons[area]
		pack_button.emit_signal("pressed")
		_check(main.get("_state") == "difficulty" and main.get("_selected_practice_area") == area and not bool((main.get("_topic_screen") as Control).visible), "%s skips the Math-only topic page and enters its level step" % area)
		_check(str((main.get("_difficulty_subtitle_label") as Label).text).contains("STEP 2 OF 3"), "%s uses the correct three-step setup count" % area)
		main.call("_show_topic_selection")
		_check(main.get("_state") == "title", "%s can navigate back to practice-area selection" % area)
		pack_button.emit_signal("pressed")
		main.call("_set_difficulty_level", 2)
		main.call("_continue_to_speed")
		_check(main.get("_state") == "speed" and str((main.get("_speed_subtitle_label") as Label).text).contains("STEP 3 OF 3"), "%s advances to its final setup step" % area)
		main.call("_set_speed_level", 1)
		main.call("_start_from_setup")
		_check(world.get("practice_area") == area and int(world.get("difficulty_level")) == 2 and int(world.get("speed_level")) == 1, "%s pack, challenge, and pace reach the flight world" % area)
		main.call("_flap_input")
		var learning_question: Dictionary = world.get("current_question")
		var topic_key := "topic." + str(learning_question.get("topic", ""))
		_check(str(learning_question.get("practice_area", "")) == area and not str(learning_question.get("expression", "")).is_empty(), "%s flight starts with a question from its own pack" % area)
		_check(I18n.t(topic_key) != topic_key and I18n.t(str(learning_question.get("hint_key", ""))) != str(learning_question.get("hint_key", "")), "%s question shows a translated topic and teaching hint" % area)
		_check(str((main.get("_question_difficulty_label") as Label).text).contains(area.to_upper()), "%s is identified in the in-flight question bar" % area)
		main.call("_return_to_home")
	main.call("_show_title")
	(practice_buttons["math"] as Button).emit_signal("pressed")
	main.call("_continue_to_difficulty")
	_check(str((main.get("_difficulty_subtitle_label") as Label).text).contains("STEP 3 OF 4") and str((main.get("_difficulty_description") as Label).text).contains("Build confidence"), "returning to Math restores its four-step flow and math description")
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
