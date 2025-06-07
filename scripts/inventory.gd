extends Node

class_name Inventory

signal inventory_changed

@export var slot_count := 20

var items: Array = []

func add_item(item) -> bool:
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
                var slot := TextureRect.new()
                if item is Texture2D:
                        slot.texture = item
                grid.add_child(slot)
        for _i in range(get_free_slots()):
                grid.add_child(TextureRect.new())
