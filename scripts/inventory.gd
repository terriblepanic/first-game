extends Node
class_name Inventory

signal inventory_changed

const Item = preload("res://scripts/item.gd")
const ItemSlotScene = preload("res://scenes/item_slot.tscn")

@export var slot_count: int = 20
var items: Array[Item] = []
const SLOT_SIZE   := Vector2(80, 96)
const ICON_SIZE   := Vector2(64, 64)


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
	# ────────── (1) одноразовая настройка сетки ──────────
	if not grid.has_meta("setup"):
		grid.columns = 7
		grid.set("theme_override_constants/separation", 4)
		grid.set_meta("setup", true)

	# ────────── (2) очищаем старое содержимое ──────────
	for child in grid.get_children():
		child.queue_free()

	# ────────── (3) создаём 20 слотов ──────────
	for i in range(slot_count):
		var slot := ItemSlotScene.instantiate()
		slot.custom_minimum_size = SLOT_SIZE

		# пути к нодам внутри слота
		var icon:  TextureRect = slot.get_node("VBoxContainer/Icon")
		var name:  Label       = slot.get_node("VBoxContainer/Name")
		var count: Label       = slot.get_node("Count")

		if i < items.size():               # заполненный слот
			var item: Item = items[i]
			icon.custom_minimum_size = ICON_SIZE
			icon.texture = item.icon
			name.text    = item.name

			if item.count > 1:
				count.text    = str(item.count)
				count.visible = true
			else:
				count.visible = false
		else:                              # пустая ячейка
			icon.visible  = false
			name.visible  = false
			count.visible = false

		grid.add_child(slot)
