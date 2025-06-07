extends HBoxContainer

class_name QuickSlots

@export var inventory_path: NodePath = NodePath("../../Inventory")
@export var highlight_color: Color = Color.YELLOW
@export var normal_color: Color = Color.WHITE

@onready var inventory: Inventory = get_node(inventory_path)

var selected_index: int = 0

func _ready() -> void:
        _update_highlight()

func _input(event: InputEvent) -> void:
        if event is InputEventKey and event.pressed and not event.echo:
                match event.keycode:
                        KEY_1: _select_slot(0)
                        KEY_2: _select_slot(1)
                        KEY_3: _select_slot(2)
                        KEY_4: _select_slot(3)
                        KEY_5: _select_slot(4)
                        KEY_6: _select_slot(5)
                        KEY_7: _select_slot(6)
                        KEY_8: _select_slot(7)
                        KEY_9: _select_slot(8)
                        KEY_0: _select_slot(9)

func _select_slot(index: int) -> void:
        index = clamp(index, 0, get_child_count() - 1)
        if selected_index == index:
                return
        selected_index = index
        _update_highlight()

func _update_highlight() -> void:
        for i in range(get_child_count()):
                var slot = get_child(i)
                slot.modulate = highlight_color if i == selected_index else normal_color

func get_selected_item() -> Item:
        if inventory and selected_index >= 0 and selected_index < inventory.items.size():
                return inventory.items[selected_index]
        return null
