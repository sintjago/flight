extends SceneTree

const SAVE_PATH := "user://paper_glide_save.json"
const DungeonWorld = preload("res://scripts/dungeon/dungeon_world.gd")
const LearningQuestion = preload("res://scripts/flight/learning_question.gd")

var _failures: Array[String] = []
var _save_store: Node
var _saved_save_data: Dictionary = {}
var _saved_save_bytes: Variant = null
var _had_saved_save_file := false


func _initialize() -> void:
    call_deferred("_run")


func _run() -> void:
    _save_store = root.get_node("SaveStore")
    _had_saved_save_file = FileAccess.file_exists(SAVE_PATH)
    _saved_save_bytes = FileAccess.get_file_as_bytes(SAVE_PATH) if _had_saved_save_file else null
    _saved_save_data = (_save_store.get("_data") as Dictionary).duplicate(true)
    _save_store.set("_data", _save_store.call("_default_data"))

    var packed := load("res://scenes/main.tscn") as PackedScene
    _check(packed != null, "exported main scene loads")
    if packed == null:
        _restore_user_save()
        _finish()
        return

    var main := packed.instantiate() as Control
    _check(main != null, "exported main scene has a Control root")
    if main == null:
        _restore_user_save()
        _finish()
        return

    root.add_child(main)
    await process_frame
    await process_frame

    var practice_buttons: Dictionary = main.get("_practice_buttons")
    _check(practice_buttons.size() == 5, "title offers Math, Reading, Russian, Spanish and Science")
    _check(DungeonWorld.TOTAL_CHAMBERS == 3 and DungeonWorld.TOTAL_ROOMS == 4, "dungeon contains three chambers and a final boss room")
    _check(DungeonWorld.hero_texture_for("paper") != null, "exported hero sprite loads")
    for texture_path: String in [
        "res://assets/dungeon/enemy_ink_slime_runtime.png",
        "res://assets/dungeon/enemy_pencil_bat_runtime.png",
        "res://assets/dungeon/boss_paper_dragon_runtime.png",
        "res://assets/paperglide/fonts/NotoSans-Cyrillic.subset.woff2",
        "res://scripts/flight/answer_report_document.gd",
    ]:
        _check(ResourceLoader.exists(texture_path), "exported resource loads: " + texture_path)

    var hangar_button := main.get("_title_hangar_button") as Button
    if hangar_button != null:
        hangar_button.emit_signal("pressed")
        var hangar_styles: Dictionary = main.get("_hangar_buttons")
        var hangar_cheers: Dictionary = main.get("_hangar_cheer_buttons")
        _check(hangar_styles.size() == 10 and hangar_cheers.size() == 3, "wardrobe retains ten unlockable styles and three cheers")
        var back_button := (main.get("_hangar_screen") as Control).find_child("HangarBackButton", true, false) as Button
        if back_button != null:
            back_button.emit_signal("pressed")
        _check(str(main.get("_state")) == "title", "wardrobe returns to the learning-pack selection")

    main.call("_begin_from_title", "math")
    _check(str(main.get("_state")) == "topics", "Math opens its separate track selection")
    main.call("_continue_to_difficulty")
    main.call("_start_from_setup")

    var world := main.get("_world") as Node2D
    _check(str(main.get("_state")) == "playing" and str(world.get("state")) == "exploring", "starting a pack begins turn-based exploration")
    _check(int(world.get("hearts")) == 3 and int(world.get("room_index")) == 0, "run starts with three hearts in the first chamber")
    _check(str((main.get("_room_label") as Label).text).contains("1/4"), "HUD reports the first of four rooms")
    _check(str((main.get("_question_hint_label") as Label).text).contains("WASD"), "HUD explains grid movement")

    _send_key(main, KEY_D)
    _send_key(main, KEY_D)
    _check(str(world.get("state")) == "combat", "WASD movement reaches and triggers an adjacent foe")
    var answer_buttons: Array = main.get("_answer_choice_buttons")
    var question: Dictionary = world.get("current_question").duplicate(true)
    var options: Array = question.get("answer_options", [])
    var correct_index := int(question.get("correct_index", -1))
    _check(answer_buttons.size() == 2 and options.size() == 2, "combat offers exactly two answer choices")
    _check(question.has("topic") and question.has("topic_group") and question.has("hint_key"), "combat preserves learning topic and hint metadata")

    var wallet_before := int(_save_store.call("get_coins"))
    if correct_index >= 0 and correct_index < options.size() and answer_buttons.size() == 2:
        (answer_buttons[1 - correct_index] as Button).emit_signal("pressed")
    _check(str(world.get("state")) == "feedback" and int(world.get("hearts")) == 2, "a wrong choice costs exactly one heart")
    _check(not str(world.get("failure_answer")).is_empty() and not str(world.get("failure_hint_key")).is_empty(), "wrong-answer feedback includes the correct answer and a hint")
    (main.get("_continue_turn_button") as Button).emit_signal("pressed")
    question = world.get("current_question").duplicate(true)
    correct_index = int(question.get("correct_index", -1))
    if correct_index >= 0 and correct_index < answer_buttons.size():
        (answer_buttons[correct_index] as Button).emit_signal("pressed")
    _check(str(world.get("state")) == "exploring" and not bool(world.get("enemy_alive")) and bool(world.get("exit_unlocked")), "a correct answer defeats the foe and opens the exit")
    _check(int(world.get("score")) == 1 and int(_save_store.call("get_coins")) == wallet_before + 1, "a correct answer awards one score point and one coin")
    _check(bool((main.get("_cheer_label") as Label).visible), "a correct answer displays the selected cheer")

    for _step in range(4):
        _send_key(main, KEY_D)
    _check(int(world.get("room_index")) == 1 and str((main.get("_room_label") as Label).text).contains("2/4"), "the unlocked exit advances to chamber two")
    _send_key(main, KEY_S)
    for _step in range(4):
        _send_key(main, KEY_D)
    _send_key(main, KEY_W)
    _check(str(world.get("state")) == "combat", "the second chamber is reachable on the tile grid")

    for attempt in range(2):
        question = world.get("current_question").duplicate(true)
        correct_index = int(question.get("correct_index", -1))
        if correct_index >= 0 and correct_index < answer_buttons.size():
            (answer_buttons[1 - correct_index] as Button).emit_signal("pressed")
        if attempt == 0:
            _check(int(world.get("hearts")) == 1 and str(world.get("state")) == "feedback", "a second wrong answer removes one more heart")
            (main.get("_continue_turn_button") as Button).emit_signal("pressed")

    await create_timer(0.8).timeout
    _check(str(world.get("state")) == "defeated" and int(world.get("hearts")) == 0, "the third mistake ends the run at zero hearts")
    _check(bool((main.get("_over_screen") as Control).visible), "defeat displays a results screen")
    var answer_history: Array = world.get("answer_history")
    _check(answer_history.size() == 4, "results preserve every answered combat question")

    var review_button := main.get("_over_review_button") as Button
    _check(review_button != null and not review_button.disabled, "results provide answer review")
    if review_button != null:
        review_button.emit_signal("pressed")
        await process_frame
        var report_html := str(main.call("_build_answer_report_html"))
        _check(str(main.get("_state")) == "review" and report_html.contains("Save as PDF"), "answer review retains the PDF export action")
        _check(report_html.contains("data:font/woff2;base64,") and report_html.contains("Paper Glide Noto"), "PDF report embeds its reading font offline")
        var review_back := main.get("_answer_review_back_button") as Button
        if review_back != null:
            review_back.emit_signal("pressed")
        await process_frame
        _check(str(main.get("_state")) == "over", "answer review returns to the results screen")

    for area: String in ["math", "reading", "russian", "spanish", "science"]:
        main.call("_return_to_home")
        main.call("_begin_from_title", area)
        if area == "math":
            main.call("_continue_to_difficulty")
        main.call("_start_from_setup")
        _send_key(main, KEY_D)
        _send_key(main, KEY_D)
        var area_question: Dictionary = world.get("current_question")
        var area_options: Array = area_question.get("answer_options", [])
        _check(str(area_question.get("practice_area", "")) == area and area_options.size() == 2 and area_options.count(str(area_question.get("answer", ""))) == 1, area + " produces a playable two-choice encounter")

    var audio := root.get_node_or_null("AudioDirector")
    if audio != null:
        audio.call("release_streams")
    main.queue_free()
    await process_frame
    _restore_user_save()
    _finish()


func _send_key(main: Control, keycode: int) -> void:
    var event := InputEventKey.new()
    event.keycode = keycode
    event.physical_keycode = keycode
    event.pressed = true
    main.call("_unhandled_input", event)


func _check(condition: bool, description: String) -> void:
    if not condition and description not in _failures:
        _failures.append(description)


func _restore_user_save() -> void:
    _save_store.set("_data", _saved_save_data)
    if _had_saved_save_file:
        var save_file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
        if save_file != null:
            save_file.store_buffer(_saved_save_bytes)
            save_file.close()
    elif FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func _finish() -> void:
    if _failures.is_empty():
        print("[exported-pack] PASS: dungeon exploration, combat, learning packs and answer review")
        quit(0)
        return
    for failure: String in _failures:
        push_error("[exported-pack] " + failure)
    quit(1)
