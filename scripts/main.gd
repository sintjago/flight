extends Control
## Paper Glide: input, game flow and notebook-styled UI around the flight world.

const FlightWorld = preload("res://scripts/flight/flight_world.gd")
const SfxBank = preload("res://scripts/flight/sfx_bank.gd")
const MathQuestion = preload("res://scripts/flight/math_question.gd")
const TITLE_FONT: Font = preload("res://assets/template/fonts/display/generic_title.tres")

const GRAPHITE := Color(0.16, 0.17, 0.2)
const PAPER := Color(0.965, 0.945, 0.885)
const CARD := Color(0.99, 0.975, 0.93)
const BLUE_PENCIL := Color(0.3, 0.5, 0.8)
const RED_PENCIL := Color(0.82, 0.25, 0.22)
const SAGE := Color(0.6, 0.78, 0.5)
const RESTART_LOCKOUT_MS := 550

## "title", "playing", "paused" or "over".
var _state := "title"
var _world: Node2D
var _hud: Control
var _score_label: Label
var _best_label: Label
var _practice_label: Label
var _question_bar: PanelContainer
var _question_label: Label
var _question_hint_label: Label
var _question_difficulty_label: Label
var _pause_button: Button
var _title_screen: Control
var _title_card: PanelContainer
var _title_prompt: Label
var _title_best: Label
var _difficulty_description: Label
var _difficulty_slider: HSlider
var _difficulty_value_label: Label
var _topic_checkboxes: Dictionary = {}
var _topic_selection: Dictionary = {
	"addition_subtraction": true,
	"multiplication_division": true,
	"fractions": true,
	"number_sense": true,
}
var _start_button: Button
var _selected_level := 2
var _selected_difficulty := "easy"
var _over_screen: Control
var _over_card: PanelContainer
var _over_title_label: Label
var _over_score: Label
var _over_best: Label
var _over_feedback: Label
var _over_stamp: Label
var _over_note: Label
var _over_again_button: Button
var _over_easier_button: Button
var _over_home_button: Button
var _pause_screen: Control
var _sound_button: Button
var _over_unlock_ms := 0
var _score_tween: Tween
var _prompt_time := 0.0
var _last_run_practice := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_world()
	_build_hud()
	_build_title()
	_build_over()
	_build_pause()
	SfxBank.register_all(get_node_or_null("/root/AudioDirector"))
	var store := get_node_or_null("/root/TuningStore")
	if store != null:
		store.connect("value_changed", _on_tuning_changed)
	_apply_hud_opacity()
	_show_title()


func _process(delta: float) -> void:
	_prompt_time += delta
	if _title_prompt != null and _title_screen.visible:
		_title_prompt.modulate.a = 0.55 + 0.45 * (0.5 + 0.5 * sin(_prompt_time * 3.6))


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _state == "playing":
		_set_paused(true)


# ------------------------------------------------------------------ building

func _build_world() -> void:
	_world = FlightWorld.new()
	_world.name = "FlightWorld"
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	_world.connect("flapped", _on_flapped)
	_world.connect("scored", _on_scored)
	_world.connect("crashed", _on_crashed)
	_world.connect("question_changed", _on_question_changed)


func _full_rect_control(node_name: String) -> Control:
	var control := Control.new()
	control.name = node_name
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(control)
	return control


