extends Node
class_name Inventory

signal inventory_changed

const Item = preload("res://scripts/item.gd")
const ItemSlotScene = preload("res://scenes/item_slot.tscn")

@export var slot_count: int = 20
var items: Array[Item] = []


func add_item(item: Item) -> bool:
	# Попытка сложить в существующий стак того же предмета
	if item.stack_size > 1:
		for existing_item in items:
			if existing_item.resource_path == item.resource_path and existing_item.count < existing_item.stack_size:
				existing_item.count += 1
				emit_signal("inventory_changed")
				return true
	# Добавляем как новый слот
	if items.size() >= slot_count:
		return false
	item.count = 1
	items.append(item)
	emit_signal("inventory_changed")
	return true


func remove_item(index: int) -> void:
	if index >= 0 and index < items.size():
		items.remove_at(index)
		emit_signal("inventory_changed")


func get_free_slots() -> int:
	return max(slot_count - items.size(), 0)


func clear() -> void:
	items.clear()
	emit_signal("inventory_changed")


# inventory.gd
func populate_grid(grid: GridContainer) -> void:
	# Очистка старого
	for child in grid.get_children():
		child.queue_free()

	# ------------------------------------------------------------------
	# 1. Настроим сетку (чтобы имена не налезали) – сделать один раз.
	# ------------------------------------------------------------------
	grid.columns = 5                                   # 5×4 = 20 слотов
	grid.set("theme_override_constants/separation", 4)

	# ------------------------------------------------------------------
	# 2. Добавляем предметы
	# ------------------------------------------------------------------
	for item in items:
		var slot = ItemSlotScene.instantiate()

		# --- ОБЯЗАТЕЛЬНЫЕ размеры: ------------------------
		slot.custom_minimum_size = Vector2(80, 96)
		var icon = slot.get_node("Icon")
		icon.custom_minimum_size = Vector2(64, 64)
		# --------------------------------------------------

		var count = slot.get_node("Icon/Count")
		var name  = slot.get_node("Name")

		icon.texture = item.icon
		name.text   = item.name

		if item.count > 1:
			count.text = str(item.count)
			count.visible = true
		else:
			count.visible = false

		print("ADD:", item.name, item.icon)
		grid.add_child(slot)

	# ------------------------------------------------------------------
	# 3. Пустые слоты
	# ------------------------------------------------------------------
	for i in range(get_free_slots()):
		var filler := Control.new()
		filler.custom_minimum_size = Vector2(80, 96)
		grid.add_child(filler)
