

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
var skip_typing := false
var current_full_text := ""

var button_tween: Tween

func _ready() -> void:
	next_button.pressed.connect(next_line)
	next_button.visible = false
	show_line()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if is_typing:
			skip_typing = true

func show_line() -> void:
	current_full_text = lines[index]
	dialogue_text.text = ""
	is_typing = true
	skip_typing = false

	next_button.visible = false

	if button_tween:
		button_tween.kill()

	for i in current_full_text.length():
		if skip_typing:
			dialogue_text.text = current_full_text
			break

		dialogue_text.text += current_full_text[i]
		await get_tree().create_timer(typing_speed).timeout

	is_typing = false
	show_next_button()

func show_next_button() -> void:
	next_button.visible = true
	next_button.modulate.a = 1.0
	next_button.scale = Vector2(1, 1)
	animate_next_button()

func animate_next_button() -> void:
	button_tween = create_tween()
	button_tween.set_loops()

	button_tween.tween_property(next_button, "modulate:a", 0.5, 0.6)

	button_tween.tween_property(next_button, "modulate:a", 1.0, 0.6)

func next_line() -> void:
	index += 1

	if index >= lines.size():
		get_tree().change_scene_to_file("res://scenes/main.tscn")
	else:
		show_line()
