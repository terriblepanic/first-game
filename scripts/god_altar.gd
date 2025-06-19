extends Area2D
class_name GodAltar

@export var god_name: String = "God"
@export var blessings: Array[String] = ["Blessing1", "Blessing2"]

signal blessing_selected(god: String, blessing: String)

func interact(_player: Node) -> void:
        _show_menu()

func _show_menu() -> void:
        var win := Window.new()
        win.title = "Выберите благословение"
        var vbox := VBoxContainer.new()
        win.add_child(vbox)
        for b in blessings:
                var btn := Button.new()
                btn.text = b
                btn.pressed.connect(_on_blessing_chosen.bind(b, win))
                vbox.add_child(btn)
        add_child(win)
        get_tree().paused = true
        win.popup_centered(Vector2(200, 100))

func _on_blessing_chosen(blessing: String, win: Window) -> void:
        get_tree().paused = false
        win.queue_free()
        BlessingManager.set_blessing(god_name, blessing)
        emit_signal("blessing_selected", god_name, blessing)
