extends Control

const QUESTIONS_PATH := "res://data/questions.json"
const INTRO_BACKGROUND := preload("res://assets/images/main_background_v2.png")
const QUESTION_BACKGROUND := preload("res://assets/images/blank-computer.png")
const INTRO_HOTSPOTS := {
	"HR": Rect2(0.13, 0.40, 0.29, 0.30),
	"IT": Rect2(0.53, 0.40, 0.32, 0.30),
	"Business": Rect2(0.02, 0.66, 0.41, 0.33),
	"Operations": Rect2(0.52, 0.66, 0.34, 0.33),
}
const QUESTION_SCREEN_RECT := Rect2(0.095, 0.112, 0.810, 0.658)

@onready var background: TextureRect = $Background
@onready var environment_value_label: Label = $TopScorePanel/ScoreRow/EnvironmentValueLabel
@onready var budget_value_label: Label = $TopScorePanel/ScoreRow/BudgetValueLabel
@onready var intro_layer: Control = $IntroLayer
@onready var screen_area: Control = $ScreenArea
@onready var back_button: Button = $ScreenArea/VBoxContainer/BackButton
@onready var title_label: Label = $ScreenArea/VBoxContainer/TitleLabel
@onready var category_label: Label = $ScreenArea/VBoxContainer/CategoryLabel
@onready var round_label: Label = $ScreenArea/VBoxContainer/RoundLabel
@onready var description_label: Label = $ScreenArea/VBoxContainer/DescriptionLabel
@onready var choice_buttons: Array[Button] = [
	$ScreenArea/VBoxContainer/ChoiceButton,
	$ScreenArea/VBoxContainer/ChoiceButton2,
	$ScreenArea/VBoxContainer/ChoiceButton3,
]
@onready var feedback_label: Label = $ScreenArea/VBoxContainer/FeedbackLabel
@onready var next_button: Button = $ScreenArea/VBoxContainer/NextButton
@onready var category_buttons := {
	"Business": $IntroLayer/BusinessButton,
	"HR": $IntroLayer/HRButton,
	"IT": $IntroLayer/ITButton,
	"Operations": $IntroLayer/OperationsButton,
}
@onready var info_button: Button = $ScreenArea/infobutton

var all_base_questions: Array[Dictionary] = []
var all_triggered_questions: Array[Dictionary] = []
var base_questions: Array[Dictionary] = []
var triggered_questions: Array[Dictionary] = []
var remaining_questions: Array[Dictionary] = []
var pending_triggered_questions: Array[Dictionary] = []
var current_question: Dictionary = {}
var selected_category := ""
var category_sessions := {}
var is_showing_end_screen := false
var all_events: Array[Dictionary] = []
var pending_events: Array[Dictionary] = []
var queued_event: Dictionary = {}
var queued_event_question: Dictionary = {}
var shown_event_ids := {}
var selected_choice_index := -1
var selected_choice: Dictionary = {}


func _ready() -> void:
	randomize()
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	for index in range(choice_buttons.size()):
		choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
	for category_name in category_buttons.keys():
		var button: Button = category_buttons[category_name]
		button.pressed.connect(_on_category_selected.bind(category_name))
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.pressed.connect(_on_back_button_pressed)
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	info_button.pressed.connect(_on_info_button_pressed)
	info_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	
	next_button.pressed.connect(_on_next_button_pressed)
	resized.connect(_update_background_layout)
	load_questions()
	update_score_labels()
	show_intro_screen()


func load_questions() -> void:
	var file := FileAccess.open(QUESTIONS_PATH, FileAccess.READ)
	if file == null:
		show_loading_error("Unable to read the questions file.")
		return

	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	if parse_error != OK:
		show_loading_error("The questions file contains a JSON error.")
		return

	var data: Dictionary = json.data

	all_base_questions.clear()
	all_triggered_questions.clear()
	all_events.clear()

	var raw_events: Array = data.get("events", [])
	for raw_event in raw_events:
		if raw_event is Dictionary:
			all_events.append(raw_event)

	var questions: Array = data.get("questions", [])
	for raw_question in questions:
		if raw_question is Dictionary:
			var question: Dictionary = raw_question
			if question.has("trigger"):
				all_triggered_questions.append(question)
			else:
				all_base_questions.append(question)

	var initial_scores: Dictionary = data.get("initial_scores", {})
	GameState.configure(
		int(initial_scores.get("environment", 50)),
		int(initial_scores.get("money", 50)),
		all_base_questions.size()
	)


