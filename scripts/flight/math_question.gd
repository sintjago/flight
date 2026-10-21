extends RefCounted
## Builds a two-choice math prompt, with a topic and short learning hint, for each difficulty.

const DIFFICULTIES := ["easy", "medium", "hard"]
const TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability", "decimals", "percentages", "ratios", "order_of_operations", "statistics", "integers", "algebra", "quadratics", "exponents", "roots", "trigonometry"]
const TRACK_IDS := ["math_1", "math_2", "math_3"]
const TRACK_TOPIC_GROUPS := {
	"math_1": ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense"],
	"math_2": ["fractions", "measurement", "geometry", "probability", "decimals", "percentages", "ratios", "order_of_operations", "statistics", "integers", "algebra"],
	"math_3": ["geometry", "probability", "statistics", "integers", "algebra", "quadratics", "exponents", "roots", "trigonometry"],
}
const EASY_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability"]
const MEDIUM_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability", "decimals", "percentages", "ratios", "order_of_operations", "statistics"]
const HARD_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability", "decimals", "percentages", "ratios", "order_of_operations", "statistics", "integers", "algebra", "exponents", "roots"]
const LEVEL_FIVE_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "measurement", "geometry", "probability", "decimals", "percentages", "ratios", "order_of_operations", "statistics", "integers", "algebra", "quadratics", "exponents", "roots", "trigonometry"]


static func difficulty_level_for(value: Variant) -> int:
	if value is int or value is float:
		return clampi(roundi(float(value)), 1, 5)
	match str(value):
		"easy":
			return 2
		"medium":
			return 3
		"hard":
			return 4
	return 2


static func band_for_level(level: int) -> String:
	if level <= 2:
		return "easy"
	if level == 3:
		return "medium"
	return "hard"


static func available_topic_groups(level: int) -> Array[String]:
	var safe_level := clampi(level, 1, 5)
	var groups: Array[String] = []
	var source: Array = EASY_TOPIC_GROUPS
	if safe_level == 3:
		source = MEDIUM_TOPIC_GROUPS
	elif safe_level == 4:
		source = HARD_TOPIC_GROUPS
	elif safe_level == 5:
		source = LEVEL_FIVE_TOPIC_GROUPS
	for group: Variant in source:
		groups.append(str(group))
	return groups


static func topic_groups_for_track(track_id: String) -> Array[String]:
	var groups: Array[String] = []
	for group: Variant in TRACK_TOPIC_GROUPS.get(track_id, []):
		groups.append(str(group))
	return groups


static func available_topic_groups_for_track(track_id: String, level: int) -> Array[String]:
	var groups: Array[String] = []
	var available := available_topic_groups(level)
	for group: String in topic_groups_for_track(track_id):
		if group in available:
			groups.append(group)
	return groups


static func topic_unlock_level(group: String) -> int:
	if group in EASY_TOPIC_GROUPS:
		return 1
	if group in MEDIUM_TOPIC_GROUPS:
		return 3
	if group in HARD_TOPIC_GROUPS:
		return 4
	if group in LEVEL_FIVE_TOPIC_GROUPS:
		return 5
	return 5


static func generate(rng: RandomNumberGenerator, difficulty: Variant, selected_groups: Array = []) -> Dictionary:
	var level := difficulty_level_for(difficulty)
	var mode := band_for_level(level)
	var eligible: Array[String] = []
	for group: String in available_topic_groups(level):
		if selected_groups.is_empty() or group in selected_groups:
			eligible.append(group)
	if eligible.is_empty():
		eligible = available_topic_groups(level)
	var group := eligible[rng.randi_range(0, eligible.size() - 1)]
	var question := _generate_for_group(rng, mode, level, group)
	question["difficulty"] = mode
	question["difficulty_level"] = level
	question["topic_group"] = group
	var answer := str(question.answer)
	var distractor := _make_distractor(question, mode, rng)
	question["distractor"] = distractor
	var lane := "upper" if rng.randi_range(0, 1) == 0 else "lower"
	question["upper_answer"] = answer if lane == "upper" else distractor
	question["lower_answer"] = distractor if lane == "upper" else answer
	question["correct_lane"] = lane
	return question


static func generate_with_history(rng: RandomNumberGenerator, difficulty: Variant, selected_groups: Array, used_prompts: Array) -> Dictionary:
	var question: Dictionary = {}
	var seen_prompts: Dictionary = {}
	for prompt: Variant in used_prompts:
		seen_prompts[str(prompt)] = true
	var attempt_limit := maxi(2048, (seen_prompts.size() + 1) * 16)
	for _attempt in attempt_limit:
		question = generate(rng, difficulty, selected_groups)
		var prompt := str(question.get("expression", ""))
		if not prompt.is_empty() and not seen_prompts.has(prompt):
			used_prompts.append(prompt)
			return question
	var previous_prompt := str(used_prompts.back()) if not used_prompts.is_empty() else ""
	used_prompts.clear()
	if not previous_prompt.is_empty():
		used_prompts.append(previous_prompt)
	for _attempt in 2048:
		question = generate(rng, difficulty, selected_groups)
		var prompt := str(question.get("expression", ""))
		if not prompt.is_empty() and prompt != previous_prompt:
			used_prompts.append(prompt)
			return question
	question = generate(rng, difficulty, selected_groups)
	used_prompts.append(str(question.get("expression", "")))
	return question


static func _generate_for_group(rng: RandomNumberGenerator, mode: String, level: int, group: String) -> Dictionary:
	match group:
		"addition":
			if mode == "easy":
				return _easy_add(rng, 20 if level == 1 else 100)
			if mode == "medium":
				return _medium_add(rng)
			return _hard_signed_operation(rng, "addition", level)
		"subtraction":
			if mode == "easy":
				return _easy_subtract(rng, 20 if level == 1 else 100)
			if mode == "medium":
				return _medium_subtract(rng)
			return _hard_signed_operation(rng, "subtraction", level)
		"multiplication":
			if mode == "easy":
				return _easy_multiply(rng, 5 if level == 1 else 10)
			if mode == "medium":
				return _medium_multiply(rng)
			return _hard_signed_operation(rng, "multiplication", level)
		"division":
			if mode == "easy":
				return _easy_divide(rng, 5 if level == 1 else 10)
			if mode == "medium":
				return _medium_divide(rng)
			return _hard_signed_operation(rng, "division", level)
		"fractions":
			if mode == "easy":
				if level == 1:
					return _easy_fraction_of(rng, level)
				return _easy_fraction_of(rng, level) if rng.randi_range(0, 1) == 0 else _easy_fraction_compare(rng)
			return _fraction_operation(rng, level == 5, level)
		"number_sense":
			return _number_sense_question(rng, level)
		"measurement":
			return _measurement_question(rng, level)
		"geometry":
			return _geometry_question(rng, level)
		"probability":
			return _probability_question(rng, level)
		"decimals":
			return _decimal_question(rng, level)
		"percentages":
			return _percentage_question(rng, level)
		"ratios":
			return _ratio_question(rng, level)
		"order_of_operations":
			return _order_operations_question(rng, level)
		"statistics":
			return _statistics_question(rng, level)
		"integers":
			return _hard_signed_operation(rng, "integers", level)
		"algebra":
			return _hard_linear(rng, level)
		"quadratics":
			return _hard_quadratic(rng)
		"exponents":
			return _hard_exponents(rng)
		"roots":
			return _hard_roots(rng)
		"trigonometry":
			return _hard_trigonometry(rng)
	return _easy_add(rng)


