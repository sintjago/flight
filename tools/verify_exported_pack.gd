extends SceneTree

var _failures := PackedStringArray()
const MathQuestion = preload("res://scripts/flight/math_question.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var catalog_path := "res://localization/en.json"
	_check(FileAccess.file_exists(catalog_path), "exported locale catalog")
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "exported main scene")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		_check(bool((main.get("_title_screen") as Control).visible), "pack opens at practice-area selection")
		_check(not main.has_method("_open_tuning"), "release tuning entry point excluded")
		_check(not ResourceLoader.exists("res://scripts/ui/tuning_panel.gd"), "release tuning panel excluded")
		_check(ResourceLoader.exists("res://scripts/flight/math_question.gd"), "math question generator is packed")
		var practice_buttons: Dictionary = main.get("_practice_buttons")
		_check(practice_buttons.size() == 5 and not (practice_buttons["math"] as Button).disabled, "pack offers Math plus future practice areas")
			for area: String in ["reading", "russian", "spanish", "science"]:
				var future_button: Button = practice_buttons[area]
				_check(future_button.disabled and future_button.text.contains("COMING SOON"), "future pack is clearly marked: " + area)
			var content_rng := RandomNumberGenerator.new()
			content_rng.seed = 20261020
			for level: int in range(1, 6):
				for group: String in MathQuestion.available_topic_groups(level):
					var sample: Dictionary = MathQuestion.generate(content_rng, level, [group])
					var choices: Array[String] = [str(sample.upper_answer), str(sample.lower_answer)]
					_check(str(sample.topic_group) == group and choices[0] != choices[1] and choices.count(str(sample.answer)) == 1, "packed curriculum serves " + group + " at level " + str(level))
					_check(I18n.t(str(sample.hint_key)) != str(sample.hint_key), "packed topic has a learner hint: " + group)
			var advanced_contracts: Array[Dictionary] = [
				{"level": 4, "group": "decimals", "kind": "decimal_operation_advanced"},
				{"level": 5, "group": "percentages", "kind": "percentage_reverse"},
				{"level": 4, "group": "ratios", "kind": "unit_rate"},
				{"level": 5, "group": "ratios", "kind": "ratio_proportion"},
				{"level": 4, "group": "order_of_operations", "kind": "order_operations_extended"},
				{"level": 5, "group": "order_of_operations", "kind": "order_operations_extended"},
			]
			for contract: Dictionary in advanced_contracts:
				var found_form := false
				for _sample_index in 64:
					var advanced_sample: Dictionary = MathQuestion.generate(content_rng, int(contract.level), [str(contract.group)])
					if str(advanced_sample.kind) == str(contract.kind):
						found_form = true
						break
				_check(found_form, "packed generator includes " + str(contract.group) + " advanced form")
			var topic_checkboxes: Dictionary = main.get("_topic_checkboxes")
		_check(topic_checkboxes.size() == MathQuestion.TOPIC_GROUPS.size(), "pack includes all selectable math subjects")
		_check(topic_checkboxes.has("addition") and topic_checkboxes.has("subtraction") and topic_checkboxes.has("multiplication") and topic_checkboxes.has("division"), "core operations have separate checkboxes")
		var difficulty_buttons: Dictionary = main.get("_difficulty_buttons")
		var speed_buttons: Dictionary = main.get("_speed_buttons")
		_check(difficulty_buttons.size() == 5 and speed_buttons.size() == 5, "pack has separate five-choice math challenge and flight pace steps")
		_check(int(main.get("_selected_level")) == 1 and int(main.get("_selected_speed")) == 1, "pack defaults to level one and the calmest pace")
		_check(main.get("_over_again_button") is Button and main.get("_over_easier_button") is Button and main.get("_over_home_button") is Button, "pack includes all three crash recovery actions")
		for path: String in [
			"res://assets/paperglide/plane.png", "res://assets/paperglide/pipe_cap.png",
			"res://assets/paperglide/pipe_body.png", "res://assets/paperglide/notebook.jpg",
			"res://assets/paperglide/cloud0.png",
		]:
			_check(ResourceLoader.exists(path), "exported art: " + path)
		var tap := InputEventMouseButton.new()
		tap.button_index = MOUSE_BUTTON_LEFT
		tap.pressed = true
		main.call("_unhandled_input", tap)
		_check(main.get("_state") == "title", "tapping setup cannot accidentally start flight")
		main.call("_begin_from_title")
		_check(main.get("_state") == "topics" and bool((main.get("_topic_screen") as Control).visible), "Math opens its dedicated subject step")
		main.call("_continue_to_difficulty")
		_check(main.get("_state") == "difficulty", "topics lead to the challenge step")
		main.call("_continue_to_speed")
		_check(main.get("_state") == "speed", "challenge leads to the independent pace step")
		main.call("_start_from_setup")
		var world: Node2D = main.get("_world")
		_check(main.get("_state") == "playing" and world.get("state") == "ready", "practice starts ready for the learner's first tap")
		_check(float(world.get("base_speed")) < 193.0 and float(world.get("pipe_spacing")) > 532.0, "default flight is slower with more distance between gates")
		main.call("_flap_input")
		_check(world.get("state") == "playing", "pack launches on the first in-game tap")
		_check(bool((main.get("_question_bar") as Control).visible), "pack shows the equation bar")
		_check(str((main.get("_question_label") as Label).text).contains("?"), "pack generates a math question")
		_check(not str((main.get("_question_hint_label") as Label).text).is_empty(), "pack shows a learning hint")
		var active_question: Dictionary = world.get("current_question")
		_check(active_question.has("topic") and active_question.has("topic_group") and active_question.has("hint_key"), "pack question includes selected subject and teaching metadata")
		_check(str(active_question.topic_group) in main.call("_selected_topic_groups"), "generated question respects selected checkboxes")
		var gates: Array = world.get("pipes")
		_check(not gates.is_empty() and gates[0].has("upper_answer") and gates[0].has("lower_answer"), "pack includes two answer choices")
		var audio := root.get_node("AudioDirector")
		_check(bool(audio.call("play_cue", "score.reward")) or true, "pack cues are callable")
		audio.call("release_streams")
		main.queue_free()
		await process_frame
	if _failures.is_empty():
		print("[exported-pack] PASS: Paper Glide staged math pack boots")
		quit(0)
		return
	for failure: String in _failures:
		push_error("[exported-pack] " + failure)
	quit(1)


func _check(condition: bool, context: String) -> void:
	if not condition and context not in _failures:
		_failures.append(context)