func show_intro_screen() -> void:
	reset_text_styles()

	if not selected_category.is_empty():
		save_current_session()

	selected_category = ""
	current_question = {}
	is_showing_end_screen = false
	feedback_label.text = ""
	next_button.visible = false
	background.texture = INTRO_BACKGROUND
	intro_layer.visible = true
	screen_area.visible = false
	info_button.visible = false
	update_score_labels()
	_update_background_layout()


func start_category_game(category_name: String) -> void:
	pending_events.clear()
	for event in all_events:
		if str(event.get("category", "")) == category_name or str(event.get("category", "")) == "General":
			pending_events.append(event)

	selected_category = category_name
	base_questions = filter_questions_for_category(all_base_questions, category_name)
	triggered_questions = filter_questions_for_category(all_triggered_questions, category_name)

	if base_questions.is_empty():
		show_loading_error("No questions were found for the %s category." % category_name)
		return

	background.texture = QUESTION_BACKGROUND
	intro_layer.visible = false
	screen_area.visible = true
	_update_background_layout()

	if restore_category_session(category_name):
		return

	if category_sessions.is_empty():
		GameState.reset_game()
	else:
		GameState.round_number = 0

	remaining_questions = base_questions.duplicate(true)
	pending_triggered_questions = triggered_questions.duplicate(true)
	GameState.max_rounds = remaining_questions.size()
	current_question = {}
	is_showing_end_screen = false
	feedback_label.text = ""
	next_button.visible = false
	next_button.text = "Next"
	update_score_labels()
	load_next_question()


func filter_questions_for_category(source_questions: Array[Dictionary], category_name: String) -> Array[Dictionary]:
	var filtered_questions: Array[Dictionary] = []
	for question in source_questions:
		if str(question.get("category", "")) == category_name:
			filtered_questions.append(question)
	return filtered_questions


func load_next_question() -> void:
	if remaining_questions.is_empty():
		show_end_screen()
		return

	current_question = remaining_questions.pop_front()
	is_showing_end_screen = false
	display_question(current_question)
	update_score_labels()
	save_current_session()


func display_question(question: Dictionary) -> void:

	reset_text_styles()

	title_label.visible = true
	category_label.visible = true
	round_label.visible = true
	description_label.visible = true
	feedback_label.visible = true

	title_label.text = str(question.get("title", "Question"))
	category_label.text = "Category: %s" % question.get("category", "General")
	round_label.text = "Question %d / %d" % [GameState.round_number + 1, GameState.max_rounds]
	description_label.text = str(question.get("question", ""))
	feedback_label.text = ""
	next_button.visible = false
	info_button.visible = str(question.get("info", "")).strip_edges() != ""

	var choices: Array = question.get("choices", [])

	for index in range(choice_buttons.size()):
		var button := choice_buttons[index]

		if index < choices.size():
			var choice: Dictionary = choices[index]
			button.visible = true
			button.disabled = false
			button.text = "%s. %s" % [choice.get("id", ""), choice.get("text", "")]
		else:
			button.visible = false

	back_button.visible = true

	if int(question.get("id", 0)) < 0:
		round_label.text = "Event"
	else:
		round_label.text = "Question %d / %d" % [GameState.round_number + 1, GameState.max_rounds]
		
	selected_choice_index = -1
	selected_choice = {}