static func _generate_easy(rng: RandomNumberGenerator, level: int = 2) -> Dictionary:
	match rng.randi_range(0, 7):
		0:
			return _easy_add(rng)
		1:
			return _easy_subtract(rng)
		2:
			return _easy_multiply(rng)
		3:
			return _easy_divide(rng)
		4:
			return _easy_fraction_of(rng, level)
		5:
			return _easy_fraction_compare(rng) if level >= 2 else _easy_fraction_of(rng, level)
		6:
			return _easy_place_value(rng)
		_:
			return _easy_pattern(rng)


static func _generate_medium(rng: RandomNumberGenerator) -> Dictionary:
	match rng.randi_range(0, 8):
		0:
			return _medium_add(rng)
		1:
			return _medium_subtract(rng)
		2:
			return _medium_multiply(rng)
		3:
			return _medium_divide(rng)
		4:
			return _fraction_operation(rng, false)
		5:
			return _medium_decimal(rng)
		6:
			return _medium_percent(rng)
		7:
			return _medium_ratio(rng)
		_:
			return _medium_order_operations(rng)


static func _generate_hard(rng: RandomNumberGenerator) -> Dictionary:
	match rng.randi_range(0, 7):
		0:
			return _hard_integers(rng)
		1:
			return _fraction_operation(rng, true)
		2:
			return _hard_linear(rng)
		3:
			return _hard_quadratic(rng)
		4:
			return _hard_exponents(rng)
		5:
			return _hard_roots(rng)
		6:
			return _hard_geometry(rng)
		_:
			return _hard_trigonometry(rng)


static func _easy_add(rng: RandomNumberGenerator, max_total: int = 100) -> Dictionary:
	var min_a := maxi(2, int(max_total * 0.12))
	var max_a := maxi(min_a, int(max_total * 0.89))
	var a := rng.randi_range(min_a, max_a)
	var b := rng.randi_range(1, max_total - a)
	return _integer_problem("%d + %d = ?" % [a, b], a + b, "addition", "hint.addition", "integer_operation", a, b, "+")


static func _easy_subtract(rng: RandomNumberGenerator, max_value: int = 100) -> Dictionary:
	var a := rng.randi_range(maxi(2, int(max_value * 0.1)), max_value)
	var b := rng.randi_range(1, a)
	return _integer_problem("%d - %d = ?" % [a, b], a - b, "subtraction", "hint.subtraction", "integer_operation", a, b, "-")


static func _easy_multiply(rng: RandomNumberGenerator, max_factor: int = 10) -> Dictionary:
	var a := rng.randi_range(2, max_factor)
	var b := rng.randi_range(2, max_factor)
	return _integer_problem("%d × %d = ?" % [a, b], a * b, "multiplication", "hint.multiplication", "integer_operation", a, b, "×")


static func _easy_divide(rng: RandomNumberGenerator, max_factor: int = 10) -> Dictionary:
	var divisor := rng.randi_range(2, max_factor)
	var quotient := rng.randi_range(2, max_factor)
	var dividend := divisor * quotient
	return _integer_problem("%d ÷ %d = ?" % [dividend, divisor], quotient, "division", "hint.division", "integer_operation", dividend, divisor, "÷")


static func _easy_fraction_of(rng: RandomNumberGenerator, level: int = 2) -> Dictionary:
	var denominator := 2 if level == 1 or rng.randi_range(0, 1) == 0 else 4
	var numerator := 1 if denominator == 2 or rng.randi_range(0, 1) == 0 else 3
	var whole := denominator * rng.randi_range(2, 20)
	var answer := int(numerator * whole / denominator)
	var expression := "%d/%d of %d = ?" % [numerator, denominator, whole]
	return _problem(expression, str(answer), "fractions", "hint.simple_fractions", "fraction_of", answer, 1, {
		"numerator": numerator, "denominator": denominator, "whole": whole,
	})


static func _easy_fraction_compare(rng: RandomNumberGenerator) -> Dictionary:
	var fractions: Array = [Vector2i(1, 2), Vector2i(1, 3), Vector2i(1, 4), Vector2i(2, 3), Vector2i(3, 4), Vector2i(2, 4)]
	var left: Vector2i = fractions[rng.randi_range(0, fractions.size() - 1)]
	var right: Vector2i = fractions[rng.randi_range(0, fractions.size() - 1)]
	while left.x * right.y == right.x * left.y:
		right = fractions[rng.randi_range(0, fractions.size() - 1)]
	var left_is_greater := left.x * right.y > right.x * left.y
	var chosen: Vector2i = left if left_is_greater else right
	var other: Vector2i = right if left_is_greater else left
	var answer := _format_fraction(chosen.x, chosen.y)
	return _problem("Which is larger, %s or %s?" % [_format_fraction(left.x, left.y), _format_fraction(right.x, right.y)], answer, "fractions", "hint.simple_fractions", "fraction_compare", chosen.x, chosen.y, {
		"left_num": left.x, "left_den": left.y, "right_num": right.x, "right_den": right.y,
		"distractor_pool": [_format_fraction(other.x, other.y)],
	})


static func _easy_place_value(rng: RandomNumberGenerator) -> Dictionary:
	var number := rng.randi_range(10, 99)
	var answer := int(number / 10)
	return _integer_problem("Tens digit of %d = ?" % number, answer, "place_value", "hint.place_value", "place_value", number, 10, "÷")


static func _easy_pattern(rng: RandomNumberGenerator, max_value: int = 100) -> Dictionary:
	var max_step := maxi(2, mini(12, int(max_value / 6)))
	var step_size := rng.randi_range(2, max_step)
	var start := rng.randi_range(1, max_value - step_size * 3)
	var answer := start + step_size * 3
	var expression := "%d, %d, %d, ?" % [start, start + step_size, start + step_size * 2]
	return _integer_problem(expression, answer, "number_patterns", "hint.number_patterns", "number_pattern", start, step_size, "+")


static func _number_sense_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 2:
		return _easy_place_value(rng) if rng.randi_range(0, 1) == 0 else _easy_pattern(rng, 20 if level == 1 else 100)
	if level == 3:
		return _place_value_at(rng, 100, 1000, 9999, "hundreds") if rng.randi_range(0, 1) == 0 else _larger_number_pattern(rng)
	if level == 4:
		return _rounding_question(rng)
	return _scientific_notation_question(rng)


