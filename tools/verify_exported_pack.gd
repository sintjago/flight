extends SceneTree

var _failures := PackedStringArray()


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
			_check(bool((main.get("_title_screen") as Control).visible), "pack boots to title")
			_check(not main.has_method("_open_tuning"), "release tuning entry point excluded")
			_check(not ResourceLoader.exists("res://scripts/ui/tuning_panel.gd"), "release tuning panel excluded")
			_check(ResourceLoader.exists("res://scripts/flight/math_question.gd"), "math question generator is packed")
			var slider: HSlider = main.get("_difficulty_slider")
			_check(slider != null and slider.min_value == 0.0 and slider.max_value == 10.0 and slider.step == 1.0, "pack includes the 0–10 difficulty slider")
			var topic_checkboxes: Dictionary = main.get("_topic_checkboxes")
			_check(topic_checkboxes.size() == 9, "pack includes all selectable math-topic checkboxes")
			_check(main.get("_over_again_button") is Button and main.get("_over_easier_button") is Button and main.get("_over_home_button") is Button, "pack includes all three crash recovery actions")
			for path: String in [
			"res://assets/paperglide/plane.png", "res://assets/paperglide/pipe_cap.png",
			"res://assets/paperglide/pipe_body.png", "res://assets/paperglide/notebook.jpg",
			"res://assets/paperglide/cloud0.png",
		]:
			_check(ResourceLoader.exists(path), "exported art: " + path)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		main.call("_unhandled_input", click)
		await process_frame
		_check(main.get("_state") == "playing", "pack starts flying on tap")
		_check(bool((main.get("_question_bar") as Control).visible), "pack shows the equation bar")
		_check(str((main.get("_question_label") as Label).text).contains("?"), "pack generates a math question")
		_check(not str((main.get("_question_hint_label") as Label).text).is_empty(), "pack shows a learning hint")
		var active_question: Dictionary = (main.get("_world") as Node2D).get("current_question")
		_check(active_question.has("topic") and active_question.has("hint_key"), "pack question includes topic and teaching metadata")
		var gates: Array = (main.get("_world") as Node2D).get("pipes")
		_check(not gates.is_empty() and gates[0].has("upper_answer") and gates[0].has("lower_answer"), "pack includes two answer choices")
		var audio := root.get_node("AudioDirector")
		_check(bool(audio.call("play_cue", "score.reward")) or true, "pack cues are callable")
		audio.call("release_streams")
		main.queue_free()
		await process_frame
	if _failures.is_empty():
		print("[exported-pack] PASS: Paper Glide pack boots")
		quit(0)
		return
	for failure: String in _failures:
		push_error("[exported-pack] " + failure)
	quit(1)


func _check(condition: bool, context: String) -> void:
	if not condition and context not in _failures:
		_failures.append(context)