func _on_choice_pressed(index: int) -> void:
	if current_question.is_empty():
		return

	var choices: Array = current_question.get("choices", [])
	if index >= choices.size():
		return

	selected_choice_index = index
	selected_choice = choices[index]

	var impact: Dictionary = selected_choice.get("impact", {})
	var environment_change := int(impact.get("environment", 0))
	var money_change := int(impact.get("money", 0))

	# Visa preview (men ändra INTE GameState)
	feedback_label.text = "Impact: environment %s%d | budget %s%d" % [
		format_signed_value(environment_change),
		abs(environment_change),
		format_signed_value(money_change),
		abs(money_change),
	]

	for i in range(choice_buttons.size()):
		var button := choice_buttons[i]
		if i < choices.size():
			var choice: Dictionary = choices[i]
			if i == selected_choice_index:
				button.text = "✓ %s. %s" % [choice.get("id", ""), choice.get("text", "")]
			else:
				button.text = "%s. %s" % [choice.get("id", ""), choice.get("text", "")]

	next_button.text = "View results" if remaining_questions.is_empty() else "Next"
	next_button.visible = true

func unlock_triggered_questions(answered_question: Dictionary, selected_choice: Dictionary) -> void:
	for index in range(pending_triggered_questions.size() - 1, -1, -1):
		var candidate: Dictionary = pending_triggered_questions[index]
		var trigger: Dictionary = candidate.get("trigger", {})
		var depends_on := int(trigger.get("depends_on_question_id", -1))
		var expected_choice := str(trigger.get("choice_id", ""))
		var probability := float(trigger.get("probability", 1.0))

		if depends_on == int(answered_question.get("id", -1)) and expected_choice == str(selected_choice.get("id", "")):
			if randf() <= probability:
				remaining_questions.append(candidate)
				GameState.max_rounds += 1
			pending_triggered_questions.remove_at(index)

	remaining_questions.shuffle()


func update_score_labels() -> void:
	environment_value_label.text = "Environment %d" % GameState.environment_score
	budget_value_label.text = "Budget %d" % GameState.economy_score


func show_end_screen() -> void:
	current_question = {}
	is_showing_end_screen = true
	title_label.text = "%s complete" % selected_category
	category_label.text = "Category: %s" % selected_category
	round_label.text = "Final score"
	description_label.text = "Overall balance: %d\nEnvironment: %d\nBudget: %d" % [
		GameState.get_balance_score(),
		GameState.environment_score,
		GameState.economy_score,
	]
	feedback_label.text = "The balance score rewards choices that protect both dimensions."
	for button in choice_buttons:
		button.visible = false
	back_button.visible = true
	next_button.text = "Replay category"
	next_button.visible = true
	info_button.visible = false
	update_score_labels()
	save_current_session()


func show_loading_error(message: String) -> void:
	background.texture = QUESTION_BACKGROUND
	intro_layer.visible = false
	screen_area.visible = true
	is_showing_end_screen = false
	_update_background_layout()
	title_label.text = "Error"
	category_label.text = ""
	round_label.text = ""
	description_label.text = message
	feedback_label.text = "Check the file %s." % QUESTIONS_PATH
	for button in choice_buttons:
		button.visible = false
	back_button.visible = true
	next_button.visible = false
	info_button.visible = false
	update_score_labels()


func _on_next_button_pressed() -> void:

	if current_question.is_empty() and title_label.text.to_lower() == "game over":
		reset_full_game()
		return

	if int(current_question.get("id", 0)) < 0:
		current_question = {}
		show_intro_screen()
		return

	if current_question.is_empty():
		if selected_category.is_empty():
			show_intro_screen()
			return
		if is_showing_end_screen:
			category_sessions.erase(selected_category)
			start_category_game(selected_category)
			return
		start_category_game(selected_category)
		return
		
	if not selected_choice.is_empty():
		var impact: Dictionary = selected_choice.get("impact", {})
		var environment_change := int(impact.get("environment", 0))
		var money_change := int(impact.get("money", 0))

		GameState.apply_choice(
			environment_change,
			money_change,
			int(current_question.get("id")),
			selected_choice
		)

		update_score_labels()

		if check_game_over():
			return

		unlock_triggered_questions(current_question, selected_choice)

		selected_choice_index = -1
		selected_choice = {}
	
	load_next_question()


func _on_category_selected(category_name: String) -> void:
	start_category_game(category_name)


func _on_back_button_pressed() -> void:
	save_current_session()
	show_intro_screen()
	await get_tree().process_frame
	try_show_event_popup_on_intro()


func format_signed_value(value: int) -> String:
	if value >= 0:
		return "+"
	return "-"


