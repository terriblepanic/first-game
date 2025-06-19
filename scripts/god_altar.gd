class_name GodAltar
extends Area2D

@export var blessings: Array[String] = ["Blessing1", "Blessing2"]

signal blessing_selected(god: String, blessing: String)

@export var god_name: String = "God"

# Tracks whether the game tree was already paused before showing the
# blessing selection window. Used to avoid unpausing the tree if it was
# previously paused by another system.
var _tree_was_paused := false


func interact(_player: Node) -> void:
	_show_menu()


func _show_menu() -> void:
	var win := Window.new()
	# чтобы окно работало даже на паузе
	win.process_mode = Node.PROCESS_MODE_ALWAYS
	win.title = "Выберите благословение"

	# подключаем обработчик крестика
	win.close_requested.connect(_on_menu_closed.bind(win))

	var vbox := VBoxContainer.new()
	win.add_child(vbox)

	# кнопки благословений
	for b in blessings:
		var btn := Button.new()
		btn.text = b
		btn.pressed.connect(_on_blessing_chosen.bind(b, win))
		vbox.add_child(btn)

	# единожды добавляем в сцену, ставим паузу и показываем
	add_child(win)
	_tree_was_paused = get_tree().paused
	if not _tree_was_paused:
		get_tree().paused = true
	win.popup_centered(Vector2(200, 100))


func _on_menu_closed(win: Window) -> void:
	# убираем паузу, только если мы её сами включали
	if not _tree_was_paused:
		get_tree().paused = false
	win.queue_free()


func _on_blessing_chosen(blessing: String, win: Window) -> void:
	if not _tree_was_paused:
		get_tree().paused = false
	win.queue_free()
	BlessingManager.set_blessing(god_name, blessing)
	emit_signal("blessing_selected", god_name, blessing)