static func _place_value_at(rng: RandomNumberGenerator, place: int, minimum: int, maximum: int, place_name: String) -> Dictionary:
	var number := rng.randi_range(minimum, maximum)
	var digit := int(number / place) % 10
	var expression := "%s digit of %d = ?" % [place_name.capitalize(), number]
	return _integer_problem(expression, digit, "place_value", "hint.place_value", "place_value", number, place, "digit", {
		"place_name": place_name,
	})


static func _larger_number_pattern(rng: RandomNumberGenerator) -> Dictionary:
	var step_size := rng.randi_range(10, 100)
	var start := rng.randi_range(100, 700)
	var answer := start + step_size * 3
	var expression := "%d, %d, %d, ?" % [start, start + step_size, start + step_size * 2]
	return _integer_problem(expression, answer, "number_patterns", "hint.number_patterns", "number_pattern", start, step_size, "+")


static func _rounding_question(rng: RandomNumberGenerator) -> Dictionary:
	var place := 100 if rng.randi_range(0, 1) == 0 else 1000
	var place_name := "hundred" if place == 100 else "thousand"
	var number := rng.randi_range(1000, 9999)
	var answer := roundi(float(number) / float(place)) * place
	return _integer_problem("Round %d to the nearest %s = ?" % [number, place_name], answer, "rounding", "hint.rounding", "rounding", number, place, "round", {
		"rounded_value": answer, "rounding_place": place, "distractor_pool": [answer - place, answer + place],
	})


static func _scientific_notation_question(rng: RandomNumberGenerator) -> Dictionary:
	var coefficient_tenths := rng.randi_range(11, 99)
	var exponent := rng.randi_range(3, 6)
	var answer := coefficient_tenths * int(pow(10.0, float(exponent - 1)))
	var coefficient_text := "%d.%d" % [int(coefficient_tenths / 10), coefficient_tenths % 10]
	var expression := "%s × 10^%d in standard form = ?" % [coefficient_text, exponent]
	return _integer_problem(expression, answer, "scientific_notation", "hint.scientific_notation", "scientific_notation", coefficient_tenths, exponent, "×10^", {
		"coefficient_tenths": coefficient_tenths, "exponent": exponent, "standard_value": answer,
		"distractor_pool": [int(answer / 10), answer * 10],
	})


static func _medium_add(rng: RandomNumberGenerator) -> Dictionary:
	var a := rng.randi_range(100, 8999)
	var b := rng.randi_range(100, 10000 - a)
	return _integer_problem("%d + %d = ?" % [a, b], a + b, "addition", "hint.addition", "integer_operation", a, b, "+")


static func _medium_subtract(rng: RandomNumberGenerator) -> Dictionary:
	var a := rng.randi_range(1000, 10000)
	var b := rng.randi_range(100, a)
	return _integer_problem("%d - %d = ?" % [a, b], a - b, "subtraction", "hint.subtraction", "integer_operation", a, b, "-")


static func _medium_multiply(rng: RandomNumberGenerator) -> Dictionary:
	var a := rng.randi_range(10, 99)
	var b := rng.randi_range(10, 99)
	return _integer_problem("%d × %d = ?" % [a, b], a * b, "multiplication", "hint.multiplication", "integer_operation", a, b, "×")


static func _medium_divide(rng: RandomNumberGenerator) -> Dictionary:
	var divisor := rng.randi_range(2, 40)
	var quotient := rng.randi_range(2, mini(250, int(10000.0 / float(divisor))))
	var dividend := divisor * quotient
	return _integer_problem("%d ÷ %d = ?" % [dividend, divisor], quotient, "division", "hint.division", "integer_operation", dividend, divisor, "÷")


static func _medium_decimal(rng: RandomNumberGenerator) -> Dictionary:
	var a_cents := rng.randi_range(100, 8999)
	var operator := "+" if rng.randi_range(0, 1) == 0 else "-"
	var b_cents := rng.randi_range(1, 10000 - a_cents) if operator == "+" else rng.randi_range(1, a_cents)
	var answer_cents := a_cents + b_cents if operator == "+" else a_cents - b_cents
	var expression := "%s %s %s = ?" % [_format_decimal_cents(a_cents), operator, _format_decimal_cents(b_cents)]
	return _problem(expression, _format_decimal_cents(answer_cents), "decimals", "hint.decimals", "decimal_operation", answer_cents, 100, {
		"a_cents": a_cents, "b_cents": b_cents, "operator": operator, "answer_cents": answer_cents,
	})


static func _medium_percent(rng: RandomNumberGenerator) -> Dictionary:
	var percentages: Array[int] = [5, 10, 20, 25, 50, 75]
	var percent: int = percentages[rng.randi_range(0, percentages.size() - 1)]
	var amount := 20 * rng.randi_range(1, 50)
	var answer := int(amount * percent / 100)
	return _integer_problem("%d%% of %d = ?" % [percent, amount], answer, "percentages", "hint.percentages", "percentage", amount, percent, "of", {
		"amount": amount, "percent": percent,
	})


static func _medium_ratio(rng: RandomNumberGenerator) -> Dictionary:
	var first := rng.randi_range(2, 12)
	var second := rng.randi_range(2, 15)
	var scale := rng.randi_range(2, 10)
	var known := first * scale
	var answer := second * scale
	return _integer_problem("%d : %d = %d : ?" % [first, second, known], answer, "ratios", "hint.ratios", "ratio", first, second, ":", {
		"scale": scale, "known": known,
	})


static func _medium_order_operations(rng: RandomNumberGenerator) -> Dictionary:
	var form := rng.randi_range(0, 2)
	var a := rng.randi_range(2, 25)
	var b := rng.randi_range(2, 12)
	var c := rng.randi_range(2, 12)
	var expression := ""
	var answer := 0
	match form:
		0:
			expression = "%d + %d × %d = ?" % [a, b, c]
			answer = a + b * c
		1:
			expression = "(%d + %d) × %d = ?" % [a, b, c]
			answer = (a + b) * c
		_:
			expression = "%d × %d - %d = ?" % [a, b, c]
			answer = a * b - c
	return _problem(expression, str(answer), "order_of_operations", "hint.order_operations", "order_operations", answer, 1, {
		"a": a, "b": b, "c": c, "form": form,
	})