func _update_background_layout() -> void:
	if intro_layer.visible:
		_update_intro_hotspots()
	if screen_area.visible:
		_update_question_screen_area()


func _update_intro_hotspots() -> void:
	var texture := background.texture
	if texture == null:
		return

	var image_rect := get_displayed_image_rect(texture.get_size(), size)
	for category_name in category_buttons.keys():
		var normalized_rect: Rect2 = INTRO_HOTSPOTS[category_name]
		var button: Button = category_buttons[category_name]
		button.position = image_rect.position + Vector2(
			image_rect.size.x * normalized_rect.position.x,
			image_rect.size.y * normalized_rect.position.y
		)
		button.size = Vector2(
			image_rect.size.x * normalized_rect.size.x,
			image_rect.size.y * normalized_rect.size.y
		)


func _update_question_screen_area() -> void:
	var texture := background.texture
	if texture == null:
		return

	var image_rect := get_displayed_image_rect(texture.get_size(), size)
	screen_area.position = image_rect.position + Vector2(
		image_rect.size.x * QUESTION_SCREEN_RECT.position.x,
		image_rect.size.y * QUESTION_SCREEN_RECT.position.y
	)
	screen_area.size = Vector2(
		image_rect.size.x * QUESTION_SCREEN_RECT.size.x,
		image_rect.size.y * QUESTION_SCREEN_RECT.size.y
	)


func save_current_session() -> void:
	if selected_category.is_empty():
		return

	category_sessions[selected_category] = {
		"remaining_questions": remaining_questions.duplicate(true),
		"pending_triggered_questions": pending_triggered_questions.duplicate(true),
		"current_question": current_question.duplicate(true),
		"feedback_text": feedback_label.text,
		"next_visible": next_button.visible,
		"next_text": next_button.text,
		"buttons_locked": are_choice_buttons_locked(),
		"is_showing_end_screen": is_showing_end_screen,
		"pending_events": pending_events.duplicate(true),
	}


func restore_category_session(category_name: String) -> bool:
	if not category_sessions.has(category_name):
		return false

	var session: Dictionary = category_sessions[category_name]

	remaining_questions = session.get("remaining_questions", []).duplicate(true)
	pending_triggered_questions = session.get("pending_triggered_questions", []).duplicate(true)
	pending_events = session.get("pending_events", []).duplicate(true)
	current_question = session.get("current_question", {}).duplicate(true)

	feedback_label.text = str(session.get("feedback_text", ""))
	next_button.visible = bool(session.get("next_visible", false))
	next_button.text = str(session.get("next_text", "Next"))
	is_showing_end_screen = bool(session.get("is_showing_end_screen", false))

	update_score_labels()

	if is_showing_end_screen:
		show_end_screen()
		return true

	if current_question.is_empty():
		load_next_question()
		return true

	display_question(current_question)
	feedback_label.text = str(session.get("feedback_text", ""))
	next_button.visible = bool(session.get("next_visible", false))
	next_button.text = str(session.get("next_text", "Next"))

	if bool(session.get("buttons_locked", false)):
		for button in choice_buttons:
			button.disabled = true

	return true


func are_choice_buttons_locked() -> bool:
	for button in choice_buttons:
		if button.visible and button.disabled:
			return true
	return false


func get_displayed_image_rect(texture_size: Vector2, available_size: Vector2) -> Rect2:
	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Rect2(Vector2.ZERO, available_size)

	var texture_ratio := texture_size.x / texture_size.y
	var available_ratio := available_size.x / available_size.y

	if available_ratio > texture_ratio:
		var height := available_size.y
		var width := height * texture_ratio
		var x := (available_size.x - width) * 0.5
		return Rect2(Vector2(x, 0.0), Vector2(width, height))

	var width := available_size.x
	var height := width / texture_ratio
	var y := (available_size.y - height) * 0.5
	return Rect2(Vector2(0.0, y), Vector2(width, height))


func check_and_trigger_event() -> void:
	for i in range(pending_events.size() - 1, -1, -1):
		var event: Dictionary = pending_events[i]

		if GameState.round_number < int(event.get("trigger_after_round", 999)):
			continue

		var event_question: Dictionary = build_event_question(event)
		remaining_questions.push_front(event_question)
		GameState.max_rounds += 1
		pending_events.remove_at(i)
		return



