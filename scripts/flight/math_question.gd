extends RefCounted
## Generates one integer equation with exactly two distinct answer choices.

const DIFFICULTIES := ["easy", "medium", "hard"]


static func generate(rng: RandomNumberGenerator, difficulty: String) -> Dictionary:
	var mode := difficulty if difficulty in DIFFICULTIES else "medium"
	var a := 0
	var b := 0
	var operator := "+"
	match mode:
		"easy":
			operator = "+" if rng.randi_range(0, 1) == 0 else "-"
			if operator == "+":
				a = rng.randi_range(1, 10)
				b = rng.randi_range(1, 10)
			else:
				a = rng.randi_range(2, 20)
				b = rng.randi_range(1, a)
		"medium":
			match rng.randi_range(0, 2):
				0:
					operator = "+"
					a = rng.randi_range(15, 89)
					b = rng.randi_range(10, 79)
				1:
					operator = "-"
					a = rng.randi_range(30, 99)
					b = rng.randi_range(10, a)
				_:
					operator = "×"
					a = rng.randi_range(3, 12)
					b = rng.randi_range(3, 12)
		"hard":
			match rng.randi_range(0, 3):
				0:
					operator = "+"
					a = rng.randi_range(150, 899)
					b = rng.randi_range(100, 799)
				1:
					operator = "-"
					a = rng.randi_range(200, 999)
					b = rng.randi_range(50, a)
				2:
					operator = "×"
					a = rng.randi_range(12, 29)
					b = rng.randi_range(12, 29)
				_:
					operator = "÷"
					b = rng.randi_range(3, 19)
					var quotient := rng.randi_range(12, 89)
					a = b * quotient

	var answer := 0
	match operator:
		"+":
			answer = a + b
		"-":
			answer = a - b
		"×":
			answer = a * b
		"÷":
			answer = int(a / b)

	var distractor := _make_distractor(answer, mode, rng)
	var expression := "%d %s %d = ?" % [a, operator, b]
	var lane := "upper" if rng.randi_range(0, 1) == 0 else "lower"
	return {
		"expression": expression,
		"a": a,
		"b": b,
		"operator": operator,
		"answer": answer,
		"distractor": distractor,
		"upper_answer": answer if lane == "upper" else distractor,
		"lower_answer": distractor if lane == "upper" else answer,
		"correct_lane": lane,
		"difficulty": mode,
	}


static func _make_distractor(answer: int, difficulty: String, rng: RandomNumberGenerator) -> int:
	var offsets: Array[int] = [1, 2, 3]
	if difficulty == "medium":
		offsets = [2, 3, 5, 7]
	elif difficulty == "hard":
		offsets = [5, 7, 10, 25, 50]
	var offset: int = offsets[rng.randi_range(0, offsets.size() - 1)]
	var distractor := maxi(0, answer + offset if rng.randi_range(0, 1) == 0 else answer - offset)
	if distractor == answer:
		distractor = answer + offset
	return distractor
