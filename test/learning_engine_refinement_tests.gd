extends RefCounted

const MathQuestion = preload("res://scripts/flight/math_question.gd")
const LearningQuestion = preload("res://scripts/flight/learning_question.gd")
const QuestionGenerator = preload("res://scripts/flight/learning_question_generator.gd")


static func run(checker: Callable) -> void:
	_test_math(checker)
	_test_reading(checker)
	_test_russian_and_spanish(checker)
	_test_science(checker)


static func _check(checker: Callable, condition: bool, message: String) -> void:
	checker.call(condition, message)


static func _check_learning_choices(checker: Callable, question: Dictionary, label: String) -> void:
	var upper := str(question.get("upper_answer", ""))
	var lower := str(question.get("lower_answer", ""))
	var answer := str(question.get("answer", ""))
	_check(checker, not upper.is_empty() and not lower.is_empty() and upper != lower and [upper, lower].count(answer) == 1, "%s keeps two distinct choices and exactly one correct answer" % label)
	_check(checker, I18n.t(str(question.get("hint_key", ""))) != str(question.get("hint_key", "")), "%s retains a translated teaching hint" % label)


static func _test_math(checker: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62051
	var level_one_kinds: Dictionary = {}
	for _sample in 100:
		var beginner_measurement: Dictionary = MathQuestion.generate(rng, 1, ["measurement"])
		level_one_kinds[str(beginner_measurement.kind)] = true
		_check(checker, str(beginner_measurement.hint_key) == "hint.measurement_addition", "Math 1 measurement addition uses a matching-unit hint")
	_check(checker, level_one_kinds.has("money_sum") and level_one_kinds.has("measurement_sum") and not level_one_kinds.has("unit_conversion"), "Math Level 1 keeps measurement within familiar matched-unit addition")

	var conversions: Dictionary = {}
	for _sample in 120:
		var conversion: Dictionary = MathQuestion.generate(rng, 2, ["measurement"])
		conversions[str(conversion.get("conversion", ""))] = true
		_check(checker, str(conversion.kind) == "unit_conversion" and str(conversion.hint_key) == "hint.measurement_conversion", "Math Level 2 conversion explains its conversion factor")
	_check(checker, conversions.has("meters_to_cm") and conversions.has("kilograms_to_g") and conversions.has("hours_to_minutes") and conversions.has("cm_to_m"), "Math Level 2 includes familiar metric/time conversions")

	for _sample in 80:
		var rate: Dictionary = MathQuestion.generate(rng, 3, ["measurement"])
		_check(checker, str(rate.kind) == "measurement_rate" and str(rate.hint_key) == "hint.measurement_rate", "Math Level 3 rate questions explain distance divided by time")
		_check(checker, int(rate.distance) == int(rate.speed) * int(rate.time_hours), "Math measurement rate has consistent distance, speed, and time")

	var signed_multiplications := 0
	for level: int in [4, 5]:
		for _sample in 80:
			var integer_product: Dictionary = MathQuestion.generate(rng, level, ["multiplication"])
			if int(integer_product.a) < 0 or int(integer_product.b) < 0:
				signed_multiplications += 1
				_check(checker, str(integer_product.hint_key) == "hint.signed_multiplication", "Signed multiplication explains sign rules")
	_check(checker, signed_multiplications > 0, "Higher Math challenges generate signed multiplication practice")

	for _sample in 80:
		var triangle: Dictionary = MathQuestion.generate(rng, 4, ["geometry"])
		var hypotenuse := int(triangle.answer)
		_check(checker, str(triangle.kind) == "pythagorean" and hypotenuse >= 5 and hypotenuse <= 100, "Math geometry uses a bounded familiar Pythagorean triple")
		_check(checker, int(triangle.a) * int(triangle.a) + int(triangle.b) * int(triangle.b) == hypotenuse * hypotenuse, "Math geometry triangle dimensions satisfy Pythagoras")
		_check(checker, str(triangle.hint_key) == "hint.pythagorean" and str(triangle.expression).to_lower().contains("hypotenuse"), "Pythagorean hint and question name the target side")


static func _test_reading(checker: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62052
	var level_two_history: Array = []
	var level_two_kinds: Dictionary = {}
	for _sample in 180:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "reading", 2, level_two_history)
		var kind := str(question.get("generator_kind", ""))
		if kind in ["generated_reading_plural", "generated_reading_punctuation", "generated_reading_adjective"]:
			level_two_kinds[kind] = true
		_check_learning_choices(checker, question, "Reading Level 2")
	_check(checker, level_two_kinds.size() == 3, "Reading Level 2 generates plural, punctuation, and adjective practice")

	var level_four_history: Array = []
	var complex_count := 0
	var evidence_count := 0
	for _sample in 220:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "reading", 4, level_four_history)
		var kind := str(question.get("generator_kind", ""))
		if kind == "generated_reading_complex_sentence":
			complex_count += 1
		if kind == "generated_reading_evidence":
			evidence_count += 1
	_check(checker, complex_count > 0 and evidence_count > 0, "Reading Level 4 generates complex sentences and text-evidence analysis")

	var level_five_history: Array = []
	var advanced_vocabulary := 0
	var vocabulary_review := 0
	var level_five_evidence := 0
	for _sample in 260:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "reading", 5, level_five_history)
		var kind := str(question.get("generator_kind", ""))
		if kind == "generated_reading_vocabulary":
			var source_level := int(question.get("source_level", 0))
			_check(checker, source_level >= 1 and source_level <= 5, "Reading vocabulary preserves its source challenge level")
			if source_level >= 4:
				advanced_vocabulary += 1
			else:
				vocabulary_review += 1
		if kind == "generated_reading_evidence":
			level_five_evidence += 1
	_check(checker, advanced_vocabulary > 0 and vocabulary_review > 0, "Reading Level 5 balances challenging vocabulary with spaced review")
	_check(checker, level_five_evidence > 0, "Reading Level 5 generates text-evidence questions")
	var grounded_coat_inference := false
	for item: Dictionary in QuestionGenerator.READING_INFERENCE_CASES:
		if str(item.prompt).to_lower().contains("wind") and str(item.prompt).to_lower().contains("coat"):
			grounded_coat_inference = str(item.answer) == "To stay warm"
	_check(checker, grounded_coat_inference, "Reading inference supplies an explicit clue for the coat answer")