static func _decimal_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 3:
		return _medium_decimal(rng)
	var operator := "×" if rng.randi_range(0, 1) == 0 else "÷"
	if level == 4:
		var whole := rng.randi_range(2, 9)
		var answer_tenths := rng.randi_range(12, 90)
		var left_tenths := answer_tenths * whole if operator == "÷" else rng.randi_range(12, 90)
		if operator == "×":
			answer_tenths = left_tenths * whole
		var answer := _format_scaled_decimal(answer_tenths, 1)
		var left_text := _format_scaled_decimal(left_tenths, 1)
		var expression := "%s %s %d = ?" % [left_text, operator, whole]
		return _problem(expression, answer, "decimals", "hint.decimals", "decimal_operation_advanced", answer_tenths, 10, {
			"operator": operator, "form_type": "decimal_by_whole", "left_scaled": left_tenths, "left_scale": 10,
			"right_scaled": whole, "right_scale": 1, "answer_scale": 10,
			"distractor_pool": _decimal_distractor_pool(answer_tenths, 1),
		})
	var right_tenths := rng.randi_range(2, 9)
	var left_scaled := rng.randi_range(10, 90)
	var left_scale := 10
	var answer_scale := 100
	var answer_scaled := 0
	var expression := ""
	if operator == "×":
		answer_scaled = left_scaled * right_tenths
		expression = "%s × %s = ?" % [_format_scaled_decimal(left_scaled, 1), _format_scaled_decimal(right_tenths, 1)]
	else:
		answer_scaled = rng.randi_range(10, 90)
		left_scaled = answer_scaled * right_tenths
		left_scale = 100
		answer_scale = 10
		expression = "%s ÷ %s = ?" % [_format_scaled_decimal(left_scaled, 2), _format_scaled_decimal(right_tenths, 1)]
	var answer_text := _format_scaled_decimal(answer_scaled, 1 if answer_scale == 10 else 2)
	return _problem(expression, answer_text, "decimals", "hint.decimals", "decimal_operation_advanced", answer_scaled, answer_scale, {
		"operator": operator, "form_type": "decimal_by_decimal", "left_scaled": left_scaled, "left_scale": left_scale,
		"right_scaled": right_tenths, "right_scale": 10, "answer_scale": answer_scale,
		"distractor_pool": _decimal_distractor_pool(answer_scaled, 1 if answer_scale == 10 else 2),
	})


static func _format_scaled_decimal(value: int, decimal_places: int) -> String:
	if decimal_places == 1:
		return "%.1f" % (float(value) / 10.0)
	return "%.2f" % (float(value) / 100.0)


static func _decimal_distractor_pool(value: int, decimal_places: int) -> Array[String]:
	var pool: Array[String] = []
	for offset: int in [-3, -2, 2, 3]:
		if value + offset >= 0:
			pool.append(_format_scaled_decimal(value + offset, decimal_places))
	return pool


static func _percentage_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 3:
		return _medium_percent(rng)
	if level == 4 or rng.randi_range(0, 1) == 0:
		return _percentage_change(rng)
	return _percentage_reverse(rng)


static func _percentage_change(rng: RandomNumberGenerator) -> Dictionary:
	var bases: Array[int] = [80, 100, 120, 200, 320, 500]
	var percents: Array[int] = [10, 15, 20, 25, 50]
	var base := bases[rng.randi_range(0, bases.size() - 1)]
	var percent := percents[rng.randi_range(0, percents.size() - 1)]
	var amount_change := int(base * percent / 100)
	var discount := rng.randi_range(0, 1) == 0
	var answer := base - amount_change if discount else base + amount_change
	var form := "discount" if discount else "increase"
	var expression := "%d; %d%% off = ?" % [base, percent] if discount else "%d; add %d%% = ?" % [base, percent]
	var pool: Array[String] = [str(base), str(amount_change), str(base + amount_change)]
	return _integer_problem(expression, answer, "percentages", "hint.percentages", "percentage_change", base, percent, "%", {
		"base_amount": base, "percent": percent, "amount_change": amount_change, "change_type": form, "form_type": form,
		"distractor_pool": pool,
	})


static func _percentage_reverse(rng: RandomNumberGenerator) -> Dictionary:
	var bases: Array[int] = [60, 80, 100, 120, 200, 320]
	var percents: Array[int] = [10, 20, 25, 50]
	var answer := bases[rng.randi_range(0, bases.size() - 1)]
	var percent := percents[rng.randi_range(0, percents.size() - 1)]
	var known_part := int(answer * percent / 100)
	var expression := "%d is %d%% of ?" % [known_part, percent]
	var pool: Array[String] = [str(maxi(1, answer - 20)), str(answer + 20), str(answer * 2)]
	return _integer_problem(expression, answer, "percentages", "hint.percentages", "percentage_reverse", known_part, percent, "%", {
		"known_part": known_part, "percent": percent, "form_type": "reverse", "distractor_pool": pool,
	})


static func _ratio_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 3:
		return _medium_ratio(rng)
	if level == 4:
		var item_count := rng.randi_range(3, 12)
		var unit_rate := rng.randi_range(2, 24)
		var total := item_count * unit_rate
		return _integer_problem("%d items cost $%d; each costs ?" % [item_count, total], unit_rate, "ratios", "hint.ratios", "unit_rate", total, item_count, "÷", {
			"item_count": item_count, "total_cost": total, "unit_rate": unit_rate, "form_type": "unit_rate",
			"distractor_pool": [str(unit_rate - 1), str(unit_rate + 1), str(total)],
		})
	var servings := rng.randi_range(2, 5)
	var cups := rng.randi_range(1, 4)
	var scale := rng.randi_range(2, 6)
	var target_servings := servings * scale
	var answer := cups * scale
	return _integer_problem("%d cups for %d servings; %d servings = ? cups" % [cups, servings, target_servings], answer, "ratios", "hint.ratios", "ratio_proportion", cups, servings, ":", {
		"cups": cups, "base_servings": servings, "target_servings": target_servings, "scale": scale,
		"form_type": "word_proportion", "distractor_pool": [str(answer - 1), str(answer + 1), str(cups * target_servings)],
	})


static func _order_operations_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 3:
		return _medium_order_operations(rng)
	if level == 4:
		var addend := rng.randi_range(8, 36)
		var divisor := rng.randi_range(2, 8)
		var quotient := rng.randi_range(2, 12)
		var multiplier := rng.randi_range(2, 5)
		var dividend := divisor * quotient
		var answer := addend + quotient * multiplier
		var expression := "%d + %d ÷ %d × %d = ?" % [addend, dividend, divisor, multiplier]
		return _problem(expression, str(answer), "order_of_operations", "hint.order_operations", "order_operations_extended", answer, 1, {
			"form_type": "exact_division_chain", "addend": addend, "dividend": dividend, "divisor": divisor,
			"multiplier": multiplier,
		})
	var base := rng.randi_range(2, 5)
	var exponent := rng.randi_range(2, 3)
	var left_factor := rng.randi_range(2, 12)
	var right_factor := rng.randi_range(2, 12)
	var power_value := int(pow(float(base), float(exponent)))
	var answer := power_value + left_factor * right_factor
	var expression := "%d^%d + %d × %d = ?" % [base, exponent, left_factor, right_factor]
	return _problem(expression, str(answer), "order_of_operations", "hint.order_operations", "order_operations_extended", answer, 1, {
		"form_type": "powers_first", "base": base, "exponent": exponent, "left_factor": left_factor,
		"right_factor": right_factor,
	})


