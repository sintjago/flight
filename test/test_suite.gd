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
			_check(str(filtered.topic_group) == group, "level %d question follows the selected %s topic" % [level, group])
			_check(int(filtered.difficulty_level) == level, "question keeps the exact selected level")
		var math_history: Array = []
		var math_prompts: Dictionary = {}
		for _sample in 80:
			var generated: Dictionary = MathQuestion.generate_with_history(rng, level, ["addition"], math_history)
			var generated_expression := str(generated.expression)
			_check(not math_prompts.has(generated_expression), "Math level %d avoids repeated equation prompts" % level)
			math_prompts[generated_expression] = true
		_check(math_history.size() == 80 and math_prompts.size() == 80, "Math level %d maintains a generated no-repeat sequence" % level)
	var broad_math_topics: Array[Dictionary] = [
		{"level":4,"topic":"geometry"}, {"level":4,"topic":"probability"},
		{"level":5,"topic":"trigonometry"}, {"level":5,"topic":"probability"},
	]
	for item: Dictionary in broad_math_topics:
		var history: Array = []
		var prompts: Dictionary = {}
		for _sample in 120:
			var question: Dictionary = MathQuestion.generate_with_history(rng, int(item.level), [str(item.topic)], history)
			var expression := str(question.expression)
			_check(not prompts.has(expression), "Math %s level %d avoids prompt repeats" % [str(item.topic), int(item.level)])
			prompts[expression] = true
			if str(question.kind) == "probability":
				_check(int(question.favorable) >= 0 and int(question.favorable) <= int(question.outcomes), "generated probability has valid favorable outcomes")
				_check(str(question.answer) == MathQuestion._format_fraction(int(question.favorable), int(question.outcomes)), "generated probability answer matches its outcome counts")
				if int(item.level) >= 4:
					var probability_prompt := expression.to_lower()
					_check(probability_prompt.contains("coin") or probability_prompt.contains("spinner") or probability_prompt.contains("bag"), "advanced probability prompt describes its generated experiment")
			elif str(question.kind) == "pythagorean":
				_check(int(question.a) * int(question.a) + int(question.b) * int(question.b) == int(question.hypotenuse) * int(question.hypotenuse), "generated Pythagorean triple satisfies a² + b² = c²")
			elif str(question.kind) == "trigonometry" and str(question.get("form_type", "")) == "triangle_ratio":
				_check(str(question.answer) == MathQuestion._format_fraction(int(question.ratio_top), int(question.ratio_bottom)), "generated right-triangle ratio is reduced correctly")
		_check(history.size() == 120 and prompts.size() == 120, "Math %s level %d generates a large varied prompt run" % [str(item.topic), int(item.level)])
	var shape_history: Array = ["Sides in a triangle = ?", "Sides in a square = ?", "Sides in a pentagon = ?", "Sides in a hexagon = ?"]
	var shape_rng := RandomNumberGenerator.new()
	shape_rng.seed = 34918
	var next_shape: Dictionary = MathQuestion.generate_with_history(shape_rng, 1, ["geometry"], shape_history)
	_check(str(next_shape.expression) != "Sides in a hexagon = ?", "a fresh Math cycle does not immediately repeat its last prompt")
	for level: int in range(1, 6):
		_check(MathQuestion.topic_unlock_level("quadratics") == 5 or level < 5, "high-school topics have a level-five unlock")
	_check(MathQuestion.TRACK_IDS == ["math_1", "math_2", "math_3"], "Math offers exactly three ordered tracks")
	_check("addition" in MathQuestion.topic_groups_for_track("math_1") and "number_sense" in MathQuestion.topic_groups_for_track("math_1") and "algebra" not in MathQuestion.topic_groups_for_track("math_1"), "Math 1 bundles foundational arithmetic and number sense")
	_check("decimals" in MathQuestion.topic_groups_for_track("math_2") and "algebra" in MathQuestion.topic_groups_for_track("math_2") and "quadratics" not in MathQuestion.topic_groups_for_track("math_2"), "Math 2 bundles middle-school topics and introductory algebra")
	_check("quadratics" in MathQuestion.topic_groups_for_track("math_3") and "trigonometry" in MathQuestion.topic_groups_for_track("math_3"), "Math 3 bundles high-school algebra and trigonometry")
	for track_id: String in MathQuestion.TRACK_IDS:
		for level: int in range(1, 6):
			_check(not MathQuestion.available_topic_groups_for_track(track_id, level).is_empty(), "%s remains playable at challenge level %d" % [track_id, level])
	_check("trigonometry" not in MathQuestion.available_topic_groups_for_track("math_3", 4) and "trigonometry" in MathQuestion.available_topic_groups_for_track("math_3", 5), "Math 3 trigonometry unlocks at the stretch challenge")
	_test_extended_question_forms(rng)


