extends Control

@onready var dia_text: Label = $DialogueBox/DiaText
@onready var next_button: Button = $DialogueBox/NextButton

var dialogue_lines: Array[String] = []
var current_line := 0

var typing_speed := 0.03
var is_typing := false
var full_text := ""

func _ready():
	next_button.pressed.connect(_on_next_pressed)

	var total_score = GameState.environment_score + GameState.economy_score

	var grade = get_grade(total_score)
	var grade_line = get_grade_text(grade)

	dialogue_lines = [
		"Welcome back.",
		"I've reviewed your performance as CIO...",
		"You had to balance environment and budget.",
		"Not an easy task.",
		"Your final score is %d." % total_score,
		"And your grade is...",
		"%s" % grade_line
	]

	show_line()


func get_grade(score: int) -> String:
	if score >= 500:
		return "A+"
	elif score >= 450:
		return "A"
	elif score >= 400:
		return "B"
	elif score >= 350:
		return "C"
	elif score >= 250:
		return "D"
	else:
		return "F"


func get_grade_text(grade: String) -> String:
	match grade:
		"A+":
			return "A+ — Outstanding. I knew hiring you was the right decision."
		"A":
			return "A — Very strong performance."
		"B":
			return "B — Solid work, but room for improvement."
		"C":
			return "C — Acceptable, but not impressive."
		"D":
			return "D — You barely made it."
		"F":
			return "F — Very disappointing..."
	return grade

func show_line():
	if current_line >= dialogue_lines.size():
		next_button.text = "Restart"
		return

	full_text = dialogue_lines[current_line]
	dia_text.text = ""
	next_button.visible = false

	is_typing = true
	type_text()


func type_text() -> void:
	for i in full_text.length():
		if not is_typing:
			break

		dia_text.text += full_text[i]
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	dia_text.text = full_text
	next_button.visible = true


func _on_next_pressed():
	if is_typing:
		is_typing = false
		dia_text.text = full_text
		next_button.visible = true
		return

	current_line += 1
	show_line()