static func _fraction_operation(rng: RandomNumberGenerator, advanced: bool, level: int = 3) -> Dictionary:
	var max_denominator := 20 if advanced else 12
	var left_den := rng.randi_range(2, max_denominator)
	var right_den := rng.randi_range(2, max_denominator)
	var left_num := rng.randi_range(1, left_den - 1)
	var right_num := rng.randi_range(1, right_den - 1)
	var operators: Array[String] = ["+", "-"]
	if level >= 4:
		operators.append("×")
	if level >= 5:
		operators.append("÷")
	var operator: String = operators[rng.randi_range(0, operators.size() - 1)]
	if not advanced and operator == "-" and left_num * right_den < right_num * left_den:
		var old_num := left_num
		var old_den := left_den
		left_num = right_num
		left_den = right_den
		right_num = old_num
		right_den = old_den
	var numerator: int = 0
	var denominator: int = 1
	match operator:
		"+":
			numerator = left_num * right_den + right_num * left_den
			denominator = left_den * right_den
		"-":
			numerator = left_num * right_den - right_num * left_den
			denominator = left_den * right_den
		"×":
			numerator = left_num * right_num
			denominator = left_den * right_den
		_:
			numerator = left_num * right_den
			denominator = left_den * right_num
	var answer := _format_fraction(numerator, denominator)
	return _problem("%s %s %s = ?" % [_format_fraction(left_num, left_den), operator, _format_fraction(right_num, right_den)], answer, "fractions", "hint.fraction_operations", "fraction_operation", numerator, denominator, {
		"left_num": left_num, "left_den": left_den, "right_num": right_num, "right_den": right_den, "operator": operator,
	})


static func _measurement_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level <= 1:
		match rng.randi_range(0, 2):
			0:
				var coins: Array[int] = [5, 10, 25, 50]
				var first_coin: int = coins[rng.randi_range(0, coins.size() - 1)]
				var second_coin: int = coins[rng.randi_range(0, coins.size() - 1)]
				return _integer_problem("%d¢ + %d¢ = ?¢" % [first_coin, second_coin], first_coin + second_coin, "measurement", "hint.measurement", "money_sum", first_coin, second_coin, "+")
			1:
				var hours := rng.randi_range(1, 4)
				return _integer_problem("%d hours = ? minutes" % hours, hours * 60, "measurement", "hint.measurement", "unit_conversion", hours, 60, "×", {"conversion": "hours_to_minutes", "input_value": hours})
			_:
				var first_cm := rng.randi_range(5, 35)
				var second_cm := rng.randi_range(5, 35)
				return _integer_problem("%d cm + %d cm = ? cm" % [first_cm, second_cm], first_cm + second_cm, "measurement", "hint.measurement", "measurement_sum", first_cm, second_cm, "+")
	if level == 2:
		match rng.randi_range(0, 3):
			0:
				var meters := rng.randi_range(1, 9)
				return _integer_problem("%d m = ? cm" % meters, meters * 100, "measurement", "hint.measurement", "unit_conversion", meters, 100, "×", {"conversion": "meters_to_cm", "input_value": meters})
			1:
				var kilograms := rng.randi_range(1, 8)
				return _integer_problem("%d kg = ? g" % kilograms, kilograms * 1000, "measurement", "hint.measurement", "unit_conversion", kilograms, 1000, "×", {"conversion": "kilograms_to_g", "input_value": kilograms})
			2:
				var hours := rng.randi_range(1, 5)
				return _integer_problem("%d hours = ? minutes" % hours, hours * 60, "measurement", "hint.measurement", "unit_conversion", hours, 60, "×", {"conversion": "hours_to_minutes", "input_value": hours})
			_:
				var meters_from_cm := rng.randi_range(2, 9)
				return _integer_problem("%d cm = ? m" % (meters_from_cm * 100), meters_from_cm, "measurement", "hint.measurement", "unit_conversion", meters_from_cm * 100, 100, "÷", {"conversion": "cm_to_m", "input_value": meters_from_cm * 100})
	var hours_travelled := rng.randi_range(2, 5 if level == 3 else 8)
	var speed := rng.randi_range(20, 80 if level < 5 else 140)
	var distance := hours_travelled * speed
	return _integer_problem("%d km in %d h: ? km/h" % [distance, hours_travelled], speed, "measurement", "hint.measurement", "measurement_rate", distance, hours_travelled, "÷", {
		"distance": distance, "time_hours": hours_travelled, "speed": speed,
	})


static func _probability_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var favorable := 1
	var total := 2
	var expression := "Fair coin: P(tails) = ?"
	var event := "tails"
	if level <= 1:
		if rng.randi_range(0, 1) == 0:
			expression = "Fair coin: P(tails) = ?"
			event = "tails"
			favorable = 1
			total = 2
		else:
			expression = "Fair die: P(even roll) = ?"
			event = "even roll"
			favorable = 3
			total = 6
	elif level == 2:
		var sections := rng.randi_range(5, 10)
		favorable = rng.randi_range(1, sections - 1)
		total = sections
		event = "blue sections"
		expression = "Spinner: %d of %d blue; P(blue) = ?" % [favorable, total]
	elif level == 3:
		total = rng.randi_range(8, 40)
		favorable = rng.randi_range(1, total - 1)
		event = "red outcomes"
		expression = "Bag: %d red of %d; P(red) = ?" % [favorable, total]
	elif level == 4:
		if rng.randi_range(0, 1) == 0:
			var flips := rng.randi_range(2, 7)
			total = int(pow(2.0, float(flips)))
			var event_index := rng.randi_range(0, 3)
			if event_index == 0:
				event = "all heads"
				favorable = 1
			elif event_index == 1:
				event = "at least 1 head"
				favorable = total - 1
			elif event_index == 2:
				event = "exactly 1 head"
				favorable = flips
			else:
				event = "exactly 2 heads"
				favorable = _binomial_coefficient(flips, 2)
			expression = "%d coin flips: P(%s) = ?" % [flips, event]
		else:
			var colours: Array[String] = ["red", "blue", "green", "gold"]
			var colour: String = colours[rng.randi_range(0, colours.size() - 1)]
			total = rng.randi_range(8, 60)
			favorable = rng.randi_range(1, total - 1)
			event = colour + " outcomes"
			if rng.randi_range(0, 1) == 0:
				expression = "Spinner: %d of %d slices are %s; P(%s) = ?" % [favorable, total, colour, colour]
			else:
				expression = "Bag: %d %s counters among %d; P(%s) = ?" % [favorable, colour, total, colour]
	else:
		if rng.randi_range(0, 2) == 0:
			var flips := rng.randi_range(4, 12)
			total = int(pow(2.0, float(flips)))
			var event_index := rng.randi_range(0, 3)
			if event_index == 0:
				event = "at least 1 head"
				favorable = total - 1
			elif event_index == 1:
				event = "exactly 1 head"
				favorable = flips
			elif event_index == 2:
				event = "exactly 2 heads"
				favorable = _binomial_coefficient(flips, 2)
			else:
				event = "all heads"
				favorable = 1
			if rng.randi_range(0, 1) == 0:
				expression = "%d fair coins: P(%s) = ?" % [flips, event]
			else:
				expression = "Flip %d coins. Probability of %s?" % [flips, event]
		else:
			var colours: Array[String] = ["red", "blue", "green", "gold", "white"]
			var colour: String = colours[rng.randi_range(0, colours.size() - 1)]
			total = rng.randi_range(12, 100)
			favorable = rng.randi_range(1, total - 1)
			event = colour + " outcomes"
			var container := "spinner" if rng.randi_range(0, 1) == 0 else "bag"
			if container == "spinner":
				expression = "A spinner has %d %s sections of %d; P(%s) = ?" % [favorable, colour, total, colour]
			else:
				expression = "A bag has %d %s counters out of %d; P(%s) = ?" % [favorable, colour, total, colour]
	var answer := _format_fraction(favorable, total)
	var distractors: Array[String] = ["1/6", "1/5", "1/4", "1/3", "1/2", "2/3", "3/4", "5/6", "7/8"]
	return _problem(expression, answer, "probability", "hint.probability", "probability", favorable, total, {
		"favorable": favorable, "outcomes": total, "event": event, "distractor_pool": distractors,
	})