func build_event_question(event: Dictionary) -> Dictionary:
	var result_text := ""
	var env := 0
	var money := 0

	if event.get("type") == "flag":
		var flag := str(event.get("flag", ""))
		var value := str(GameState.decision_flags.get(flag, "medium"))

		for outcome in event.get("outcomes", []):
			if str(outcome.get("value", "")) == value:
				result_text = str(outcome.get("text", ""))
				env = int(outcome.get("impact", {}).get("environment", 0))
				money = int(outcome.get("impact", {}).get("money", 0))
				break

	elif event.get("type") == "answer":
		var question_id := int(event.get("question_id", -1))

		if not GameState.answers.has(question_id):
			return {}

		var value := str(GameState.answers.get(question_id, ""))

		for outcome in event.get("outcomes", []):
			if str(outcome.get("value", "")) == value:
				result_text = str(outcome.get("text", ""))
				env = int(outcome.get("impact", {}).get("environment", 0))
				money = int(outcome.get("impact", {}).get("money", 0))
				break

	elif event.get("type") == "multi_answer_score":
		var question_ids: Array = event.get("question_ids", [])
		var good_choices: Dictionary = event.get("good_choices", {})
		var bad_choices: Dictionary = event.get("bad_choices", {})

		var good_count := 0
		var bad_count := 0

		for question_id in question_ids:
			var qid := int(question_id)
			var answer := str(GameState.answers.get(qid, ""))
			var qid_key := str(qid)

			var good_for_question: Array = good_choices.get(qid_key, [])
			var bad_for_question: Array = bad_choices.get(qid_key, [])

			if good_for_question.has(answer):
				good_count += 1
			elif bad_for_question.has(answer):
				bad_count += 1

		var result_value := "medium"

		if good_count >= 3 and bad_count == 0:
			result_value = "good"
		elif bad_count >= 2:
			result_value = "bad"

		for outcome in event.get("outcomes", []):
			if str(outcome.get("value", "")) == result_value:
				result_text = str(outcome.get("text", ""))
				env = int(outcome.get("impact", {}).get("environment", 0))
				money = int(outcome.get("impact", {}).get("money", 0))
				break

	if result_text.is_empty():
		return {}

	return {
		"id": -1000,
		"category": event.get("category", "Event"),
		"title": event.get("title", event.get("id", "Event")),
		"question": result_text,
		"choices": [
			{
				"id": "OK",
				"text": "Continue",
				"impact": {
					"environment": env,
					"money": money
				}
			}
		]
	}

func try_trigger_event_now() -> bool:
	for i in range(pending_events.size() - 1, -1, -1):
		var event: Dictionary = pending_events[i]

		# Only trigger if flag exists
		if event.has("flag"):
			var flag = event.get("flag")
			if not GameState.decision_flags.has(flag):
				continue

		#  BUILD EVENT
		var event_question: Dictionary = build_event_question(event)

		# Hide round counter (important!)
		round_label.text = "Event"

		pending_events.remove_at(i)
		return true

	return false

func try_show_queued_event_on_intro() -> void:
	for i in range(pending_events.size() - 1, -1, -1):
		var event: Dictionary = pending_events[i]

		if event.has("flag"):
			var flag := str(event.get("flag", ""))
			if not GameState.decision_flags.has(flag):
				continue

		queued_event = build_event_question(event)
		pending_events.remove_at(i)

		show_sudden_event_dialog(queued_event)
		save_current_session()
		return



func try_show_event_popup_on_intro() -> void:
	for i in range(pending_events.size() - 1, -1, -1):
		var event: Dictionary = pending_events[i]
		var event_id := str(event.get("id", "%s_%s" % [
			event.get("category", "General"),
			event.get("title", "Event")
		]))
		if event.get("type") == "flag":
			var flag := str(event.get("flag", ""))
			if not GameState.decision_flags.has(flag):
				continue

		if event.get("type") == "answer":
			var question_id := int(event.get("question_id", -1))
			if not GameState.answers.has(question_id):
				continue
		
		if event.get("type") == "multi_answer_score":
			var question_ids: Array = event.get("question_ids", [])
			var all_answered := true

			for question_id in question_ids:
				if not GameState.answers.has(int(question_id)):
					all_answered = false
					break

			if not all_answered:
				continue

		queued_event_question = build_event_question(event)

		if queued_event_question.is_empty():
			continue
		if shown_event_ids.has(event_id):
			continue

		shown_event_ids[event_id] = true
		pending_events.remove_at(i)
		show_sudden_event_dialog(queued_event_question)
		save_current_session()
		return

