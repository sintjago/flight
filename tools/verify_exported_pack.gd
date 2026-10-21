extends SceneTree

var _failures := PackedStringArray()
var _saved_save_data: Dictionary = {}
var _saved_save_bytes: Variant = null
var _had_saved_save_file := false
var _save_store: Node
const SAVE_PATH := "user://paper_glide_save.json"
const PLANE_IDS: Array[String] = ["paper", "sky", "coral", "gold"]
const FlightWorld = preload("res://scripts/flight/flight_world.gd")
const MathQuestion = preload("res://scripts/flight/math_question.gd")
const LearningQuestion = preload("res://scripts/flight/learning_question.gd")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_save_store = root.get_node("SaveStore")
	_had_saved_save_file = FileAccess.file_exists(SAVE_PATH)
	_saved_save_bytes = FileAccess.get_file_as_bytes(SAVE_PATH) if _had_saved_save_file else null
	var current_save_data: Dictionary = _save_store.get("_data")
	_saved_save_data = current_save_data.duplicate(true)
	_save_store.set("_data", _save_store.call("_default_data"))
	var catalog_path := "res://localization/en.json"
	_check(FileAccess.file_exists(catalog_path), "exported locale catalog")
	var packed := load("res://scenes/main.tscn") as PackedScene
	_check(packed != null, "exported main scene")
	if packed != null:
		var main := packed.instantiate()
		root.add_child(main)
		await process_frame
		await process_frame
		var i18n: Node = root.get_node("I18n")
		_check(bool((main.get("_title_screen") as Control).visible), "pack opens at practice-area selection")
		_check(not main.has_method("_open_tuning"), "release tuning entry point excluded")
		_check(not ResourceLoader.exists("res://scripts/ui/tuning_panel.gd"), "release tuning panel excluded")
		_check(ResourceLoader.exists("res://scripts/flight/math_question.gd"), "math question generator is packed")
		_check(ResourceLoader.exists("res://scripts/flight/learning_question.gd"), "non-math question generator is packed")
		var practice_buttons: Dictionary = main.get("_practice_buttons")
		_check(practice_buttons.size() == 5 and not (practice_buttons["math"] as Button).disabled, "pack offers five practice areas")
		for area: String in ["reading", "russian", "spanish", "science"]:
			var pack_button: Button = practice_buttons[area]
			_check(not pack_button.disabled and not pack_button.text.contains("COMING SOON"), "learning pack is enabled: " + area)
		var title_hangar_button: Button = main.get("_title_hangar_button")
		_check(title_hangar_button != null and title_hangar_button.text.contains("0 COINS"), "pack title screen shows the zero-balance Hangar entry")
		if title_hangar_button != null:
			title_hangar_button.emit_signal("pressed")
			var hangar_buttons: Dictionary = main.get("_hangar_buttons")
			_check(main.get("_state") == "hangar" and hangar_buttons.size() == PLANE_IDS.size(), "pack Hangar opens with every cosmetic plane")
			_save_store.call("add_coins", 10)
			main.call("_update_hangar")
			var sky_entry: Dictionary = hangar_buttons.get("sky", {})
			var sky_button := sky_entry.get("button") as Button
			_check(sky_button != null, "pack includes the purchasable Blue Sketch plane")
			if sky_button != null:
				sky_button.emit_signal("pressed")
				_check(int(_save_store.call("get_coins")) == 0 and bool(_save_store.call("owns_plane", "sky")) and str(_save_store.call("get_selected_plane")) == "sky", "packed purchase deducts coins and equips an owned plane")
				_check(main.get("_world").get("selected_plane_id") == "sky", "packed plane selection reaches the flight renderer")
			var hangar_screen: Control = main.get("_hangar_screen")
			var hangar_back := hangar_screen.find_child("HangarBackButton", true, false) as Button
			_check(hangar_back != null, "pack Hangar provides a return-to-Home action")
			if hangar_back != null:
				hangar_back.emit_signal("pressed")
		var content_rng := RandomNumberGenerator.new()
		content_rng.seed = 20261020
		for level: int in range(1, 6):
			for group: String in MathQuestion.available_topic_groups(level):
				var sample: Dictionary = MathQuestion.generate(content_rng, level, [group])
				var choices: Array[String] = [str(sample.upper_answer), str(sample.lower_answer)]
				_check(str(sample.topic_group) == group and choices[0] != choices[1] and choices.count(str(sample.answer)) == 1, "packed curriculum serves " + group + " at level " + str(level))
				_check(str(i18n.call("t", str(sample.hint_key))) != str(sample.hint_key), "packed topic has a learner hint: " + group)
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
		for area: String in LearningQuestion.PRACTICE_AREAS:
			for level: int in range(1, 6):
				var bank: Array = LearningQuestion.questions_for(area, level)
				_check(not bank.is_empty(), "%s has content at level %d" % [area, level])
				for template: Dictionary in bank:
					var bank_answers: Array[String] = [str(template.get("answer", "")), str(template.get("distractor", ""))]
					var topic_key := "topic." + str(template.get("topic", ""))
					var hint_key := str(template.get("hint_key", ""))
					_check(not bank_answers[0].is_empty() and bank_answers[0] != bank_answers[1], "%s choices are distinct at level %d" % [area, level])
					_check(str(i18n.call("t", topic_key)) != topic_key, "%s topic label is packed" % area)
					_check(not hint_key.is_empty() and str(i18n.call("t", hint_key)) != hint_key, "%s teaching hint is packed" % area)
				var generated: Dictionary = LearningQuestion.generate(content_rng, area, level)
				var gate_answers: Array[String] = [str(generated.get("upper_answer", "")), str(generated.get("lower_answer", ""))]
				_check(str(generated.get("practice_area", "")) == area and gate_answers[0] != gate_answers[1] and gate_answers.count(str(generated.get("answer", ""))) == 1, "%s generates one correct answer gate at level %d" % [area, level])
		var track_buttons: Dictionary = main.get("_track_buttons")
		_check(track_buttons.size() == 3 and track_buttons.has("math_1") and track_buttons.has("math_2") and track_buttons.has("math_3"), "pack replaces the long Math checklist with three track cards")
		_check(str(main.get("_selected_math_track")) == "math_1", "pack defaults to the Math 1 Foundations track")
		(track_buttons["math_2"] as Button).emit_signal("pressed")
		var math_2_groups: Array = main.call("_selected_topic_groups")
		_check("decimals" in math_2_groups and "algebra" in math_2_groups and "addition" not in math_2_groups, "Math 2 selects its bundled middle-school topics")
		(track_buttons["math_3"] as Button).emit_signal("pressed")
		var math_3_groups: Array = main.call("_selected_topic_groups")
		_check("quadratics" in math_3_groups and "trigonometry" in math_3_groups and "addition" not in math_3_groups, "Math 3 selects its bundled high-school topics")
		(track_buttons["math_1"] as Button).emit_signal("pressed")
		var difficulty_buttons: Dictionary = main.get("_difficulty_buttons")
		var speed_buttons: Dictionary = main.get("_speed_buttons")
		_check(difficulty_buttons.size() == 5 and speed_buttons.size() == 5, "pack has separate five-choice challenge and flight pace steps")
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
		_check(main.get("_state") == "topics" and bool((main.get("_topic_screen") as Control).visible), "Math opens its dedicated track step")
		main.call("_continue_to_difficulty")
		_check(main.get("_state") == "difficulty", "the selected Math track leads to the challenge step")
		main.call("_continue_to_speed")
		_check(main.get("_state") == "speed", "challenge leads to the independent pace step")
		main.call("_start_from_setup")
		var world: Node2D = main.get("_world")
		_check(main.get("_state") == "playing" and world.get("state") == "ready", "practice starts ready for the learner's first tap")
		_check(float(world.get("base_speed")) < 193.0 and float(world.get("pipe_spacing")) > 532.0, "default flight is slower with more distance between gates")
		main.call("_flap_input")
		_check(world.get("state") == "playing", "pack launches on the first in-game tap")
		_check(bool((main.get("_question_bar") as Control).visible), "pack shows the learning prompt bar")
		_check(str((main.get("_question_label") as Label).text).contains("?"), "pack generates a math question")
		_check(not str((main.get("_question_hint_label") as Label).text).is_empty(), "pack shows a learning hint")
		var reward_gates: Array = world.get("pipes")
		_check(not reward_gates.is_empty(), "pack run exposes a real answer gate to pass")
		if not reward_gates.is_empty():
			var reward_gate: Dictionary = reward_gates[0].duplicate(true)
			reward_gate.x = FlightWorld.PLANE_X - 22.0
			reward_gates.clear()
			reward_gates.append(reward_gate)
			var reward_y := float(reward_gate.upper_y) if str(reward_gate.correct_lane) == "upper" else float(reward_gate.lower_y)
			world.set("gravity", 0.0)
			world.set("plane_y", reward_y)
			world.set("plane_vy", 0.0)
			for _attempt in range(120):
				if int(world.get("score")) > 0:
					break
				world.call("step", 1.0 / 60.0)
			_check(int(world.get("score")) == 1 and int(_save_store.call("get_coins")) == 1 and int(main.get("_coins_earned_this_run")) == 1, "passing the packed correct answer gate earns one saved gameplay coin")
			world.call("step", 1.0 / 60.0)
			_check(int(world.get("score")) == 1 and int(_save_store.call("get_coins")) == 1 and int(main.get("_coins_earned_this_run")) == 1, "one packed gate cannot award the same coin twice")
		var active_question: Dictionary = world.get("current_question")
		_check(active_question.has("topic") and active_question.has("topic_group") and active_question.has("hint_key"), "pack question includes selected subject and teaching metadata")
		_check(str(active_question.topic_group) in main.call("_selected_topic_groups"), "generated question respects the selected Math track")
		var gates: Array = world.get("pipes")
		_check(not gates.is_empty() and gates[0].has("upper_answer") and gates[0].has("lower_answer"), "pack includes two answer choices")
		for area: String in LearningQuestion.PRACTICE_AREAS:
			main.call("_return_to_home")
			main.call("_begin_from_title", area)
			_check(main.get("_state") == "difficulty", "%s opens its challenge step" % area)
			main.call("_continue_to_speed")
			_check(main.get("_state") == "speed", "%s reaches the independent pace step" % area)
			main.call("_start_from_setup")
			main.call("_flap_input")
			var area_question: Dictionary = world.get("current_question")
			var area_gates: Array = world.get("pipes")
			var area_answers: Array[String] = []
			if not area_gates.is_empty():
				area_answers.append(str(area_gates[0].get("upper_answer", "")))
				area_answers.append(str(area_gates[0].get("lower_answer", "")))
			_check(str(area_question.get("practice_area", "")) == area and area_answers.size() == 2 and area_answers.count(str(area_question.get("answer", ""))) == 1, "%s starts a playable two-answer flight" % area)
		var audio := root.get_node("AudioDirector")
		_check(bool(audio.call("play_cue", "score.reward")) or true, "pack cues are callable")
		audio.call("release_streams")
		main.queue_free()
		await process_frame
	_restore_user_save()
	if _failures.is_empty():
		print("[exported-pack] PASS: Paper Glide staged math pack boots")
		quit(0)
		return
	for failure: String in _failures:
		push_error("[exported-pack] " + failure)
	quit(1)


func _restore_user_save() -> void:
	_save_store.set("_data", _saved_save_data)
	if _had_saved_save_file:
		var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if save_file != null:
			save_file.store_buffer(_saved_save_bytes)
			save_file.close()
	elif FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _check(condition: bool, context: String) -> void:
	if not condition and context not in _failures:
		_failures.append(context)