static func _binomial_coefficient(n: int, k: int) -> int:
	var result := 1
	var take := mini(k, n - k)
	for index in take:
		result = int(result * (n - index) / (index + 1))
	return result


static func _statistics_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	var choices: Array[String] = ["mean", "median", "range"]
	if level >= 4:
		choices.append("mode")
	var statistic: String = choices[rng.randi_range(0, choices.size() - 1)]
	var center := rng.randi_range(8, 20 if level == 3 else 60)
	var values: Array[int] = []
	var answer := center
	match statistic:
		"mean":
			var spread_a := rng.randi_range(1, 5)
			var spread_b := rng.randi_range(1, 6)
			values = [center - spread_a, center - spread_b, center, center + spread_b, center + spread_a]
		"median":
			values = [center + 5, center - 2, center, center + 3, center - 1]
		"range":
			var spread := rng.randi_range(6, 18)
			values = [center, center + 2, center + spread, center + 4, center + 1]
			answer = spread
		_:
			values = [center, center, center + 2, center + 1, center]
	var statistic_names := {"mean": "Mean", "median": "Median", "range": "Range", "mode": "Mode"}
	var expression := "%s %s = ?" % [str(statistic_names[statistic]), str(values).replace(" ", "")]
	return _integer_problem(expression, answer, "statistics", "hint.statistics", "statistic", answer, 1, statistic, {
		"values": values, "statistic": statistic,
	})


static func _geometry_question(rng: RandomNumberGenerator, level: int) -> Dictionary:
	if level == 1:
		var shapes: Array[Dictionary] = [
			{"name": "triangle", "sides": 3}, {"name": "square", "sides": 4},
			{"name": "pentagon", "sides": 5}, {"name": "hexagon", "sides": 6},
		]
		var shape: Dictionary = shapes[rng.randi_range(0, shapes.size() - 1)]
		return _integer_problem("Sides in a %s = ?" % str(shape.name), int(shape.sides), "geometry", "hint.geometry", "geometry_shape_sides", int(shape.sides), 1, "sides", {"sides": int(shape.sides)})
	if level == 2:
		var length := rng.randi_range(3, 12)
		var width := rng.randi_range(2, 10)
		if rng.randi_range(0, 1) == 0:
			return _integer_problem("Rect %d × %d: perimeter = ?" % [length, width], 2 * (length + width), "geometry", "hint.geometry", "rectangle_perimeter", length, width, "perimeter")
		return _integer_problem("Rect %d × %d: area = ?" % [length, width], length * width, "geometry", "hint.geometry", "rectangle_area", length, width, "area")
	if level == 3:
		if rng.randi_range(0, 1) == 0:
			var base := rng.randi_range(2, 10) * 2
			var height := rng.randi_range(2, 12)
			return _integer_problem("Triangle b=%d, h=%d: area = ?" % [base, height], int(base * height / 2), "geometry", "hint.geometry", "triangle_area", base, height, "area")
		var first_angle := rng.randi_range(25, 85)
		var second_angle := rng.randi_range(25, 170 - first_angle)
		return _integer_problem("Triangle: %d°, %d°, ?°" % [first_angle, second_angle], 180 - first_angle - second_angle, "geometry", "hint.geometry", "triangle_angle", first_angle, second_angle, "angle")
	if level == 4:
		return _pythagorean_question(rng)
	if rng.randi_range(0, 1) == 0:
		var radius := rng.randi_range(2, 99)
		return _integer_problem("Circle r=%d: area/π = ?" % radius, radius * radius, "geometry", "hint.geometry", "circle_area_factor", radius, 1, "r²", {"radius": radius})
	var side_a := rng.randi_range(2, 20)
	var side_b := rng.randi_range(2, 20)
	var side_c := rng.randi_range(2, 20)
	return _integer_problem("Box %d × %d × %d: volume = ?" % [side_a, side_b, side_c], side_a * side_b * side_c, "geometry", "hint.geometry", "box_volume", side_a, side_b, "volume", {"side_c": side_c})


static func _pythagorean_question(rng: RandomNumberGenerator) -> Dictionary:
	var triple := _random_pythagorean_triple(rng)
	var a := int(triple[0])
	var b := int(triple[1])
	var c := int(triple[2])
	return _integer_problem("Right triangle: legs %d, %d; c = ?" % [a, b], c, "geometry", "hint.geometry", "pythagorean", a, b, "c", {"hypotenuse": c})


static func _random_pythagorean_triple(rng: RandomNumberGenerator) -> Array[int]:
	var m := rng.randi_range(2, 40)
	var n := rng.randi_range(1, m - 1)
	var side_a := m * m - n * n
	var side_b := 2 * m * n
	if side_a > side_b:
		var held := side_a
		side_a = side_b
		side_b = held
	return [side_a, side_b, m * m + n * n]


static func _hard_integers(rng: RandomNumberGenerator) -> Dictionary:
	return _hard_signed_operation(rng, "integers", 5)


