extends Node

var environment_score := 50
var economy_score := 50
var round_number := 0
var max_rounds := 5

func reset_game():
	environment_score = 50
	economy_score = 50
	round_number = 0

func apply_choice(environment_change: int, economy_change: int):
	environment_score = clamp(environment_score + environment_change, 0, 100)
	economy_score = clamp(economy_score + economy_change, 0, 100)
	round_number += 1

func get_balance_score() -> int:
	var average = (environment_score + economy_score) / 2
	var penalty = abs(environment_score - economy_score)
	return clamp(average - penalty, 0, 100)
