extends Node
class_name DialogueManager

var data : Dictionary = {}           # npc_id → Array[Dictionary]

func _ready() -> void:
	var fa := FileAccess.open(
		"res://data/dialogues.json",
		FileAccess.READ
	)
	if fa:
		var parsed : Variant = JSON.parse_string(fa.get_as_text())
		if parsed is Dictionary:
			var npc_array : Array = parsed.get("npcs", [])
			for npc_dict_var in npc_array:
				var npc_dict : Dictionary = npc_dict_var          # жёстко приводим
				data[npc_dict["id"]] = npc_dict.get("dialogues", [])

func get_line(npc_id : String) -> String:
	if not data.has(npc_id):
		return "..."

	var dialogues : Array = data[npc_id]

	for entry_var in dialogues:
		var d : Dictionary = entry_var
		var play_once : bool = d.get("play_once", false)
		var entry_id : String = d.get("id", "")

		# если нужно показывать только один раз, и уже показывали — пропускаем
		if play_once and GameState.has(entry_id):
			continue

		var cond : String = String(d.get("condition", ""))
		if cond != "":
			if not GameState.has(cond):
				# 🧠 Автоматически ставим флаг, если он называется "*_first_meeting"
				if cond.ends_with("_first_meeting"):
					GameState.set_flag(cond)
				else:
					continue  # условие не выполнено — пропускаем диалог

		# Ставим флаг, что этот диалог уже воспроизводился (если play_once)
		GameState.set_flag(entry_id)

		var lines : Array = d.get("lines", [])
		return String("\n".join(lines))

	return "..."


func get_npc_name(npc_id: String) -> String:
	var file := FileAccess.open("res://data/dialogues.json", FileAccess.READ)
	if file:
		var parsed : Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.has("npcs"):
			for npc_dict in parsed["npcs"]:
				if npc_dict.get("id", "") == npc_id:
					return npc_dict.get("name", npc_id)
	return npc_id
