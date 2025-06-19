# inventory.gd
extends Node
class_name Inventory

signal inventory_changed

@export var slot_count: int = 20
var items: Array[Item] = []

func add_item(item: Item) -> bool:
	if items.size() >= slot_count:
		return false
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

func populate_grid(grid: GridContainer) -> void:
	for child in grid.get_children():
		child.queue_free()

	for item in items:
		if item == null or item.icon == null:
			continue
		var slot := TextureRect.new()
		slot.texture = item.icon
		slot.expand = true
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		grid.add_child(slot)

	for i in range(get_free_slots()):
		grid.add_child(TextureRect.new())