func show_sudden_event_dialog(event_question: Dictionary) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "⚠ Sudden Event"
	dialog.dialog_text = "%s\n\n%s" % [
		str(event_question.get("title", "Event")),
		str(event_question.get("question", ""))
	]

	dialog.min_size = Vector2(600, 300)
	dialog.exclusive = true

	add_child(dialog)
	dialog.popup_centered()

	dialog.confirmed.connect(func():
		apply_event_impact(event_question)
		dialog.queue_free()
		update_score_labels()
	)

func apply_event_impact(event_question: Dictionary) -> void:
	var choices: Array = event_question.get("choices", [])
	if choices.is_empty():
		return

	var choice: Dictionary = choices[0]
	var impact: Dictionary = choice.get("impact", {})

	var environment_change := int(impact.get("environment", 0))
	var money_change := int(impact.get("money", 0))

	GameState.apply_choice(
		environment_change,
		money_change,
		int(event_question.get("id", -1000)),
		choice
	)
	update_score_labels()
	check_game_over()

func check_game_over() -> bool:
	if GameState.economy_score <= 0:
		GameState.economy_score = 0
		show_game_over_screen("Budget depleted", "Your budget reached 0 money-points.")
		return true

	if GameState.environment_score <= 0:
		GameState.environment_score = 0
		show_game_over_screen("Environment depleted", "Your environment score reached 0 points.")
		return true

	return false

func show_game_over_screen(reason: String, message: String) -> void:
	current_question = {}
	is_showing_end_screen = false

	title_label.text = "Game Over"
	category_label.text = reason
	round_label.text = "Simulation failed"

	description_label.text = "%s\n\nThe organization can no longer continue with this plan." % message

	feedback_label.text = "Reset the game and try to keep both environment and budget above 0."

	title_label.add_theme_color_override("font_color", Color.RED)
	category_label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0))
	round_label.add_theme_color_override("font_color", Color(0.8, 0.0, 0.0))
	description_label.add_theme_color_override("font_color", Color(0.5, 0.0, 0.0))
	feedback_label.add_theme_color_override("font_color", Color(0.5, 0.0, 0.0))

	for button in choice_buttons:
		button.visible = false

	back_button.visible = false
	next_button.text = "Reset game"
	next_button.visible = true

	update_score_labels()
	save_current_session()

func reset_full_game() -> void:
	category_sessions.clear()
	selected_category = ""
	current_question = {}
	remaining_questions.clear()
	pending_triggered_questions.clear()
	pending_events.clear()
	shown_event_ids.clear()
	selected_choice_index = -1
	selected_choice = {}

	reset_text_styles()

	GameState.reset_game()
	update_score_labels()
	show_intro_screen()

func reset_text_styles() -> void:
	title_label.add_theme_color_override("font_color", Color.BLACK)
	category_label.add_theme_color_override("font_color", Color.BLACK)
	round_label.add_theme_color_override("font_color", Color.BLACK)
	description_label.add_theme_color_override("font_color", Color.BLACK)
	feedback_label.add_theme_color_override("font_color", Color.BLACK)
	

func _on_info_button_pressed() -> void:
	if current_question.is_empty():
		return

	var info_text := str(current_question.get("info", "")).strip_edges()

	if info_text.is_empty():
		return

	var dialog := AcceptDialog.new()
	dialog.title = "Information"
	dialog.dialog_text = "%s\n\n%s" % [
		str(current_question.get("title", "Question")),
		info_text
	]

	dialog.min_size = Vector2(700, 400)
	dialog.exclusive = true

	add_child(dialog)
	dialog.popup_centered()
	dialog.confirmed.connect(func():
		dialog.queue_free()
	)