static func _hard_signed_operation(rng: RandomNumberGenerator, operation_group: String, level: int = 5) -> Dictionary:
	var factor_limit := 8 if level == 4 else 12
	if operation_group == "multiplication":
		var left := rng.randi_range(2, factor_limit) * (-1 if rng.randi_range(0, 1) == 0 else 1)
		var right := rng.randi_range(2, factor_limit) * (-1 if rng.randi_range(0, 1) == 0 else 1)
		return _integer_problem("%d × (%d) = ?" % [left, right], left * right, "multiplication", "hint.multiplication", "integer_operation", left, right, "×")
	if operation_group == "division":
		var divisor := rng.randi_range(2, factor_limit) * (-1 if rng.randi_range(0, 1) == 0 else 1)
		var quotient := rng.randi_range(2, factor_limit) * (-1 if rng.randi_range(0, 1) == 0 else 1)
		var dividend := divisor * quotient
		return _integer_problem("%d ÷ (%d) = ?" % [dividend, divisor], quotient, "division", "hint.division", "integer_operation", dividend, divisor, "÷")
	var operators: Array[String] = []
	if operation_group == "addition":
		operators.append("+")
	elif operation_group == "subtraction":
		operators.append("-")
	else:
		operators.append("+")
		operators.append("-")
		operators.append("×")
	var operator: String = operators[rng.randi_range(0, operators.size() - 1)]
	var magnitude := 20 if level == 4 else 40
	var a := rng.randi_range(-magnitude, magnitude)
	var b := rng.randi_range(-magnitude, magnitude)
	if a == 0:
		a = 17
	if b == 0:
		b = -9
	var answer := a + b if operator == "+" else (a - b if operator == "-" else a * b)
	var rendered_b := "(%d)" % b if b < 0 else str(b)
	var expression := "%d %s %s = ?" % [a, operator, rendered_b]
	var topic := operation_group
	var hint := "hint.integers" if operation_group == "integers" or (a < 0 or b < 0) else ("hint.addition" if operator == "+" else "hint.subtraction")
	if operator == "×":
		hint = "hint.multiplication"
	return _integer_problem(expression, answer, topic, hint, "integer_operation", a, b, operator)


static func _hard_linear(rng: RandomNumberGenerator, level: int = 5) -> Dictionary:
	var coefficient := rng.randi_range(2, 5 if level == 4 else 9)
	var solution := rng.randi_range(1, 8) if level == 4 else rng.randi_range(-8, 15)
	var intercept := rng.randi_range(-8, 8) if level == 4 else rng.randi_range(-20, 20)
	var form_count := 2 if level == 4 else 3
	var form := rng.randi_range(0, form_count - 1)
	if form == 2:
		var left_coefficient := rng.randi_range(3, 9)
		var right_coefficient := rng.randi_range(1, left_coefficient - 1)
		var left_constant := rng.randi_range(-18, 18)
		var right_constant := (left_coefficient - right_coefficient) * solution + left_constant
		var left_sign := "+ %d" % left_constant if left_constant >= 0 else "- %d" % abs(left_constant)
		var right_sign := "+ %d" % right_constant if right_constant >= 0 else "- %d" % abs(right_constant)
		var expression := "%dx %s = %dx %s; x = ?" % [left_coefficient, left_sign, right_coefficient, right_sign]
		return _integer_problem(expression, solution, "algebra", "hint.algebra", "linear_equation", left_coefficient, left_constant, "x", {
			"form_type": "both_sides", "solution": solution, "left_coefficient": left_coefficient,
			"left_constant": left_constant, "right_coefficient": right_coefficient, "right_constant": right_constant,
		})
	if form == 1:
		var inside := rng.randi_range(2, 8) if level == 4 else rng.randi_range(-9, 12)
		var result := coefficient * (solution + inside)
		var inside_sign := "+ %d" % inside if inside >= 0 else "- %d" % abs(inside)
		var expression := "Solve: %d(x %s) = %d; x = ?" % [coefficient, inside_sign, result]
		return _integer_problem(expression, solution, "algebra", "hint.algebra", "linear_equation", coefficient, coefficient * inside, "x", {
			"form_type": "parentheses", "coefficient": coefficient, "solution": solution,
			"intercept": coefficient * inside, "result": result, "inside": inside,
		})
	var result := coefficient * solution + intercept
	var sign := "+" if intercept >= 0 else "-"
	var basic_expression := "Solve: %dx %s %d = %d; x = ?" % [coefficient, sign, abs(intercept), result]
	return _integer_problem(basic_expression, solution, "algebra", "hint.algebra", "linear_equation", coefficient, intercept, "x", {
		"form_type": "basic", "coefficient": coefficient, "solution": solution, "intercept": intercept, "result": result,
	})


static func _hard_quadratic(rng: RandomNumberGenerator) -> Dictionary:
	var first_root := rng.randi_range(1, 12) * (-1 if rng.randi_range(0, 1) == 0 else 1)
	var second_root := rng.randi_range(1, 12) * (-1 if rng.randi_range(0, 1) == 0 else 1)
	while second_root == first_root:
		second_root = rng.randi_range(1, 12) * (-1 if rng.randi_range(0, 1) == 0 else 1)
	var sum_roots := first_root + second_root
	var product_roots := first_root * second_root
	var factorized := rng.randi_range(0, 1) == 1
	var requested_root := "larger" if factorized else "smaller"
	var answer := maxi(first_root, second_root) if factorized else mini(first_root, second_root)
	var expression := ""
	if factorized:
		var factor_a := "(x - %d)" % first_root if first_root > 0 else "(x + %d)" % abs(first_root)
		var factor_b := "(x - %d)" % second_root if second_root > 0 else "(x + %d)" % abs(second_root)
		expression = "%s%s = 0; larger root = ?" % [factor_a, factor_b]
	else:
		var x_term := ""
		if sum_roots > 0:
			x_term = " - %d x" % sum_roots
		elif sum_roots < 0:
			x_term = " + %d x" % abs(sum_roots)
		var constant_term := " + %d" % product_roots if product_roots > 0 else " - %d" % abs(product_roots)
		expression = "x^2%s%s = 0; smaller root = ?" % [x_term, constant_term]
	return _integer_problem(expression, answer, "quadratics", "hint.quadratics", "quadratic", sum_roots, product_roots, "roots", {
		"root_a": first_root, "root_b": second_root, "sum_roots": sum_roots, "product_roots": product_roots,
		"requested_root": requested_root, "factorized": factorized,
		"form_type": "factored" if factorized else "expanded",
	})


static func _hard_exponents(rng: RandomNumberGenerator) -> Dictionary:
	var base := rng.randi_range(2, 8)
	var power := rng.randi_range(2, 4)
	var offset := rng.randi_range(1, 20)
	var answer := int(pow(float(base), float(power))) + offset
	return _integer_problem("%d^%d + %d = ?" % [base, power, offset], answer, "exponents", "hint.exponents", "exponent", base, power, "^", {
		"base": base, "power": power, "offset": offset,
	})


static func _hard_roots(rng: RandomNumberGenerator) -> Dictionary:
	var root := rng.randi_range(2, 25)
	var radicand := root * root
	var offset := rng.randi_range(0, 20)
	var answer := root + offset
	return _integer_problem("sqrt(%d) + %d = ?" % [radicand, offset], answer, "roots", "hint.roots", "square_root", radicand, offset, "sqrt", {
		"root": root, "radicand": radicand, "offset": offset,
	})


static func _hard_geometry(rng: RandomNumberGenerator) -> Dictionary:
	return _pythagorean_question(rng)


