extends RefCounted
## Builds a two-choice math prompt, with a topic and short learning hint, for each difficulty.

const DIFFICULTIES := ["easy", "medium", "hard"]
const TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "decimals", "percentages", "ratios", "order_of_operations", "integers", "algebra", "quadratics", "exponents", "roots", "geometry", "trigonometry"]
const EASY_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense"]
const MEDIUM_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "decimals", "percentages", "ratios", "order_of_operations"]
const HARD_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "decimals", "percentages", "ratios", "order_of_operations", "integers", "algebra", "exponents", "roots", "geometry"]
const LEVEL_FIVE_TOPIC_GROUPS := ["addition", "subtraction", "multiplication", "division", "fractions", "number_sense", "decimals", "percentages", "ratios", "order_of_operations", "integers", "algebra", "quadratics", "exponents", "roots", "geometry", "trigonometry"]


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
				return _easy_fraction_of(rng, level) if rng.randi_range(0, 1) == 0 else _easy_fraction_compare(rng)
			return _fraction_operation(rng, level == 5)
		"number_sense":
			return _easy_place_value(rng) if rng.randi_range(0, 1) == 0 else _easy_pattern(rng, 20 if level == 1 else 100)
		"decimals":
			return _medium_decimal(rng)
		"percentages":
			return _medium_percent(rng)
		"ratios":
			return _medium_ratio(rng)
		"order_of_operations":
			return _medium_order_operations(rng)
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
		"geometry":
			return _hard_geometry(rng)
		"trigonometry":
			return _hard_trigonometry(rng)
	return _easy_add(rng)


static func _generate_easy(rng: RandomNumberGenerator) -> Dictionary:
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
			return _easy_fraction_of(rng)
		5:
			return _easy_fraction_compare(rng)
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


static func _fraction_operation(rng: RandomNumberGenerator, advanced: bool) -> Dictionary:
	var max_denominator := 20 if advanced else 12
	var left_den := rng.randi_range(2, max_denominator)
	var right_den := rng.randi_range(2, max_denominator)
	var left_num := rng.randi_range(1, left_den - 1)
	var right_num := rng.randi_range(1, right_den - 1)
	var operator := "+" if rng.randi_range(0, 1) == 0 else "-"
	if not advanced and operator == "-" and left_num * right_den < right_num * left_den:
		var old_num := left_num
		var old_den := left_den
		left_num = right_num
		left_den = right_den
		right_num = old_num
		right_den = old_den
	var numerator := left_num * right_den + (right_num * left_den if operator == "+" else -right_num * left_den)
	var denominator := left_den * right_den
	var answer := _format_fraction(numerator, denominator)
	return _problem("%s %s %s = ?" % [_format_fraction(left_num, left_den), operator, _format_fraction(right_num, right_den)], answer, "fractions", "hint.fraction_operations", "fraction_operation", numerator, denominator, {
		"left_num": left_num, "left_den": left_den, "right_num": right_num, "right_den": right_den, "operator": operator,
	})


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
	var result := coefficient * solution + intercept
	var sign := "+" if intercept >= 0 else "-"
	var expression := "Solve: %dx %s %d = %d; x = ?" % [coefficient, sign, abs(intercept), result]
	return _integer_problem(expression, solution, "algebra", "hint.algebra", "linear_equation", coefficient, intercept, "x", {
		"coefficient": coefficient, "solution": solution, "intercept": intercept, "result": result,
	})


static func _hard_quadratic(rng: RandomNumberGenerator) -> Dictionary:
	var first_root := rng.randi_range(1, 12)
	var second_root := rng.randi_range(1, 12)
	while second_root == first_root:
		second_root = rng.randi_range(1, 12)
	var sum_roots := first_root + second_root
	var product_roots := first_root * second_root
	var answer := mini(first_root, second_root)
	var expression := "Smallest root: x^2 - %dx + %d = 0; x = ?" % [sum_roots, product_roots]
	return _integer_problem(expression, answer, "quadratics", "hint.quadratics", "quadratic", sum_roots, product_roots, "roots", {
		"root_a": first_root, "root_b": second_root, "sum_roots": sum_roots, "product_roots": product_roots,
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
	var triples: Array = [[3, 4, 5], [5, 12, 13], [8, 15, 17], [7, 24, 25], [9, 40, 41]]
	var triple: Array = triples[rng.randi_range(0, triples.size() - 1)]
	var a := int(triple[0])
	var b := int(triple[1])
	var c := int(triple[2])
	return _integer_problem("Right triangle: legs %d, %d; c = ?" % [a, b], c, "geometry", "hint.geometry", "pythagorean", a, b, "c", {"hypotenuse": c})


static func _hard_trigonometry(rng: RandomNumberGenerator) -> Dictionary:
	var table: Array[Dictionary] = [
		{"expression": "sin(30 deg) = ?", "answer": "1/2"},
		{"expression": "cos(60 deg) = ?", "answer": "1/2"},
		{"expression": "sin(45 deg) = ?", "answer": "sqrt(2)/2"},
		{"expression": "cos(45 deg) = ?", "answer": "sqrt(2)/2"},
		{"expression": "sin(60 deg) = ?", "answer": "sqrt(3)/2"},
		{"expression": "cos(30 deg) = ?", "answer": "sqrt(3)/2"},
		{"expression": "sin(90 deg) = ?", "answer": "1"},
		{"expression": "cos(0 deg) = ?", "answer": "1"},
	]
	var item: Dictionary = table[rng.randi_range(0, table.size() - 1)]
	var pool: Array[String] = ["1/2", "sqrt(2)/2", "sqrt(3)/2", "1", "0"]
	return _problem(str(item.expression), str(item.answer), "trigonometry", "hint.trigonometry", "trigonometry", 0, 1, {"distractor_pool": pool})


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
