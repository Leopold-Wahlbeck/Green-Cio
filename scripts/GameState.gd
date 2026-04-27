extends Node

var initial_environment_score := 50
var initial_economy_score := 50
var environment_score := 50
var economy_score := 50
var round_number := 0
var max_rounds := 5

func configure(initial_environment: int, initial_economy: int, total_rounds: int) -> void:
	initial_environment_score = initial_environment
	initial_economy_score = initial_economy
	max_rounds = total_rounds


func reset_game() -> void:
	environment_score = initial_environment_score
	economy_score = initial_economy_score
	round_number = 0


func apply_choice(environment_change: int, economy_change: int) -> void:
	environment_score = clamp(environment_score + environment_change, 0, 100)
	economy_score = clamp(economy_score + economy_change, 0, 100)
	round_number += 1


func get_balance_score() -> int:
	var average = (environment_score + economy_score) / 2
	var penalty = abs(environment_score - economy_score)
	return clamp(average - penalty, 0, 100)