static func _hard_trigonometry(rng: RandomNumberGenerator) -> Dictionary:
	var pool: Array[String] = ["1/2", "sqrt(2)/2", "sqrt(3)/2", "sqrt(3)/3", "sqrt(3)", "1", "0", "3/5", "4/5", "3/4", "5/13", "12/13", "5/12"]
	if rng.randi_range(0, 1) == 0:
		var table: Array[Dictionary] = [
			{"function": "sin", "angle": 30, "answer": "1/2"},
			{"function": "sin", "angle": 45, "answer": "sqrt(2)/2"},
			{"function": "sin", "angle": 60, "answer": "sqrt(3)/2"},
			{"function": "sin", "angle": 90, "answer": "1"},
			{"function": "cos", "angle": 0, "answer": "1"},
			{"function": "cos", "angle": 30, "answer": "sqrt(3)/2"},
			{"function": "cos", "angle": 45, "answer": "sqrt(2)/2"},
			{"function": "cos", "angle": 60, "answer": "1/2"},
			{"function": "tan", "angle": 30, "answer": "sqrt(3)/3"},
			{"function": "tan", "angle": 45, "answer": "1"},
			{"function": "tan", "angle": 60, "answer": "sqrt(3)"},
		]
		var item: Dictionary = table[rng.randi_range(0, table.size() - 1)]
		var expression := "%s(%d°) = ?" % [str(item.function), int(item.angle)]
		return _problem(expression, str(item.answer), "trigonometry", "hint.trigonometry", "trigonometry", 0, 1, {
			"distractor_pool": pool, "form_type": "special_angle", "trig_function": str(item.function), "angle": int(item.angle),
		})
	var triple := _random_pythagorean_triple(rng)
	var opposite := int(triple[0])
	var adjacent := int(triple[1])
	var hypotenuse := int(triple[2])
	var functions: Array[String] = ["sin", "cos", "tan"]
	var trig_function: String = functions[rng.randi_range(0, functions.size() - 1)]
	var top := opposite if trig_function != "cos" else adjacent
	var bottom := hypotenuse if trig_function != "tan" else adjacent
	var side_names := "opp %d, hyp %d" % [opposite, hypotenuse] if trig_function == "sin" else ("adj %d, hyp %d" % [adjacent, hypotenuse] if trig_function == "cos" else "opp %d, adj %d" % [opposite, adjacent])
	var expression := "%s θ = ? (%s)" % [trig_function, side_names]
	return _problem(expression, _format_fraction(top, bottom), "trigonometry", "hint.trigonometry", "trigonometry", top, bottom, {
		"distractor_pool": pool, "form_type": "triangle_ratio", "trig_function": trig_function,
		"ratio_top": top, "ratio_bottom": bottom, "opposite": opposite, "adjacent": adjacent, "hypotenuse": hypotenuse,
	})


static func _integer_problem(expression: String, answer: int, topic: String, hint_key: String, kind: String, a: int, b: int, operator: String, extra: Dictionary = {}) -> Dictionary:
	var fields := {"a": a, "b": b, "operator": operator}
	for key: String in extra:
		fields[key] = extra[key]
	return _problem(expression, str(answer), topic, hint_key, kind, answer, 1, fields)


static func _problem(expression: String, answer: String, topic: String, hint_key: String, kind: String, value_num: int, value_den: int = 1, extra: Dictionary = {}) -> Dictionary:
	var question := {
		"expression": expression,
		"answer": answer,
		"topic": topic,
		"hint_key": hint_key,
		"kind": kind,
		"value_num": value_num,
		"value_den": value_den,
		"distractor_pool": [],
	}
	for key: String in extra:
		question[key] = extra[key]
	return question


static func _make_distractor(question: Dictionary, difficulty: String, rng: RandomNumberGenerator) -> String:
	var answer := str(question.answer)
	var pool: Array = question.get("distractor_pool", [])
	var valid_pool: Array[String] = []
	for candidate: Variant in pool:
		var text := str(candidate)
		if text != answer and text not in valid_pool:
			valid_pool.append(text)
	if not valid_pool.is_empty():
		return valid_pool[rng.randi_range(0, valid_pool.size() - 1)]
	if str(question.kind) == "decimal_operation":
		var cents := int(question.answer_cents)
		var decimal_offsets: Array[int] = [1, 10, 25, 100]
		for attempt in 12:
			var offset: int = decimal_offsets[rng.randi_range(0, decimal_offsets.size() - 1)]
			var candidate_cents := cents + (offset if rng.randi_range(0, 1) == 0 else -offset)
			if candidate_cents < 0:
				candidate_cents = cents + offset
			var candidate := _format_decimal_cents(candidate_cents)
			if candidate != answer:
				return candidate
	if str(question.kind) == "fraction_operation" and int(question.value_den) > 1:
		var numerator := int(question.value_num)
		var denominator := int(question.value_den)
		var candidates: Array[String] = [
			_format_fraction(numerator + 1, denominator),
			_format_fraction(numerator - 1, denominator),
			_format_fraction(numerator, denominator + 1),
			_format_fraction(numerator * 2, denominator),
		]
		for candidate: String in candidates:
			if candidate != answer:
				return candidate
	if str(question.kind) == "place_value":
		var digit := int(question.answer)
		var alternatives: Array[int] = []
		for value in 10:
			if value != digit:
				alternatives.append(value)
		return str(alternatives[rng.randi_range(0, alternatives.size() - 1)])
	var value := int(question.value_num)
	var offsets: Array[int] = [1, 2, 3, 10]
	if difficulty == "medium":
		offsets = [1, 5, 10, 100]
	elif difficulty == "hard":
		offsets = [1, 2, 5, 10]
	for attempt in 12:
		var offset: int = offsets[rng.randi_range(0, offsets.size() - 1)]
		var candidate_value := value + (offset if rng.randi_range(0, 1) == 0 else -offset)
		if difficulty == "easy":
			candidate_value = maxi(0, candidate_value)
		var candidate_text := str(candidate_value)
		if candidate_text != answer:
			return candidate_text
	return str(value + 1)


static func _format_fraction(numerator: int, denominator: int) -> String:
	if denominator == 0:
		return "0"
	if denominator < 0:
		numerator = -numerator
		denominator = -denominator
	var divisor := _gcd(abs(numerator), denominator)
	var reduced_numerator := int(numerator / divisor)
	var reduced_denominator := int(denominator / divisor)
	if reduced_denominator == 1:
		return str(reduced_numerator)
	return "%d/%d" % [reduced_numerator, reduced_denominator]


static func _format_decimal_cents(cents: int) -> String:
	var sign := "-" if cents < 0 else ""
	var value: int = abs(cents)
	return "%s%d.%02d" % [sign, int(value / 100), value % 100]


static func _gcd(a: int, b: int) -> int:
	var left: int = abs(a)
	var right: int = abs(b)
	while right != 0:
		var remainder: int = left % right
		left = right
		right = remainder
	return maxi(left, 1)