static func _test_russian_and_spanish(checker: Callable) -> void:
	var aspect_gloss_is_bounded := false
	for pair: Dictionary in QuestionGenerator.RUSSIAN_ASPECT_PAIRS:
		if str(pair.perfective) == "посмотреть":
			var gloss := str(pair.meaning).to_lower()
			aspect_gloss_is_bounded = gloss == "take a look"
	_check(checker, aspect_gloss_is_bounded, "Russian perfective посмотреть uses a concise, natural English gloss")
	var study_is_a_noun := false
	for item: Dictionary in QuestionGenerator.RUSSIAN_WORDS:
		if str(item.word) == "изучение":
			study_is_a_noun = str(item.get("part_of_speech", "")) == "noun" and str(item.en) == "study"
	_check(checker, study_is_a_noun, "Russian изучение is marked as a noun and keeps a concise English gloss")
	var noun_cue_rng := RandomNumberGenerator.new()
	noun_cue_rng.seed = 62056
	var noun_cue_seen := false
	for _sample in 300:
		var noun_question: Dictionary = QuestionGenerator._language_vocabulary(noun_cue_rng, "russian", 5)
		if str(noun_question.get("source_word", "")) == "изучение":
			noun_cue_seen = str(noun_question.expression).to_lower().contains("noun")
	_check(checker, noun_cue_seen, "Russian noun translations identify the part of speech in the question")

	var rng := RandomNumberGenerator.new()
	rng.seed = 62053
	var russian_history: Array = []
	var russian_form_cues := 0
	for _sample in 160:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "russian", 2, russian_history)
		var form_note := str(question.get("form_note", ""))
		if not form_note.is_empty():
			russian_form_cues += 1
			_check(checker, str(question.expression).to_lower().contains(form_note.to_lower()), "Russian adjective translation identifies its masculine singular form")
	_check(checker, russian_form_cues > 0, "Russian beginner vocabulary generates explicit adjective-form cues")

	var spanish_history: Array = []
	var spanish_form_cues := 0
	for _sample in 220:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "spanish", 1, spanish_history)
		var form_note := str(question.get("form_note", ""))
		if not form_note.is_empty():
			spanish_form_cues += 1
			_check(checker, str(question.expression).to_lower().contains(form_note.to_lower()), "Spanish adjective translation identifies its masculine singular form")
	_check(checker, spanish_form_cues > 0, "Spanish beginner vocabulary generates explicit adjective-form cues")

	var subjunctive_hint := I18n.t("hint.spanish.subjunctive").to_lower()
	for trigger: String in ["es posible que", "quiero que", "espero que", "es importante que"]:
		_check(checker, subjunctive_hint.contains(trigger), "Spanish subjunctive hint includes %s" % trigger)
	var subjunctive_history: Array = []
	var subjunctive_triggers: Dictionary = {}
	for _sample in 260:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "spanish", 5, subjunctive_history)
		if str(question.get("generator_kind", "")) == "generated_spanish_subjunctive":
			var prompt := str(question.expression).to_lower()
			for trigger: String in ["es posible que", "quiero que", "espero que", "es importante que"]:
				if prompt.contains(trigger):
					subjunctive_triggers[trigger] = true
	_check(checker, subjunctive_triggers.has("es posible que") and (subjunctive_triggers.has("quiero que") or subjunctive_triggers.has("espero que") or subjunctive_triggers.has("es importante que")), "Spanish subjunctive generator practices possibility and desire/importance triggers")


