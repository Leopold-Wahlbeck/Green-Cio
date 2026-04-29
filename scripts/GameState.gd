extends Node

var initial_environment_score := 50
var initial_economy_score := 50
var environment_score := 50
var economy_score := 50
var round_number := 0
var max_rounds := 5
var decision_flags := {}
var answers := {}


func configure(initial_environment: int, initial_economy: int, total_rounds: int) -> void:
	initial_environment_score = initial_environment
	initial_economy_score = initial_economy
	max_rounds = total_rounds


func reset_game() -> void:
	decision_flags.clear()
	answers.clear()
	environment_score = initial_environment_score
	economy_score = initial_economy_score
	round_number = 0


func apply_choice(environment_change: int, money_change: int, question_id := -1, choice := {}):
	environment_score += environment_change
	economy_score += money_change

	# store answer
	if question_id != -1:
		answers[question_id] = choice.get("id", "")

	# store flags (from JSON)
	if choice.has("flags"):
		for key in choice["flags"].keys():
			decision_flags[key] = choice["flags"][key]
	round_number += 1

func get_balance_score() -> int:
	var average = (environment_score + economy_score) / 2
	var penalty = abs(environment_score - economy_score)
	return clamp(average - penalty, 0, 100)


func get_snapshot() -> Dictionary:
	return {
		"environment_score": environment_score,
		"economy_score": economy_score,
		"round_number": round_number,
		"max_rounds": max_rounds,
		"decision_flags": decision_flags.duplicate(true),
		"answers": answers.duplicate(true)
	}


func restore_snapshot(snapshot: Dictionary) -> void:
	environment_score = int(snapshot.get("environment_score", initial_environment_score))
	economy_score = int(snapshot.get("economy_score", initial_economy_score))
	round_number = int(snapshot.get("round_number", 0))
	max_rounds = int(snapshot.get("max_rounds", max_rounds))
	decision_flags = snapshot.get("decision_flags", {}).duplicate(true)
	answers = snapshot.get("answers", {}).duplicate(true)
