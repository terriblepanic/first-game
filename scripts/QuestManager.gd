extends Node
class_name QuestManager

# -------- СИГНАЛЫ --------
signal quest_added(id: String)
signal quest_state_changed(id: String, new_state: int)  # 0-LOCKED, 1-ACTIVE, 2-DONE
signal quest_completed(id: String)

# -------- СТАТУСЫ --------
enum State { LOCKED, ACTIVE, DONE }

# -------- ДАННЫЕ --------
var quests: Dictionary = {}   # id -> {title, need, reward, state}

# ============ ПУБЛИЧНЫЙ API ============

func add_quest(
		id: String,
		title: String,
		need: Dictionary,      # {res_path : int, ...}
		reward: Dictionary,    # {res_path : int, ...}
		state: int = State.ACTIVE) -> void:
	if quests.has(id):
		push_warning("Quest %s already exists" % id)
		return

	quests[id] = {
		"title":  title,
		"need":   need.duplicate(),
		"reward": reward.duplicate(),
		"state":  state
	}
	emit_signal("quest_added", id)


func set_state(id: String, new_state: int) -> void:
	if !quests.has(id):
		return
	quests[id]["state"] = new_state
	emit_signal("quest_state_changed", id, new_state)
	if new_state == State.DONE:
		emit_signal("quest_completed", id)


func has_quest(id: String) -> bool:
	return quests.has(id) and quests[id]["state"] != State.LOCKED


func progress(id: String) -> float:
	if !quests.has(id):
		return 0.0

	var quest: Dictionary = quests[id]
	var total_required: int = 0
	var total_collected: int = 0

	for res_path in quest["need"].keys():
		var required_amount: int = int(quest["need"][res_path])
		total_required += required_amount
		total_collected += min(required_amount, _inventory_count(res_path))

	return float(total_collected) / max(total_required, 1)


func ready_to_complete(id: String) -> bool:
	if !quests.has(id) or quests[id]["state"] != State.ACTIVE:
		return false

	for res_path in quests[id]["need"].keys():
		if _inventory_count(res_path) < int(quests[id]["need"][res_path]):
			return false
	return true


func complete_quest(id: String) -> bool:
	if !ready_to_complete(id):
		return false

	var quest: Dictionary = quests[id]

	# забираем нужные предметы
	for res_path in quest["need"].keys():
		_inventory_remove(res_path, int(quest["need"][res_path]))

	# выдаём награду
	for res_path in quest["reward"].keys():
		var reward_res: Resource = load(res_path)
		if reward_res:
			InventoryData.add_item(reward_res, int(quest["reward"][res_path]))

	set_state(id, State.DONE)
	return true


# ============ СЕЙВ/ЛОАД ============

func get_save_data() -> Dictionary:
	var save: Dictionary = {}
	for quest_id in quests.keys():
		save[quest_id] = quests[quest_id]["state"]
	return save


func apply_save_data(data: Dictionary) -> void:
	for quest_id in data.keys():
		if quests.has(quest_id):
			quests[quest_id]["state"] = int(data[quest_id])


# ============ ВНУТРЕННЕЕ ============

func _inventory_count(res_path: String) -> int:
	var amount_in_inventory: int = 0
	for inv_item in InventoryData.items:
		if inv_item.resource_path == res_path:
			amount_in_inventory += inv_item.count
	return amount_in_inventory


func _inventory_remove(res_path: String, amount: int) -> void:
	var remaining: int = amount   # сколько ещё нужно изъять
	for inv_item in InventoryData.items.duplicate():
		if inv_item.resource_path != res_path or remaining <= 0:
			continue

		var amount_to_take: int = int(min(inv_item.count, remaining))
		inv_item.count -= amount_to_take
		remaining -= amount_to_take

		if inv_item.count <= 0:
			InventoryData.items.erase(inv_item)

	if remaining > 0:
		push_warning("Wanted to remove %d×%s but inventory had less" % [amount, res_path])

func is_completed(id: String) -> bool:
	return has_quest(id) and quests[id]["state"] == State.DONE
