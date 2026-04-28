extends Control

@onready var dialogue_text: Label = $DialogueBox/DiaText
@onready var next_button: Button = $DialogueBox/NextButton

var lines := [
	"Welcome… We are soooo glad you applied for the CIO position at Company Incorporated.",
	"But don't get too excited, currently you have been only chosen for the 2 week testing period.",
	"Each day, your job is to make a series of choices for our company.",
	"At the end of the 2 week period, we will evaluate your performance and decide whether to keep you or not.",
	"We expect you to make us a lot of money…",
	"While of course…",
	"Thinking about the environment.",
	"Think about your choices wisely.",
	"Good luck :D"
]

var index := 0
var typing_speed := 0.03
var is_typing := false
var current_full_text := ""

func _ready() -> void:
	next_button.pressed.connect(next_line)
	show_line()

func show_line() -> void:
	current_full_text = lines[index]
	dialogue_text.text = ""
	is_typing = true

	next_button.visible = false  # 🔥 göm knappen

	for i in current_full_text.length():
		dialogue_text.text += current_full_text[i]
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	next_button.visible = true   # 🔥 visa när klar

func next_line() -> void:
	index += 1

	if index >= lines.size():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		show_line()
