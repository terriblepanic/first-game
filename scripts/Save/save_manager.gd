extends Node

# текущий слот сохранения (Slot1, Slot2 и т.п.)
var current_slot: String = ""

# буфер JSON-данных после чтения файла
var loaded_data: Dictionary = {}

#──────────────────────────────────#
#  УТИЛИТЫ
#──────────────────────────────────#
static func _ensure_saves_dir() -> void:
	var dir := DirAccess.open("user://")
	if dir and not dir.dir_exists("saves"):
		dir.make_dir("saves")

static func _find_player(scene: Node) -> Node2D:
	var p := scene.get_node_or_null("Player/Player")
	if p == null:
		p = scene.get_node_or_null("Player")
	if p == null:
		for n in scene.get_tree().get_nodes_in_group("player"):
			if n is Node2D:
				p = n
				break
	return p

#──────────────────────────────────#
#  СОХРАНЕНИЕ
#──────────────────────────────────#
func save_game(slot_name: String) -> void:
	current_slot = slot_name
	var scene := get_tree().current_scene
	if scene == null:
		push_warning("Нет активной сцены — сохранять нечего.")
		return

	var data: Dictionary = { "scene": scene.scene_file_path }

	# игрок
	var player := _find_player(scene)
	if player:
		data["player"] = {
			"position": [player.global_position.x, player.global_position.y],
			"health":   player.health,
			"mana":     player.mana,
			"view_mode": int(player.view_mode)
		}

	# инвентарь (глобальное хранилище)
	data["inventory_data"] = []
	for item in InventoryData.items:
		data["inventory_data"].append({
			"resource": item.resource_path,
			"count":    item.count
		})

	# квесты / навыки
	var qm := get_node_or_null("/root/QuestManager")
	data["quests"]  = qm.get_save_data() if qm and qm.has_method("get_save_data") else {}
	var sm := get_node_or_null("/root/SkillsManager")
	data["skills"]  = sm.get_save_data() if sm and sm.has_method("get_save_data") else {}

	# запись в файл
	_ensure_saves_dir()
	var path := "user://saves/%s.save" % slot_name
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))
		f.close()
		print("Сохранено:", path)
	else:
		push_error("Не удалось открыть %s" % path)

#──────────────────────────────────#
#  ЗАГРУЗКА
#──────────────────────────────────#
func load_game(slot_name: String) -> bool:
	var path := "user://saves/%s.save" % slot_name
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("Файл не найден: %s" % path)
		return false

	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Файл повреждён или пуст.")
		return false

	loaded_data = parsed
	current_slot = slot_name

	get_tree().change_scene_to_file(
		loaded_data.get("scene", "res://scenes/Levels/StartLevel.tscn")
	)
	await get_tree().process_frame
	_apply_loaded_data()
	return true

#──────────────────────────────────#
#  ПРИМЕНЕНИЕ ДАННЫХ
#──────────────────────────────────#
func _apply_loaded_data() -> void:
	if loaded_data.is_empty():
		return

	var scene := get_tree().current_scene
	if scene == null:
		return

	# игрок
	var pd: Dictionary = loaded_data.get("player", {})
	var player := _find_player(scene)
	if player and not pd.is_empty():
		player.global_position = Vector2(pd["position"][0], pd["position"][1])
		player.health = pd["health"]
		player.mana   = pd["mana"]
		player.view_mode = pd["view_mode"]

	# инвентарь (восстанавливаем глобальные данные)
	InventoryData.items.clear()
	for rec in loaded_data.get("inventory_data", []):
		var res := load(rec["resource"]) as Resource
		if res:
			var itm: Resource = res.duplicate()
			itm.count = rec["count"]
			InventoryData.items.append(itm)

	# обновляем UI-инвентарь, если он есть
	var inv_ui := scene.get_node_or_null("HUD/Inventory")
	if inv_ui and inv_ui.has_method("refresh"):
		inv_ui.refresh()

	# квесты / навыки
	var qm := get_node_or_null("/root/QuestManager")
	if qm and qm.has_method("apply_save_data"):
		qm.apply_save_data(loaded_data.get("quests", {}))
	var sm := get_node_or_null("/root/SkillsManager")
	if sm and sm.has_method("apply_save_data"):
		sm.apply_save_data(loaded_data.get("skills", {}))

	loaded_data.clear()
