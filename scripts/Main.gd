extends Control

const QUESTIONS_PATH := "res://data/questions.json"

@onready var title_label: Label = $ScreenArea/VBoxContainer/TitleLabel
@onready var round_label: Label = $ScreenArea/VBoxContainer/RoundLabel
@onready var environment_score_label: Label = $ScreenArea/VBoxContainer/ScoresRow/EnvironmentScoreLabel
@onready var money_score_label: Label = $ScreenArea/VBoxContainer/ScoresRow/MoneyScoreLabel
@onready var description_label: Label = $ScreenArea/VBoxContainer/DescriptionLabel
@onready var choice_buttons: Array[Button] = [
	$ScreenArea/VBoxContainer/ChoiceButton,
	$ScreenArea/VBoxContainer/ChoiceButton2,
	$ScreenArea/VBoxContainer/ChoiceButton3,
]
@onready var feedback_label: Label = $ScreenArea/VBoxContainer/FeedbackLabel
@onready var next_button: Button = $ScreenArea/VBoxContainer/NextButton

var base_questions: Array[Dictionary] = []
var triggered_questions: Array[Dictionary] = []
var remaining_questions: Array[Dictionary] = []
var pending_triggered_questions: Array[Dictionary] = []
var current_question: Dictionary = {}


func _ready() -> void:
	randomize()
	for index in choice_buttons.size():
		choice_buttons[index].pressed.connect(_on_choice_pressed.bind(index))
	next_button.pressed.connect(_on_next_button_pressed)
	load_questions()
	start_new_game()


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
	base_questions.clear()
	triggered_questions.clear()

	var questions: Array = data.get("questions", [])
	for raw_question in questions:
		var question: Dictionary = raw_question
		if question.has("trigger"):
			triggered_questions.append(question)
		else:
			base_questions.append(question)

	var initial_scores: Dictionary = data.get("initial_scores", {})
	GameState.configure(
		int(initial_scores.get("environment", 50)),
		int(initial_scores.get("money", 50)),
		base_questions.size()
	)


func start_new_game() -> void:
	if base_questions.is_empty():
		show_loading_error("No usable questions were found.")
		return

	GameState.reset_game()
	remaining_questions = base_questions.duplicate(true)
	pending_triggered_questions = triggered_questions.duplicate(true)
	remaining_questions.shuffle()
	GameState.max_rounds = remaining_questions.size()
	current_question = {}
	feedback_label.text = ""
	next_button.visible = false
	next_button.text = "Next"
	update_score_labels()
	load_next_question()


func load_next_question() -> void:
	if remaining_questions.is_empty():
		show_end_screen()
		return

	current_question = remaining_questions.pop_front()
	display_question(current_question)
	update_score_labels()


func display_question(question: Dictionary) -> void:
	title_label.text = str(question.get("title", "Question"))
	round_label.text = "Question %d / %d" % [GameState.round_number + 1, GameState.max_rounds]
	description_label.text = str(question.get("question", ""))
	feedback_label.text = ""
	next_button.visible = false

	var choices: Array = question.get("choices", [])
	for index in choice_buttons.size():
		var button := choice_buttons[index]
		if index < choices.size():
			var choice: Dictionary = choices[index]
			button.visible = true
			button.disabled = false
			button.text = "%s. %s" % [choice.get("id", ""), choice.get("text", "")]
		else:
			button.visible = false


func _on_choice_pressed(index: int) -> void:
	if current_question.is_empty():
		return

	var choices: Array = current_question.get("choices", [])
	if index >= choices.size():
		return

	var choice: Dictionary = choices[index]
	var impact: Dictionary = choice.get("impact", {})
	var environment_change := int(impact.get("environment", 0))
	var money_change := int(impact.get("money", 0))

	GameState.apply_choice(environment_change, money_change)
	unlock_triggered_questions(current_question, choice)
	update_score_labels()

	for button in choice_buttons:
		button.disabled = true

	feedback_label.text = "Impact: environment %s%d | budget %s%d" % [
		format_signed_value(environment_change),
		abs(environment_change),
		format_signed_value(money_change),
		abs(money_change),
	]

	if remaining_questions.is_empty():
		next_button.text = "View results"
	else:
		next_button.text = "Next"
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
	environment_score_label.text = "Environment: %d" % GameState.environment_score
	money_score_label.text = "Budget: %d" % GameState.economy_score


func show_end_screen() -> void:
	current_question = {}
	title_label.text = "Game over"
	round_label.text = "Final score"
	description_label.text = "Overall balance: %d\nEnvironment: %d\nBudget: %d" % [
		GameState.get_balance_score(),
		GameState.environment_score,
		GameState.economy_score,
	]
	feedback_label.text = "The balance score rewards choices that protect both dimensions."
	for button in choice_buttons:
		button.visible = false
	next_button.text = "Play again"
	next_button.visible = true
	update_score_labels()


func show_loading_error(message: String) -> void:
	title_label.text = "Error"
	round_label.text = ""
	description_label.text = message
	feedback_label.text = "Check the file %s." % QUESTIONS_PATH
	for button in choice_buttons:
		button.visible = false
	next_button.visible = false


func _on_next_button_pressed() -> void:
	if current_question.is_empty():
		start_new_game()
		return
	load_next_question()


func format_signed_value(value: int) -> String:
	if value >= 0:
		return "+"
	return "-"