func _test_learning_questions() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 58291
	_check(LearningQuestion.PRACTICE_AREAS.size() == 4, "four additional learner packs are available")
	for area: String in LearningQuestion.PRACTICE_AREAS:
		_check(I18n.t("practice." + area) != "practice." + area, "%s practice area has a learner-facing name" % area)
		for level: int in range(1, 6):
			var pool: Array = LearningQuestion.questions_for(area, level)
			_check(pool.size() >= 10, "%s level %d retains its curated starter questions" % [area, level])
			if area == "science" and level <= 2:
				for template: Dictionary in pool:
					var easy_prompt := str(template.get("expression", "")).to_lower()
					_check(not easy_prompt.contains("photosynthesis") and not easy_prompt.contains("transpiration"), "basic Science levels avoid specialist plant terms")
			var seen_prompts: Dictionary = {}
			for template: Dictionary in pool:
				var topic_key := "topic." + str(template.get("topic", ""))
				var hint_key := str(template.get("hint_key", ""))
				var prompt := str(template.get("expression", ""))
				_check(not prompt.is_empty() and not seen_prompts.has(prompt), "%s level %d curated prompts are present and varied" % [area, level])
				seen_prompts[prompt] = true
				_check(str(template.get("answer", "")) != str(template.get("distractor", "")), "%s level %d curated choices are distinct" % [area, level])
				_check(I18n.t(topic_key) != topic_key, "%s prompt topic is labeled" % area)
				_check(not hint_key.is_empty() and I18n.t(hint_key) != hint_key, "%s prompt has a translated learning hint" % area)
				if area in ["russian", "spanish"]:
					var language_topic := str(template.get("topic", ""))
					if language_topic.ends_with("_vocabulary"):
						_check(hint_key == "hint." + area + ".vocabulary", "single-word starter content uses its vocabulary hint")
					elif language_topic.ends_with("_phrases"):
						_check(hint_key == "hint." + area + ".phrases", "multiword starter content uses its phrase hint")
					if area == "russian" and level == 2:
						_check(language_topic in ["russian_vocabulary", "russian_phrases"], "Russian Level 2 starter content stays at the beginner scope")
				for text_value: String in [prompt, str(template.get("answer", "")), str(template.get("distractor", ""))]:
					for char_index: int in text_value.length():
						_check(ThemeDB.fallback_font.has_char(text_value.unicode_at(char_index)), "%s curated lesson characters are supported" % area)
				for answer_text: String in [str(template.get("answer", "")), str(template.get("distractor", ""))]:
					var font_size := FlightWorld.fit_answer_font_size(answer_text, 104.0)
					var measured_width := ThemeDB.fallback_font.get_string_size(answer_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
					_check(measured_width <= 104.0, "%s curated gate answer '%s' fits at %.1f px" % [area, answer_text, measured_width])
			var history: Array = []
			var generated_prompts: Dictionary = {}
			var procedural_count := 0
			var advanced_language_kinds: Dictionary = {}
			var reading_skill_kinds: Dictionary = {}
			var beginner_science_kinds: Dictionary = {}
			var high_school_science_topics: Dictionary = {}
			for _sample in 160:
				var question: Dictionary = LearningQuestion.generate_with_history(rng, area, level, history)
				var answers: Array[String] = [str(question.upper_answer), str(question.lower_answer)]
				var correct_option := str(question.upper_answer) if question.correct_lane == "upper" else str(question.lower_answer)
				var generated_prompt := str(question.expression)
				var generator_kind := str(question.get("generator_kind", ""))
				if area == "russian" and level == 2 and generator_kind.begins_with("generated_"):
					_check(generator_kind == "generated_russian_translation", "Russian Level 2 generated practice stays with beginner translations")
				if generator_kind.begins_with("generated_"):
					procedural_count += 1
				if generator_kind in ["generated_russian_aspect", "generated_russian_conditional", "generated_spanish_subjunctive", "generated_spanish_conditional", "generated_spanish_formal_address"]:
					advanced_language_kinds[generator_kind] = true
				if area == "reading" and generator_kind in ["generated_reading_inference", "generated_reading_main_idea", "generated_reading_evidence", "generated_reading_author_purpose"]:
					reading_skill_kinds[generator_kind] = true
				if area == "science" and level == 1 and generator_kind in ["generated_science_state", "generated_science_plant_part"]:
					beginner_science_kinds[generator_kind] = true
				if area == "russian" and str(question.get("source_word", "")) == "ехать":
					_check(str(question.answer) == "go by vehicle" or generated_prompt.contains("go by vehicle"), "Russian ехать is cued as travel by vehicle")
				if area == "science" and level == 5 and generator_kind.begins_with("generated_science_"):
					var science_topic := str(question.get("topic", ""))
					_check(science_topic in ["science_biology", "science_chemistry", "science_physics", "science_earth"], "Level 5 Science generated content stays in advanced topics")
					high_school_science_topics[science_topic] = true
				_check(not generated_prompts.has(generated_prompt), "%s level %d does not repeat generated prompts during a run" % [area, level])
				generated_prompts[generated_prompt] = true
				_check(str(question.practice_area) == area and int(question.difficulty_level) == level, "%s generated question keeps its pack and selected level" % area)
				_check(str(question.difficulty) == MathQuestion.band_for_level(level), "%s question records the matching score band" % area)
				_check(answers[0] != answers[1] and answers.count(str(question.answer)) == 1, "%s generated gate has two choices and one correct answer" % area)
				_check(correct_option == str(question.answer), "%s generated correct lane matches the teaching answer" % area)
				var topic_key := "topic." + str(question.topic)
				_check(I18n.t(topic_key) != topic_key, "%s generated topic has a learner-facing label" % area)
				_check(I18n.t(str(question.hint_key)) != str(question.hint_key), "%s generated prompt has a teaching hint" % area)
				for answer_text: String in answers:
					var font_size := FlightWorld.fit_answer_font_size(answer_text, 104.0)
					var measured_width := ThemeDB.fallback_font.get_string_size(answer_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
					_check(measured_width <= 104.0, "%s generated gate answer '%s' fits at %.1f px" % [area, answer_text, measured_width])
				match str(question.get("generator_kind", "")):
					"generated_science_speed":
						_check(int(question.distance) == int(question.expected_speed) * int(question.time_hours), "generated Science speed answers use distance ÷ time")
					"generated_science_force":
						_check(int(question.expected_force) == int(question.mass) * int(question.acceleration), "generated Science force answers use mass × acceleration")
					"generated_science_density":
						_check(int(question.mass) == int(question.expected_density) * int(question.volume), "generated Science density answers use mass ÷ volume")
					"generated_science_voltage":
						_check(int(question.expected_voltage) == int(question.current) * int(question.resistance), "generated Science voltage answers use current × resistance")
					"generated_science_power":
						_check(int(question.work) == int(question.expected_power) * int(question.time), "generated Science power answers use work ÷ time")
					"generated_spanish_conjugation":
						var forms: Array = question.get("conjugation_forms", [])
						_check(forms.has(str(question.answer)) and forms.has(str(question.distractor)) and question.answer != question.distractor, "Spanish conjugation choices are distinct valid verb forms")
					"generated_spanish_formal_address":
						var forms: Array = question.get("conjugation_forms", [])
						_check(str(question.get("pronoun", "")) == "usted" and int(question.get("subject_index", -1)) == 2 and str(forms[2]) == str(question.answer) and str(forms[1]) == str(question.distractor), "Spanish formal usted uses the él/ella verb form")
					"generated_russian_translation", "generated_spanish_translation":
						var source_text := str(question.get("source_word", ""))
						var lexical_type := "phrase" if source_text.contains(" ") else "vocabulary"
						var language_category := "phrases" if lexical_type == "phrase" else "vocabulary"
						_check(str(question.get("lexical_type", "")) == lexical_type and str(question.topic) == area + "_" + language_category and str(question.hint_key) == "hint." + area + "." + language_category, "Language topic and hint follow the target-language word or phrase")
						if area == "russian" and level == 2:
							var beginner_words: Array[String] = ["привет", "пока", "да", "нет", "мама", "папа", "кот", "собака", "вода", "хлеб", "дом", "книга", "пожалуйста", "спасибо", "один", "два", "красный", "синий", "яблоко", "молоко", "школа", "друг", "маленький", "большой"]
							_check(beginner_words.has(source_text), "Russian Level 2 uses only familiar beginner vocabulary")
					"generated_spanish_subjunctive", "generated_spanish_conditional":
						var forms: Array = question.get("conjugation_forms", [])
						var indicative_forms: Array = question.get("indicative_forms", [])
						var subject_index := int(question.get("subject_index", -1))
						_check(subject_index >= 0 and subject_index < forms.size() and subject_index < indicative_forms.size(), "Spanish advanced question records a valid subject index")
						if subject_index >= 0 and subject_index < forms.size() and subject_index < indicative_forms.size():
							_check(str(forms[subject_index]) == str(question.answer), "Spanish answer matches the selected subject and target tense")
							_check(str(indicative_forms[subject_index]) == str(question.distractor), "Spanish distractor matches the same subject in the indicative")
						if generator_kind == "generated_spanish_subjunctive":
							_check(str(question.get("tense", "")) == "subjunctive", "Spanish wish clauses use the subjunctive metadata")
						elif generator_kind == "generated_spanish_conditional":
							_check(str(question.get("tense", "")) == "conditional", "Spanish would-forms use conditional metadata")
					"generated_russian_aspect":
						_check(str(question.answer) == str(question.perfective) and str(question.distractor) == str(question.imperfective), "Russian aspect choices match the completed and ongoing verb forms")
					"generated_russian_conditional":
						_check(str(question.get("hint_key", "")) == "hint.russian.conditional", "Russian conditional questions provide the correct teaching hint")
					"generated_reading_detail":
						for story_name: String in ["Mia", "Leo", "Ava", "Noah", "Ivy", "Max", "Zoe", "Ben"]:
							for past_verb: String in ["found", "drew", "carried", "opened", "packed", "planted", "borrowed", "painted", "chose", "fixed"]:
								_check(not generated_prompt.contains("did %s %s" % [story_name, past_verb]), "Reading comprehension uses a base verb after did")
								_check(not generated_prompt.contains("%s What did %s" % [story_name, story_name]), "Reading comprehension avoids duplicated-name question stems")
					"generated_reading_vocabulary":
						var relation := str(question.get("relation", ""))
						var expected_answer := str(question.synonym) if relation == "synonym" else str(question.opposite)
						var expected_distractor := str(question.opposite) if relation == "synonym" else str(question.synonym)
						_check(relation in ["synonym", "antonym"] and str(question.answer) == expected_answer and str(question.distractor) == expected_distractor, "Reading synonym and antonym answers match their selected relation")
					"generated_reading_prefix":
						_check(generated_prompt.contains("prefix ") or generated_prompt.contains("In '"), "Reading prefix prompts identify the prefix or its example word")
						_check(not generated_prompt.to_lower().contains("matches re at the start"), "Reading prefix prompts use natural wording")
					"generated_science_plant_part":
						_check(str(question.answer) == str(question.plant_part) and generated_prompt.contains(str(question.plant_job)), "Science plant question and answer match the plant function")
						_check(generated_prompt.contains("can ") or generated_prompt.contains("is used to") or generated_prompt.contains("will "), "Science plant question stem is grammatical")
					"generated_science_state":
						_check(str(question.answer) == str(question.science_state) and not generated_prompt.to_lower().contains("room temperature"), "Science state question avoids an incorrect ice-at-room-temperature claim")
				if area == "science" and level <= 2:
					var easy_prompt := generated_prompt.to_lower()
					_check(not easy_prompt.contains("photosynthesis") and not easy_prompt.contains("transpiration"), "basic generated Science avoids specialist plant terms")
				if area == "reading" and level == 1:
					for advanced_word: String in ["reluctant", "arduous", "scarce", "precise"]:
						_check(not generated_prompt.to_lower().contains(advanced_word), "beginner Reading excludes advanced vocabulary: %s" % advanced_word)
			_check(history.size() == 160 and generated_prompts.size() == 160, "%s level %d maintains a large no-repeat generated run" % [area, level])
			_check(procedural_count >= 100, "%s level %d relies on procedural questions rather than only the starter bank" % [area, level])
			if area == "russian" and level == 5:
				_check(advanced_language_kinds.has("generated_russian_aspect") and advanced_language_kinds.has("generated_russian_conditional"), "Level 5 Russian practices verb aspect and conditional meaning")
			if area == "spanish" and level == 5:
				_check(advanced_language_kinds.has("generated_spanish_subjunctive") and advanced_language_kinds.has("generated_spanish_conditional"), "Level 5 Spanish practices the subjunctive and conditional forms")
			if area == "spanish" and level == 4:
				_check(advanced_language_kinds.has("generated_spanish_conditional") and advanced_language_kinds.has("generated_spanish_formal_address"), "Level 4 Spanish practices conditional forms and formal address")
			if area == "reading" and level == 3:
				_check(reading_skill_kinds.has("generated_reading_inference") and reading_skill_kinds.has("generated_reading_main_idea"), "Level 3 Reading practices inference and main idea")
			if area == "reading" and level == 4:
				_check(reading_skill_kinds.has("generated_reading_evidence"), "Level 4 Reading practices text evidence")
			if area == "reading" and level == 5:
				_check(reading_skill_kinds.has("generated_reading_author_purpose"), "Level 5 Reading practices author purpose and theme")
			if area == "science" and level == 1:
				_check(beginner_science_kinds.has("generated_science_state") and beginner_science_kinds.has("generated_science_plant_part"), "Level 1 Science includes everyday matter and plant-part questions")
			if area == "science" and level == 5:
				_check(high_school_science_topics.has("science_biology") and high_school_science_topics.has("science_chemistry") and high_school_science_topics.has("science_physics"), "Level 5 Science samples biology, chemistry, and physics")


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
	math_world.call("set_selected_topics", ["addition"])
	math_world.call("set_difficulty", 2)
	var math_flight_prompts: Dictionary = {}
	for index in 80:
		math_world.call("_spawn_gate", 2000.0 + float(index) * 500.0)
		var math_question: Dictionary = math_world.get("current_question")
		var math_prompt := str(math_question.get("expression", ""))
		_check(not math_flight_prompts.has(math_prompt), "Math flight does not repeat generated addition before the cycle ends")
		math_flight_prompts[math_prompt] = true
	_check(math_flight_prompts.size() == 80, "Math flight draws many generated equations from its selected topic")
	math_world.call("_start_run")
	var math_history_state: Dictionary = math_world.get("_math_prompt_history")
	var active_math_history: Array = math_history_state.get("2:addition", [])
	_check(active_math_history.size() == 1, "starting a Math run resets the equation-prompt history")
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

	var rotation_cases: Array[Dictionary] = [
		{"area": "reading", "level": 3},
		{"area": "russian", "level": 3},
		{"area": "spanish", "level": 4},
		{"area": "science", "level": 1},
	]
	var seed_value := 41000
	for item: Dictionary in rotation_cases:
		var world := FlightWorld.new()
		add_child(world)
		world.rng.seed = seed_value
		seed_value += 1
		world.call("set_practice_area", str(item.area))
		world.call("set_difficulty", int(item.level))
		var seen_categories: Dictionary = {}
		var previous_category := ""
		for index in 24:
			world.call("_spawn_gate", 2000.0 + float(index) * 500.0)
			var question: Dictionary = world.get("current_question")
			var category := str(world.call("_learning_rotation_category", question))
			if not previous_category.is_empty():
				_check(category != previous_category, "%s rotates question categories when alternatives exist" % str(item.area))
			seen_categories[category] = true
			previous_category = category
		_check(seen_categories.size() > 1, "%s learning engine exposes multiple categories at the sampled challenge" % str(item.area))
		world.call("_start_run")
		var category_state: Dictionary = world.get("_last_learning_category_by_key")
		_check(category_state.size() == 1, "starting a new %s run resets question-category history" % str(item.area))
		remove_child(world)
		world.free()


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
				if group == "statistics" and level == 3:
					for data_value: Variant in question.get("values", []):
						_check(int(data_value) >= 0, "level three statistics stay nonnegative before integers unlock")
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
			if group == "fractions" and level == 1:
				_check(seen_kinds.has("fraction_of") and not seen_kinds.has("fraction_compare"), "level one fractions stay with simple halves")
			if group == "number_sense" and level <= 3:
				_check(seen_kinds.has("place_value") and seen_kinds.has("number_pattern"), "level %d number sense includes place value and patterns" % level)
			if group == "number_sense" and level == 4:
				_check(seen_kinds.has("rounding"), "level four number sense teaches rounding")
			if group == "number_sense" and level == 5:
				_check(seen_kinds.has("scientific_notation"), "level five number sense teaches scientific notation")
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
			if str(question.get("place_name", "")) == "hundreds":
				var hundreds_place := int(question.b)
				var digit := int(int(question.a) / hundreds_place) % 10
				_check(int(question.a) >= 1000 and answer_text == str(digit), "higher place-value prompt identifies the hundreds digit")
			else:
				_check(int(question.a) >= 10 and int(question.a) <= 99 and answer_text == str(int(int(question.a) / 10)), "place-value prompt identifies the tens digit")
		"number_pattern":
			var limit := 20 if level == 1 else (100 if level == 2 else 1000)
			_check(int(question.a) + 3 * int(question.b) == int(answer_text) and int(answer_text) <= limit, "number pattern fits its selected easy level")
		"rounding":
			var rounding_step := int(question.rounding_place)
			var rounded_value := roundi(float(question.a) / float(rounding_step)) * rounding_step
			_check(rounding_step in [100, 1000] and int(question.rounded_value) == rounded_value and answer_text == str(rounded_value), "rounding question uses the nearest requested place")
		"scientific_notation":
			var coefficient_tenths := int(question.coefficient_tenths)
			var exponent := int(question.exponent)
			var standard_value := coefficient_tenths * int(pow(10.0, float(exponent - 1)))
			_check(coefficient_tenths >= 11 and coefficient_tenths <= 99 and exponent >= 3 and exponent <= 6 and int(question.standard_value) == standard_value and answer_text == str(standard_value), "scientific notation expands the coefficient and power correctly")
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
	var legacy_save := {
		"version": 5,
		"best_score": 9,
		"best_scores": {"easy": 0, "medium": 9, "hard": 0},
		"games_played": 3,
	}
	var legacy_file := FileAccess.open(SaveStore.SAVE_PATH, FileAccess.WRITE)
	_check(legacy_file != null, "legacy-save migration test can write its isolated fixture")
	if legacy_file != null:
		legacy_file.store_string(JSON.stringify(legacy_save))
		legacy_file.close()
		SaveStore.call("_load")
		_check(SaveStore.get_best_score() == 9 and SaveStore.get_games_played() == 3, "new economy fields preserve a version-five save's scores and run count")
		_check(SaveStore.get_coins() == 0 and SaveStore.get_selected_plane() == "paper" and SaveStore.owns_plane("paper") and SaveStore.get_selected_cheer() == "nice_work" and SaveStore.owns_cheer("nice_work"), "older saves safely receive the free starter plane and default cheer")
		_check(int(SaveStore.get("_data").get("version", 0)) == SaveStore.SAVE_VERSION, "loaded saves adopt the current schema version")
	SaveStore.set("_data", SaveStore.call("_default_data"))
	_check(not SaveStore.purchase_plane("sky"), "an unaffordable plane cannot be purchased")
	_check(SaveStore.add_coins(9) == 9 and not SaveStore.purchase_plane("sky"), "coins persist while an insufficient wallet cannot unlock a plane")
	_check(SaveStore.add_coins(1) == 10 and SaveStore.purchase_plane("sky"), "ten earned coins unlock the ten-coin plane")
	_check(SaveStore.get_coins() == 0 and SaveStore.owns_plane("sky") and SaveStore.get_selected_plane() == "sky", "buying a plane deducts its price, records ownership, and equips it")
	_check(not SaveStore.purchase_plane("sky") and not SaveStore.select_plane("coral"), "owned planes are not charged twice and locked planes cannot be selected")
	_check(SaveStore.select_plane("paper"), "the free starter plane remains selectable after buying another skin")
	_check(SaveStore.add_coins(15) == 15 and SaveStore.purchase_plane("kite_glider"), "a distinct paper-aircraft design can be bought with earned coins")
	_check(SaveStore.get_coins() == 0 and SaveStore.owns_plane("kite_glider") and SaveStore.get_selected_plane() == "kite_glider", "new aircraft purchase deducts its cost and equips the saved design")
	_check(SaveStore.add_coins(10) == 10 and SaveStore.purchase_cheer("banzai"), "the Banzai celebration is an earnable coin unlock")
	_check(SaveStore.get_coins() == 0 and SaveStore.owns_cheer("banzai") and SaveStore.get_selected_cheer() == "banzai", "purchasing a cheer deducts its price and selects it")
	_check(not SaveStore.purchase_cheer("banzai") and not SaveStore.select_cheer("excelente"), "owned cheers cannot be charged twice and locked cheers cannot be selected")
	SaveStore.call("_load")
	_check(SaveStore.owns_plane("sky") and SaveStore.owns_plane("kite_glider") and SaveStore.get_selected_plane() == "kite_glider" and SaveStore.owns_cheer("banzai") and SaveStore.get_selected_cheer() == "banzai" and SaveStore.get_coins() == 0, "wallet, distinct plane and cheer ownership, and selections survive a save reload")
	SaveStore.set("_data", SaveStore.call("_default_data"))


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
	var hangar_button: Button = main.get("_title_hangar_button")
	_check(hangar_button != null and hangar_button.text.contains("0 COINS"), "title screen shows the gameplay wallet and Hangar entry")
	if hangar_button != null:
		hangar_button.emit_signal("pressed")
		var hangar_screen: Control = main.get("_hangar_screen")
		var hangar_buttons: Dictionary = main.get("_hangar_buttons")
		var hangar_cheer_buttons: Dictionary = main.get("_hangar_cheer_buttons")
		_check(main.get("_state") == "hangar" and hangar_screen.visible and hangar_buttons.size() == SaveStore.PLANE_IDS.size() and hangar_buttons.size() == 7, "Hangar opens with seven aircraft, including three distinct new silhouettes")
		_check(hangar_cheer_buttons.size() == SaveStore.CHEER_IDS.size() and hangar_cheer_buttons.size() == 3, "Hangar includes the default, Banzai, and Spanish celebration cards")
		var sky_entry: Dictionary = hangar_buttons.get("sky", {})
		(sky_entry.get("button") as Button).emit_signal("pressed")
		_check(SaveStore.get_coins() == 0 and not SaveStore.owns_plane("sky") and str((main.get("_hangar_status_label") as Label).text).contains("10 more coins"), "Hangar explains an insufficient wallet without charging it")
		SaveStore.add_coins(10)
		main.call("_update_hangar")
		(sky_entry.get("button") as Button).emit_signal("pressed")
		_check(SaveStore.owns_plane("sky") and SaveStore.get_selected_plane() == "sky" and main.get("_world").get("selected_plane_id") == "sky", "buying in Hangar equips the saved cosmetic plane in flight")
		var paper_entry: Dictionary = hangar_buttons.get("paper", {})
		(paper_entry.get("button") as Button).emit_signal("pressed")
		_check(SaveStore.get_selected_plane() == "paper" and main.get("_world").get("selected_plane_id") == "paper", "Hangar can re-equip the free starter plane")
		var cheers_tab := hangar_screen.find_child("HangarCheersTab", true, false) as Button
		var cheers_row := hangar_screen.find_child("HangarCheerChoices", true, false) as Control
		_check(cheers_tab != null and cheers_row != null, "Hangar exposes a separate cheers collection tab")
		if cheers_tab != null:
			cheers_tab.emit_signal("pressed")
		var banzai_entry: Dictionary = hangar_cheer_buttons.get("banzai", {})
		var banzai_button := banzai_entry.get("button") as Button
		_check(cheers_row != null and cheers_row.visible and banzai_button != null and str((banzai_button.find_child("HangarCheerPreview_banzai", true, false) as Label).text) == "Banzai!", "cheer tab previews the exact correct-answer callout")
		_check(I18n.t("cheer.callout.excelente") == "¡Excelente!" and SaveStore.get_cheer_cost("excelente") == 15, "Spanish celebration keeps its exact accented wording and coin price")
		if banzai_button != null:
			banzai_button.emit_signal("pressed")
			_check(not SaveStore.owns_cheer("banzai") and str((main.get("_hangar_status_label") as Label).text).contains("10 more coins"), "locked cheers cannot be equipped without their coin cost")
		SaveStore.add_coins(10)
		main.call("_update_hangar")
		if banzai_button != null:
			banzai_button.emit_signal("pressed")
		_check(SaveStore.owns_cheer("banzai") and SaveStore.get_selected_cheer() == "banzai" and SaveStore.get_coins() == 0, "earned coins unlock and equip the Banzai cheer")
		var planes_tab := hangar_screen.find_child("HangarPlanesTab", true, false) as Button
		if planes_tab != null:
			planes_tab.emit_signal("pressed")
		SaveStore.add_coins(15)
		main.call("_update_hangar")
		var kite_entry: Dictionary = hangar_buttons.get("kite_glider", {})
		(kite_entry.get("button") as Button).emit_signal("pressed")
		_check(SaveStore.owns_plane("kite_glider") and SaveStore.get_selected_plane() == "kite_glider" and main.get("_world").get("selected_plane_id") == "kite_glider", "buying a new Hangar design selects its distinct sprite without changing gameplay state")
		(paper_entry.get("button") as Button).emit_signal("pressed")
		var back_button := hangar_screen.find_child("HangarBackButton", true, false) as Button
		_check(back_button != null, "Hangar provides a return-to-Home action")
		if back_button != null:
			back_button.emit_signal("pressed")
		_check(main.get("_state") == "title" and (main.get("_title_screen") as Control).visible, "leaving Hangar returns to the practice selector")
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
	_check(main.get("_state") == "topics" and bool((main.get("_topic_screen") as Control).visible), "choosing Math opens its own track step")
	var track_buttons: Dictionary = main.get("_track_buttons")
	_check(track_buttons.size() == 3 and track_buttons.has("math_1") and track_buttons.has("math_2") and track_buttons.has("math_3"), "Math replaces the long checklist with three track cards")
	_check(str(main.get("_selected_math_track")) == "math_1", "Math 1 Foundations is the default track")
	(track_buttons["math_2"] as Button).emit_signal("pressed")
	_check(str(main.get("_selected_math_track")) == "math_2", "choosing a Math 2 card selects one track")
	var selected_groups: Array = main.call("_selected_topic_groups")
	_check("decimals" in selected_groups and "algebra" in selected_groups and "fractions" in selected_groups and "addition" not in selected_groups, "Math 2 selects its bundled middle-school topics without a checkbox list")
	main.call("_continue_to_difficulty")
	_check(main.get("_state") == "difficulty" and bool((main.get("_difficulty_screen") as Control).visible), "the selected Math track leads to a separate challenge step")
	var difficulty_buttons: Dictionary = main.get("_difficulty_buttons")
	_check(difficulty_buttons.size() == 5, "challenge step offers exactly five difficulty choices")
	main.call("_set_difficulty_level", 1)
	_check(int(main.get("_selected_level")) == 1 and str(main.get("_selected_difficulty")) == "easy", "level one is the gentlest, age-friendly math band")
	_check(str((main.get("_difficulty_summary") as Label).text).contains("more unlock as your challenge rises"), "difficulty step explains track topics unlock with challenge")
	main.call("_show_topic_selection")
	_check(str(main.get("_selected_math_track")) == "math_2", "going back preserves the selected Math track")
	(track_buttons["math_3"] as Button).emit_signal("pressed")
	main.call("_continue_to_difficulty")
	main.call("_set_difficulty_level", 5)
	_check(int(main.get("_selected_level")) == 5 and str(main.get("_selected_difficulty")) == "hard" and str(main.get("_selected_math_track")) == "math_3", "Math 3 keeps the independent level-five challenge selection")
	selected_groups = main.call("_selected_topic_groups")
	_check("trigonometry" in selected_groups and "quadratics" in selected_groups and "addition" not in selected_groups, "Math 3 selects high-school subjects as one bundled track")
	_check(bool(main.call("_has_selected_topic_at_level", 5)) and bool(main.call("_has_selected_topic_at_level", 4)), "lowering Math 3 challenge preserves its track and uses topics available at that level")
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
	_check("algebra" in world.get("selected_topic_groups") and "trigonometry" in world.get("selected_topic_groups") and "addition" not in world.get("selected_topic_groups"), "the selected Math 3 track reaches the question generator")
	main.call("_flap_input")
	_check(world.get("state") == "playing", "the first tap after setup launches the paper plane")
	_check(bool((main.get("_question_bar") as Control).visible), "equation bar appears during flight")
	_check(str((main.get("_question_label") as Label).text).contains("?"), "equation bar shows the active question")
	_check(not str((main.get("_question_hint_label") as Label).text).is_empty(), "equation bar shows a learning hint")
	var reward_gates: Array = world.get("pipes")
	_check(not reward_gates.is_empty(), "active run exposes a real answer gate to pass")
	if not reward_gates.is_empty():
		var reward_gate: Dictionary = reward_gates[0].duplicate(true)
		reward_gate.x = FlightWorld.PLANE_X - 22.0
		_set_pipes(world, [reward_gate])
		var reward_y := float(reward_gate.upper_y) if str(reward_gate.correct_lane) == "upper" else float(reward_gate.lower_y)
		world.set("gravity", 0.0)
		world.set("plane_y", reward_y)
		world.set("plane_vy", 0.0)
		for _attempt in range(120):
			if int(world.get("score")) > 0:
				break
			world.call("step", 1.0 / 60.0)
		var after_pass_gates: Array = world.get("pipes")
		var gate_detail := "score=%d state=%s reason=%s plane_y=%.1f gate_count=%d" % [int(world.get("score")), str(world.get("state")), str(world.get("failure_reason")), float(world.get("plane_y")), after_pass_gates.size()]
		_check(int(world.get("score")) == 1 and SaveStore.get_coins() == 1 and int(main.get("_coins_earned_this_run")) == 1, "passing the correct answer gate adds one saved gameplay coin (" + gate_detail + ")")
		_check(bool((main.get("_cheer_label") as Label).visible) and str((main.get("_cheer_label") as Label).text) == "Banzai!", "a correctly passed answer gate displays the selected saved celebration phrase")
		world.call("step", 1.0 / 60.0)
		_check(int(world.get("score")) == 1 and SaveStore.get_coins() == 1 and int(main.get("_coins_earned_this_run")) == 1, "one passed gate cannot award the same coin twice")
	_check(str((main.get("_coin_label") as Label).text).contains("COINS · 1"), "in-flight HUD shows the updated wallet balance")
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
	_check(str((main.get("_over_coins_label") as Label).text).contains("+1") and str((main.get("_over_coins_label") as Label).text).contains("WALLET: 1"), "crash screen reports this flight's earned coins and wallet total")
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
	_check(str(main.get("_selected_math_track")) == "math_3", "Home preserves the selected Math track for later practice")
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
	_check(str((main.get("_difficulty_subtitle_label") as Label).text).contains("STEP 3 OF 4") and str((main.get("_difficulty_description") as Label).text).contains("Gentle questions"), "returning to Math restores its four-step flow and challenge description")
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
