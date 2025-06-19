extends Node

signal blessing_changed(god: String, blessing: String)

var blessings: Dictionary = {}


func set_blessing(god_name: String, blessing: String) -> void:
	blessings[god_name] = blessing
	emit_signal("blessing_changed", god_name, blessing)


func get_blessing(god_name: String) -> String:
	return blessings.get(god_name, "")


func clear() -> void:
	blessings.clear()
