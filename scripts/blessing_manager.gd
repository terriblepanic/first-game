extends Node

var blessings: Dictionary = {}


func set_blessing(god_name: String, blessing: String) -> void:
	blessings[god_name] = blessing


func get_blessing(god_name: String) -> String:
	return blessings.get(god_name, "")


func clear() -> void:
	blessings.clear()
