class_name Inventory
extends Node
"""
UI-инвентарь. Отображает содержимое Singleton InventoryData и следит за стаками.
Совместим c Godot 4.4.1.
"""

#──────────────────────────────────────────────────────────────────────────────#
#  Сигналы
#──────────────────────────────────────────────────────────────────────────────#
signal inventory_changed

#──────────────────────────────────────────────────────────────────────────────#
#  Узлы и данные
#──────────────────────────────────────────────────────────────────────────────#
@onready var data := InventoryData        # глобальный массив предметов
@onready var grid_container: GridContainer = $"../HUD/InventoryPanel/InfoTabs/Снаряжение/CenterContainer/InventoryGrid"

const Item          = preload("res://scripts/item.gd")
const ItemSlotScene = preload("res://scenes/item_slot.tscn")

const SLOT_SIZE : Vector2 = Vector2(80, 96)
const ICON_SIZE : Vector2 = Vector2(64, 64)

@export var slot_count: int = 20          # визуальных ячеек

#──────────────────────────────────────────────────────────────────────────────#
#  ДОБАВЛЕНИЕ / УДАЛЕНИЕ / ОЧИСТКА
#──────────────────────────────────────────────────────────────────────────────#
func add_item(item: Item, amount: int = 1) -> bool:
	# 1) если такой предмет уже есть и stack_size == 1 (уникальный) — игнорируем
	for existing: Item in data.items:
		if existing.resource_path == item.resource_path and existing.stack_size == 1:
			return false

	# 2) доливаем в существующие стаки (stack_size > 1)
	for existing: Item in data.items:
		if existing.resource_path == item.resource_path \
		and existing.count < existing.stack_size:
			var free: int = existing.stack_size - existing.count
			var to_add: int = min(amount, free)
			existing.count += to_add
			amount -= to_add
			if amount == 0:
				_emit_update()
				return true

	# 3) создаём новые стеки, пока есть место и оставшийся amount > 0
	while amount > 0:
		if data.items.size() >= slot_count:
			_emit_update()
			return false                        # места нет

		var new_stack: Item = item.duplicate() as Item
		new_stack.resource_path = item.resource_path   # ВАЖНО: сохраняем путь!
		new_stack.count = min(amount, new_stack.stack_size)
		amount -= new_stack.count
		data.items.append(new_stack)

	_emit_update()
	return true


func remove_item(index: int) -> void:
	if index >= 0 and index < data.items.size():
		data.items.remove_at(index)
		_emit_update()


func clear() -> void:
	data.items.clear()
	_emit_update()

#──────────────────────────────────────────────────────────────────────────────#
#  ВИЗУАЛИЗАЦИЯ
#──────────────────────────────────────────────────────────────────────────────#
func refresh() -> void:
	if is_instance_valid(grid_container):
		_populate_grid(grid_container)


func _populate_grid(grid: GridContainer) -> void:
	if grid == null:
		return

	# одноразовая настройка
	if not grid.has_meta("setup"):
		grid.columns = 7
		grid.set("theme_override_constants/separation", 4)
		grid.set_meta("setup", true)

	# очищаем старые слоты
	for child in grid.get_children():
		child.queue_free()

	# рисуем новые
	for i in range(slot_count):
		var slot := ItemSlotScene.instantiate()
		slot.custom_minimum_size = SLOT_SIZE

		var icon  : TextureRect = slot.get_node("VBoxContainer/Icon")
		var name  : Label       = slot.get_node("VBoxContainer/Name")
		var count : Label       = slot.get_node("Count")

		if i < data.items.size():
			var itm: Item = data.items[i]
			icon.custom_minimum_size = ICON_SIZE
			icon.texture = itm.icon
			name.text    = itm.name
			if itm.count > 1:
				count.text    = str(itm.count)
				count.visible = true
			else:
				count.visible = false
		else:
			icon.visible  = false
			name.visible  = false
			count.visible = false

		grid.add_child(slot)

#──────────────────────────────────────────────────────────────────────────────#
#  ВНУТРЕННЕЕ
#──────────────────────────────────────────────────────────────────────────────#
func _emit_update() -> void:
	emit_signal("inventory_changed")
	refresh()