func _make_label(text: String, font_size: int, color: Color = GRAPHITE, use_title_font: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if use_title_font:
		label.add_theme_font_override("font", TITLE_FONT)
	return label


func _card_style(border: Color = GRAPHITE) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD
	style.border_color = border
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.shadow_color = Color(0.1, 0.1, 0.15, 0.22)
	style.shadow_size = 0
	style.shadow_offset = Vector2(6, 7)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	return style


func _make_card(size: Vector2, center_y: float) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = size
	card.size = size
	card.position = Vector2((FlightWorld.VIEW_SIZE.x - size.x) * 0.5, center_y - size.y * 0.5)
	card.pivot_offset = size * 0.5
	card.add_theme_stylebox_override("panel", _card_style())
	return card


func _make_button(text: String, font_size: int, fill: Color) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_ALL
	button.custom_minimum_size = Vector2(300, 64)
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", GRAPHITE)
	button.add_theme_color_override("font_hover_color", GRAPHITE)
	button.add_theme_color_override("font_pressed_color", GRAPHITE)
	button.add_theme_color_override("font_focus_color", GRAPHITE)
	for slot in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		var tint := fill
		if slot == "hover":
			tint = fill.lightened(0.18)
		elif slot == "pressed":
			tint = fill.darkened(0.12)
		style.bg_color = tint
		style.border_color = GRAPHITE
		style.set_border_width_all(3)
		style.set_corner_radius_all(14)
		style.shadow_color = Color(0.1, 0.1, 0.15, 0.22)
		style.shadow_offset = Vector2(3, 4) if slot != "pressed" else Vector2(1, 1)
		if slot == "focus":
			style.border_color = BLUE_PENCIL
			style.set_border_width_all(4)
		button.add_theme_stylebox_override(slot, style)
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("register_button", button)
	return button


func _build_hud() -> void:
	_hud = _full_rect_control("Hud")
	_score_label = _make_label("0", 104, GRAPHITE, true)
	_score_label.add_theme_color_override("font_outline_color", PAPER)
	_score_label.add_theme_constant_override("outline_size", 14)
	_score_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_score_label.offset_left = -200
	_score_label.offset_right = 200
	_score_label.offset_top = 14
	_score_label.offset_bottom = 134
	_score_label.pivot_offset = Vector2(200, 60)
	_hud.add_child(_score_label)
	_best_label = _make_label("", 22, Color(GRAPHITE, 0.75))
	_best_label.add_theme_color_override("font_outline_color", PAPER)
	_best_label.add_theme_constant_override("outline_size", 8)
	_best_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_best_label.offset_left = -200
	_best_label.offset_right = 200
	_best_label.offset_top = 124
	_best_label.offset_bottom = 156
	_hud.add_child(_best_label)
	_practice_label = _make_label(I18n.t("hud.practice"), 18, RED_PENCIL)
	_practice_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_practice_label.offset_left = -200
	_practice_label.offset_right = 200
	_practice_label.offset_top = 154
	_practice_label.offset_bottom = 180
	_practice_label.visible = false
	_hud.add_child(_practice_label)
	_build_question_bar()
	_pause_button = Button.new()
	_pause_button.name = "PauseButton"
	_pause_button.tooltip_text = I18n.t("hud.pause")
	_pause_button.focus_mode = Control.FOCUS_NONE
	_pause_button.size = Vector2(58, 58)
	_pause_button.position = Vector2(FlightWorld.VIEW_SIZE.x - 58 - 22, 20)
	for slot in ["normal", "hover", "pressed"]:
		var style := StyleBoxFlat.new()
		style.bg_color = CARD if slot != "hover" else CARD.lightened(0.5)
		if slot == "pressed":
			style.bg_color = CARD.darkened(0.1)
		style.border_color = GRAPHITE
		style.set_border_width_all(3)
		style.set_corner_radius_all(29)
		style.shadow_color = Color(0.1, 0.1, 0.15, 0.2)
		style.shadow_offset = Vector2(2, 3)
		_pause_button.add_theme_stylebox_override(slot, style)
	for bar_x in [19.0, 32.0]:
		var bar := ColorRect.new()
		bar.color = GRAPHITE
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(bar_x, 17)
		bar.size = Vector2(7, 24)
		_pause_button.add_child(bar)
	_pause_button.pressed.connect(func() -> void: _set_paused(true))
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("register_button", _pause_button)
	_hud.add_child(_pause_button)


func _build_question_bar() -> void:
	_question_bar = _make_card(Vector2(760, 138), 646.0)
	var panel_style := _card_style(BLUE_PENCIL)
	panel_style.content_margin_left = 18
	panel_style.content_margin_right = 18
	panel_style.content_margin_top = 7
	panel_style.content_margin_bottom = 7
	panel_style.shadow_size = 2
	_question_bar.add_theme_stylebox_override("panel", panel_style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	_question_difficulty_label = _make_label("", 16, BLUE_PENCIL.darkened(0.2), true)
	box.add_child(_question_difficulty_label)
	_question_label = _make_label(I18n.t("hud.tap_to_launch"), 40, GRAPHITE, true)
	box.add_child(_question_label)
	_question_hint_label = _make_label(I18n.t("hud.question_wait"), 16, Color(GRAPHITE, 0.72))
	box.add_child(_question_hint_label)
	_question_bar.add_child(box)
	_question_bar.visible = false
	_hud.add_child(_question_bar)


func _build_title() -> void:
	_title_screen = _full_rect_control("TitleScreen")
	_title_card = _make_card(Vector2(1080, 620), 360.0)
	_title_screen.add_child(_title_card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_title_card.add_child(box)
	var title := _make_label(I18n.t("game.title").to_upper(), 64, GRAPHITE, true)
	title.add_theme_color_override("font_shadow_color", Color(BLUE_PENCIL, 0.55))
	title.add_theme_constant_override("shadow_offset_x", 4)
	title.add_theme_constant_override("shadow_offset_y", 4)
	box.add_child(title)
	box.add_child(_make_label(I18n.t("title.tagline"), 22, Color(GRAPHITE, 0.85)))
	box.add_child(_make_label(I18n.t("title.howto"), 16, Color(GRAPHITE, 0.72)))
	box.add_child(_make_label(I18n.t("title.choose_difficulty"), 18, BLUE_PENCIL.darkened(0.15), true))
	_difficulty_value_label = _make_label("", 21, GRAPHITE, true)
	box.add_child(_difficulty_value_label)
	var slider_row := HBoxContainer.new()
	slider_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slider_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slider_row.add_theme_constant_override("separation", 14)
	box.add_child(slider_row)
	slider_row.add_child(_make_label(I18n.t("title.slider_easy"), 15, BLUE_PENCIL.darkened(0.2), true))
	_difficulty_slider = HSlider.new()
	_difficulty_slider.name = "DifficultySlider"
	_difficulty_slider.min_value = 0.0
	_difficulty_slider.max_value = 10.0
	_difficulty_slider.step = 1.0
	_difficulty_slider.value = _selected_level
	_difficulty_slider.custom_minimum_size = Vector2(650, 36)
	_difficulty_slider.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_difficulty_slider.focus_mode = Control.FOCUS_ALL
	_difficulty_slider.value_changed.connect(_on_difficulty_slider_changed)
	slider_row.add_child(_difficulty_slider)
	slider_row.add_child(_make_label(I18n.t("title.slider_hard"), 15, BLUE_PENCIL.darkened(0.2), true))
	_difficulty_description = _make_label("", 16, Color(GRAPHITE, 0.72))
	box.add_child(_difficulty_description)
	box.add_child(_make_label(I18n.t("title.choose_content"), 18, BLUE_PENCIL.darkened(0.15), true))
	box.add_child(_make_label(I18n.t("title.topic_unlocks"), 13, Color(GRAPHITE, 0.72)))
	var topic_grid := GridContainer.new()
	topic_grid.name = "TopicCheckboxes"
	topic_grid.columns = 3
	topic_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topic_grid.add_theme_constant_override("h_separation", 20)
	topic_grid.add_theme_constant_override("v_separation", 0)
	box.add_child(topic_grid)
	for group: String in MathQuestion.TOPIC_GROUPS:
		var checkbox := CheckBox.new()
		checkbox.name = "Topic_" + group
		checkbox.text = I18n.t("topic_filter." + group)
		checkbox.custom_minimum_size = Vector2(310, 34)
		checkbox.add_theme_font_size_override("font_size", 18)
		checkbox.add_theme_color_override("font_color", GRAPHITE)
		checkbox.add_theme_color_override("font_hover_color", GRAPHITE)
		checkbox.add_theme_color_override("font_pressed_color", GRAPHITE)
		checkbox.add_theme_color_override("font_focus_color", GRAPHITE)
		checkbox.add_theme_color_override("font_disabled_color", Color(GRAPHITE, 0.72))
		checkbox.focus_mode = Control.FOCUS_ALL
		checkbox.set_pressed_no_signal(bool(_topic_selection.get(group, false)))
		checkbox.toggled.connect(_on_topic_toggled.bind(group))
		_topic_checkboxes[group] = checkbox
		topic_grid.add_child(checkbox)
	_start_button = _make_button(I18n.t("title.start"), 25, SAGE)
	_start_button.custom_minimum_size = Vector2(260, 56)
	_start_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_start_button.pressed.connect(_begin_from_title)
	box.add_child(_start_button)
	_title_prompt = _make_label(I18n.t("title.prompt"), 14, Color(BLUE_PENCIL.darkened(0.15), 0.86), true)
	box.add_child(_title_prompt)
	_title_best = _make_label("", 20, Color(GRAPHITE, 0.8))
	box.add_child(_title_best)
	_set_difficulty_level(_selected_level)


func _on_difficulty_slider_changed(value: float) -> void:
	_set_difficulty_level(roundi(value))


func _set_difficulty_level(level: int) -> void:
	_selected_level = clampi(level, 0, 10)
	_selected_difficulty = MathQuestion.band_for_level(_selected_level)
	if _difficulty_slider != null:
		_difficulty_slider.set_value_no_signal(_selected_level)
	if _difficulty_value_label != null:
		_difficulty_value_label.text = I18n.t("title.level_value", {
			"level": _selected_level,
			"difficulty": I18n.t("difficulty." + _selected_difficulty).to_upper(),
		})
	if _difficulty_description != null:
		_difficulty_description.text = I18n.t("difficulty." + _selected_difficulty + ".description")
	_refresh_topic_checkboxes()
	_update_title_best()


func _select_difficulty(mode: String) -> void:
	_set_difficulty_level(MathQuestion.difficulty_level_for(mode))


func _refresh_topic_checkboxes() -> void:
	var available := MathQuestion.available_topic_groups(_selected_level)
	var has_active_selection := false
	for group: String in available:
		has_active_selection = has_active_selection or bool(_topic_selection.get(group, false))
	if not has_active_selection and not available.is_empty():
		for group: String in available:
			_topic_selection[group] = true
	for group: String in _topic_checkboxes:
		var checkbox: CheckBox = _topic_checkboxes[group]
		checkbox.disabled = group not in available
		checkbox.set_pressed_no_signal(bool(_topic_selection.get(group, false)))
		var locked_key := "title.topic_locked_easy" if group in MathQuestion.EASY_TOPIC_GROUPS else ("title.topic_locked_medium" if group in MathQuestion.MEDIUM_TOPIC_GROUPS else "title.topic_locked_hard")
		checkbox.tooltip_text = "" if group in available else I18n.t(locked_key)


func _on_topic_toggled(checked: bool, group: String) -> void:
	_topic_selection[group] = checked
	var available := MathQuestion.available_topic_groups(_selected_level)
	var has_active_selection := false
	for candidate: String in available:
		has_active_selection = has_active_selection or bool(_topic_selection.get(candidate, false))
	if not has_active_selection and _topic_checkboxes.has(group):
		_topic_selection[group] = true
		(_topic_checkboxes[group] as CheckBox).set_pressed_no_signal(true)


func _selected_topic_groups() -> Array[String]:
	var selected: Array[String] = []
	for group: String in MathQuestion.available_topic_groups(_selected_level):
		if bool(_topic_selection.get(group, false)):
			selected.append(group)
	return selected


func _update_title_best() -> void:
	if _title_best == null:
		return
	var best := _best_score(_selected_difficulty)
	_title_best.text = I18n.t("title.best", {
		"difficulty": I18n.t("difficulty." + _selected_difficulty),
		"score": best,
	}) if best > 0 else ""
	_title_best.visible = best > 0


func _build_over() -> void:
	_over_screen = _full_rect_control("GameOverScreen")
	_over_card = _make_card(Vector2(900, 490), 350.0)
	_over_screen.add_child(_over_card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	_over_card.add_child(box)
	_over_title_label = _make_label(I18n.t("over.title").to_upper(), 44, RED_PENCIL, true)
	box.add_child(_over_title_label)
	box.add_child(_make_label(I18n.t("over.score"), 20, Color(GRAPHITE, 0.8)))
	_over_score = _make_label("0", 82, GRAPHITE, true)
	box.add_child(_over_score)
	_over_feedback = _make_label("", 22, RED_PENCIL)
	_over_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_over_feedback)
	_over_best = _make_label("", 21, Color(GRAPHITE, 0.85))
	box.add_child(_over_best)
	_over_note = _make_label(I18n.t("over.practice"), 14, RED_PENCIL)
	box.add_child(_over_note)
	var actions := HBoxContainer.new()
	actions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 12)
	box.add_child(actions)
	var again := _make_button(I18n.t("over.restart"), 22, SAGE)
	again.name = "RestartButton"
	again.custom_minimum_size = Vector2(220, 58)
	again.pressed.connect(func() -> void: _restart())
	actions.add_child(again)
	_over_easier_button = _make_button(I18n.t("over.lower_retry"), 19, Color(0.98, 0.86, 0.5))
	_over_easier_button.name = "LowerDifficultyButton"
	_over_easier_button.custom_minimum_size = Vector2(280, 58)
	_over_easier_button.pressed.connect(_lower_difficulty_and_restart)
	actions.add_child(_over_easier_button)
	_over_home_button = _make_button(I18n.t("over.home"), 22, Color(0.78, 0.86, 0.96))
	_over_home_button.name = "HomeButton"
	_over_home_button.custom_minimum_size = Vector2(190, 58)
	_over_home_button.pressed.connect(_return_to_home)
	actions.add_child(_over_home_button)
	box.add_child(_make_label(I18n.t("over.choose_action"), 15, Color(GRAPHITE, 0.6)))
	_over_stamp = _make_label(I18n.t("over.new_best"), 34, RED_PENCIL, true)
	_over_stamp.rotation_degrees = 12.0
	_over_stamp.position = Vector2(_over_card.position.x + 480, _over_card.position.y + 135)
	_over_stamp.size = Vector2(220, 50)
	_over_stamp.pivot_offset = Vector2(110, 25)
	_over_stamp.add_theme_color_override("font_outline_color", CARD)
	_over_stamp.add_theme_constant_override("outline_size", 6)
	_over_screen.add_child(_over_stamp)
	_over_again_button = again


func _build_pause() -> void:
	_pause_screen = _full_rect_control("PauseScreen")
	var dim := ColorRect.new()
	dim.color = Color(PAPER, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_screen.add_child(dim)
	var card := _make_card(Vector2(440, 400), 360.0)
	_pause_screen.add_child(card)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	card.add_child(box)
	box.add_child(_make_label(I18n.t("pause.title").to_upper(), 54, GRAPHITE, true))
	var resume := _make_button(I18n.t("pause.resume"), 28, SAGE)
	resume.name = "ResumeButton"
	resume.pressed.connect(func() -> void: _set_paused(false))
	box.add_child(resume)
	var restart := _make_button(I18n.t("pause.restart"), 28, Color(0.98, 0.86, 0.5))
	restart.name = "PauseRestartButton"
	restart.pressed.connect(func() -> void: _restart_from_pause())
	box.add_child(restart)
	_sound_button = _make_button("", 24, Color(0.78, 0.86, 0.96))
	_sound_button.name = "SoundButton"
	_sound_button.pressed.connect(_toggle_sound)
	box.add_child(_sound_button)
	_pause_resume_button = resume


var _pause_resume_button: Button


# ---------------------------------------------------------------------- flow

func _store() -> Node:
	return get_node_or_null("/root/TuningStore")


func _save() -> Node:
	return get_node_or_null("/root/SaveStore")


func _best_score(difficulty: String = "") -> int:
	var save := _save()
	if save == null:
		return 0
	return int(save.call("get_best_score", difficulty)) if not difficulty.is_empty() else int(save.call("get_best_score"))


func _show_title() -> void:
	_state = "title"
	get_tree().paused = false
	_world.call("set_difficulty", _selected_level)
	_world.call("set_selected_topics", _selected_topic_groups())
	_world.call("reset_ready")
	_title_screen.visible = true
	_over_screen.visible = false
	_pause_screen.visible = false
	_question_bar.visible = false
	_pause_button.visible = false
	_score_label.visible = false
	_best_label.visible = false
	_practice_label.visible = false
	_update_title_best()


## Starts a fresh run in the "ready" pose; the first flap launches it.
func _start_new_run() -> void:
	_world.call("set_difficulty", _selected_level)
	_world.call("set_selected_topics", _selected_topic_groups())
	_world.call("reset_ready")
	_title_screen.visible = false
	_over_screen.visible = false
	_pause_screen.visible = false
	_question_bar.visible = true
	_question_difficulty_label.text = I18n.t("hud.question_mode", {
		"level": _selected_level,
		"difficulty": I18n.t("difficulty." + _selected_difficulty).to_upper(),
		"topic": I18n.t("topic.ready").to_upper(),
	})
	_question_label.text = I18n.t("hud.tap_to_launch")
	_question_hint_label.text = I18n.t("hud.question_wait")
	_pause_button.visible = true
	_score_label.visible = true
	_score_label.text = "0"
	_score_label.scale = Vector2.ONE
	_best_label.visible = true
	var best := _best_score(_selected_difficulty)
	_best_label.text = I18n.t("hud.best", {
		"difficulty": I18n.t("difficulty." + _selected_difficulty).to_upper(),
		"score": best,
	})
	_best_label.visible = best > 0
	_practice_label.visible = false
	_state = "playing"


func _begin_from_title() -> void:
	if _state != "title":
		return
	_start_new_run()
	_world.call("flap")
	_after_flap_start()


func _restart() -> void:
	_start_new_run()
	_world.call("flap")
	_after_flap_start()


func _lower_difficulty_and_restart() -> void:
	if _selected_level <= 0:
		return
	_set_difficulty_level(_selected_level - 1)
	_restart()


func _return_to_home() -> void:
	_show_title()


func _restart_from_pause() -> void:
	get_tree().paused = false
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("set_game_paused", false)
	_start_new_run()


func _after_flap_start() -> void:
	var store := _store()
	var practice := store != null and not bool(store.call("is_ranked_eligible"))
	_practice_label.visible = practice


func _flap_input() -> void:
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("unlock_audio")
	match _state:
		"title":
			_start_new_run()
			_world.call("flap")
			_after_flap_start()
		"playing":
			var was_ready: bool = _world.get("state") == "ready"
			_world.call("flap")
			if was_ready:
				_after_flap_start()
		"over":
			pass


func _set_paused(paused: bool) -> void:
	if paused:
		if _state != "playing":
			return
		_state = "paused"
		get_tree().paused = true
		_pause_screen.visible = true
		_update_sound_button()
		_pause_resume_button.grab_focus()
	else:
		if _state != "paused":
			return
		_state = "playing"
		get_tree().paused = false
		_pause_screen.visible = false
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("set_game_paused", paused)
		audio.call("play_cue", "game.pause")


func _toggle_pause() -> void:
	_set_paused(_state == "playing")


func _toggle_sound() -> void:
	var store := _store()
	if store != null:
		var muted: bool = bool(store.call("get_active_value", "audio.master.muted", false))
		store.call("set_value", "audio.master.muted", not muted)
	_update_sound_button()


func _update_sound_button() -> void:
	var store := _store()
	var muted := store != null and bool(store.call("get_active_value", "audio.master.muted", false))
	_sound_button.text = I18n.t("pause.sound_off" if muted else "pause.sound_on")


func _on_flapped() -> void:
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("play_cue", "player.action", randf_range(0.96, 1.06))


func _on_question_changed(question: Dictionary) -> void:
	var expression := str(question.get("expression", "= ?"))
	var difficulty := str(question.get("difficulty", "medium"))
	var level := int(question.get("difficulty_level", _selected_level))
	var topic := str(question.get("topic", "addition"))
	_question_label.text = expression
	var equation_size := 40
	if expression.length() > 22:
		equation_size = 34
	if expression.length() > 30:
		equation_size = 29
	if expression.length() > 40:
		equation_size = 25
	_question_label.add_theme_font_size_override("font_size", equation_size)
	_question_difficulty_label.text = I18n.t("hud.question_mode", {
		"level": level,
		"difficulty": I18n.t("difficulty." + difficulty).to_upper(),
		"topic": I18n.t("topic." + topic).to_upper(),
	})
	_question_hint_label.text = I18n.t(str(question.get("hint_key", "hint.addition")))


func _on_scored(total: int) -> void:
	_score_label.text = I18n.t("hud.score", {"score": total})
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("play_cue", "score.reward", 1.0 + minf(float(total % 10) * 0.012, 0.1))
	var store := _store()
	if store != null and bool(store.call("get_active_value", "ui.reduced_motion", false)):
		return
	if _score_tween != null:
		_score_tween.kill()
	_score_label.scale = Vector2(1.3, 1.3)
	_score_tween = create_tween()
	_score_tween.tween_property(_score_label, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_crashed(total: int, _hit_ground: bool) -> void:
	if _state != "playing":
		return
	_state = "over"
	_over_unlock_ms = Time.get_ticks_msec() + RESTART_LOCKOUT_MS
	var store := _store()
	var ranked := store == null or bool(store.call("is_ranked_eligible"))
	_last_run_practice = not ranked
	var save := _save()
	var is_best := false
	if save != null:
		is_best = bool(save.call("record_run", total, ranked, _selected_difficulty))
	var audio := get_node_or_null("/root/AudioDirector")
	if audio != null:
		audio.call("play_cue", "enemy.impact")
	_pause_button.visible = false
	_question_bar.visible = false
	_score_label.visible = false
	_best_label.visible = false
	_practice_label.visible = false
	var wrong_answer := str(_world.get("failure_reason")) == "wrong_answer"
	_over_title_label.text = I18n.t("over.wrong_title" if wrong_answer else "over.title").to_upper()
	_over_score.text = str(total)
	var best := _best_score(_selected_difficulty)
	_over_best.text = I18n.t("over.best", {
		"difficulty": I18n.t("difficulty." + _selected_difficulty),
		"score": best,
	})
	_over_feedback.visible = wrong_answer
	var hint_key := str(_world.get("failure_hint_key"))
	var hint := I18n.t(hint_key) if not hint_key.is_empty() else ""
	_over_feedback.text = I18n.t("over.wrong_answer", {
		"answer": str(_world.get("failure_answer")),
		"question": str(_world.get("failure_question")),
		"hint": hint,
	}) if wrong_answer else ""
	_over_stamp.visible = is_best
	_over_note.visible = _last_run_practice
	_over_easier_button.disabled = _selected_level == 0
	await get_tree().create_timer(0.7).timeout
	if _state != "over":
		return
	_over_screen.visible = true
	_over_card.modulate.a = 0.0
	_over_card.scale = Vector2(0.92, 0.92)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_over_card, "modulate:a", 1.0, 0.18)
	tween.tween_property(_over_card, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_over_again_button.grab_focus()


func _apply_hud_opacity() -> void:
	var store := _store()
	var opacity := float(store.call("get_active_value", "ui.hud.opacity", 0.94)) if store != null else 1.0
	_hud.modulate.a = opacity


func _on_tuning_changed(id: String, _requested: Variant, _active: Variant) -> void:
	if id == "ui.hud.opacity":
		_apply_hud_opacity()
	elif id == "ui.reduced_motion" or id == "player.visual.scale":
		_world.call("refresh_live_tuning")


# --------------------------------------------------------------------- input

func _is_flap_event(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo and key.keycode in [KEY_SPACE, KEY_UP, KEY_ENTER, KEY_KP_ENTER]
	if event is InputEventJoypadButton:
		var pad := event as InputEventJoypadButton
		return pad.pressed and pad.button_index == JOY_BUTTON_A
	return false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not event.is_echo():
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if _state == "paused":
		return
	if _is_flap_event(event):
		_flap_input()
		get_viewport().set_input_as_handled()
