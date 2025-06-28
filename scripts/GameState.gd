# res://scripts/GameState.gd
extends Node

var flags := {
	"king_first_meeting": true,   # стартовая сцена уже сыграна
	# остальные false
}

func set_flag(flag:String, value:bool=true) -> void:
	flags[flag] = value

func has(flag:String) -> bool:
	return flags.get(flag, false)
