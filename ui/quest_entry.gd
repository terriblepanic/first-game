extends Control
class_name QuestEntry

# ---------- onready ----------
@onready var icon_texture      : TextureRect = $Panel/HBoxContainer/Icon
@onready var title_label       : Label       = $Panel/HBoxContainer/VBoxContainer/Title
@onready var description_label : Label       = $Panel/HBoxContainer/VBoxContainer/Description
@onready var status_label      : Label       = $Panel/HBoxContainer/Status

var quest_id: String = ""

# ---------- PUBLIC ----------
func init_entry(id: String, quest_data: Dictionary) -> void:
	quest_id = id
	title_label.text       = String(quest_data.get("title", ""))
	description_label.text = _build_need_text(quest_data.get("need", {}))

	_update_visuals()

	# подписка на события (уже проверяем, чтобы не словить дубли)
	if !QuestMgr.quest_state_changed.is_connected(_on_quest_changed):
		QuestMgr.quest_state_changed.connect(_on_quest_changed)
	if !QuestMgr.quest_added.is_connected(_on_quest_changed):
		QuestMgr.quest_added.connect(_on_quest_changed)
	if InventoryData.has_signal("inventory_changed") \
	and !InventoryData.inventory_changed.is_connected(_on_inventory_changed):
		InventoryData.inventory_changed.connect(_on_inventory_changed)


# ---------- PRIVATE ----------
func _on_quest_changed(changed_id: String, _state := 0) -> void:
	if changed_id == quest_id:
		_update_visuals()

func _on_inventory_changed() -> void:
	_update_visuals()

func _update_visuals() -> void:
	if !QuestMgr.has_quest(quest_id):
		queue_free()
		return

	var quest_data: Dictionary = QuestMgr.quests[quest_id]     # ← тип Dictionary
	var is_done: bool   = quest_data["state"] == QuestMgr.State.DONE
	var can_turn: bool  = QuestMgr.ready_to_complete(quest_id)
	var progress: int   = int(QuestMgr.progress(quest_id) * 100.0)

	if is_done:
		icon_texture.visible = true
		status_label.text    = "Выполнено"
	elif can_turn:
		icon_texture.visible = false
		status_label.text    = "Сдать награду"
	else:
		icon_texture.visible = false
		status_label.text    = "%d%%" % progress

func _build_need_text(need: Dictionary) -> String:
	if need.is_empty():
		return ""
	var parts: Array[String] = []
	for res_path in need.keys():
		var item_name := _get_item_name(res_path)
		parts.append("%s ×%d" % [item_name, int(need[res_path])])
	return "Нужно: " + ", ".join(parts)

func _get_item_name(res_path: String) -> String:
	var res: Resource = load(res_path)
	if res and res.has_meta("item_name"):
		return String(res.get_meta("item_name"))
	if res and res.resource_name != "":
		return res.resource_name
	return res_path.get_file().get_basename().capitalize()