static func _test_science(checker: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 62054
	var level_one_history: Array = []
	var classification_seen := false
	var senses_seen := false
	for _sample in 150:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "science", 1, level_one_history)
		var kind := str(question.get("generator_kind", ""))
		if kind == "generated_science_classification":
			classification_seen = true
			_check(checker, str(question.hint_key) == "hint.science.classification", "Science classification has a life-group hint")
		if kind == "generated_science_sense":
			senses_seen = true
			_check(checker, str(question.hint_key) == "hint.science.senses", "Science senses have an action-specific hint")
	_check(checker, classification_seen and senses_seen, "Science beginner sampling covers classification and senses")

	var level_two_history: Array = []
	for _sample in 120:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "science", 2, level_two_history)
		if str(question.get("generator_kind", "")) == "generated_science_state":
			var prompt := str(question.expression).to_lower()
			_check(checker, not prompt.contains("solid, liquid, or gas"), "Science state stem presents a two-choice-friendly question")

	var level_three_history: Array = []
	var level_three_kinds: Dictionary = {}
	for _sample in 240:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "science", 3, level_three_history)
		var kind := str(question.get("generator_kind", ""))
		if kind in ["generated_science_variable", "generated_science_ecosystem", "generated_science_water_cycle", "generated_science_energy", "generated_science_concept"]:
			level_three_kinds[kind] = true
		_check(checker, kind != "generated_science_state", "Science Level 3 does not fall back to elementary state naming")
	_check(checker, level_three_kinds.size() == 5, "Science Level 3 samples fair tests, ecosystems, cycles, energy, and concepts")

	var speed_history: Array = []
	var bounded_scenarios := 0
	for _sample in 240:
		var question: Dictionary = LearningQuestion.generate_with_history(rng, "science", 4, speed_history)
		if str(question.get("generator_kind", "")) != "generated_science_speed":
			continue
		bounded_scenarios += 1
		var expected_speed := int(question.expected_speed)
		var time_hours := int(question.time_hours)
		_check(checker, expected_speed >= int(question.min_speed) and expected_speed <= int(question.max_speed) and time_hours >= 1 and time_hours <= int(question.max_hours), "Science travel values stay within the named scenario's bounds")
		_check(checker, int(question.distance) == expected_speed * time_hours and str(question.hint_key) == "hint.science.physics", "Science travel answers and speed hint match the scenario")
		_check(checker, str(question.expression).to_lower().contains(str(question.scenario_name).to_lower()), "Science travel prompt names its real-world scenario")
	_check(checker, bounded_scenarios > 0, "Science Level 4 still offers bounded travel-rate questions")

	for level: int in [4, 5]:
		var level_history: Array = []
		var density_seen := false
		for _sample in 120:
			var question: Dictionary = LearningQuestion.generate_with_history(rng, "science", level, level_history)
			if str(question.get("generator_kind", "")) == "generated_science_density":
				density_seen = true
				_check(checker, str(question.hint_key) == "hint.science.density", "Science density has a grams-per-cubic-centimeter hint")
		_check(checker, density_seen, "Science challenge level %d includes density practice" % level)
