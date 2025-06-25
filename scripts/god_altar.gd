extends Area2D
class_name GodAltar

signal blessing_selected(god: String, blessing: String)
signal player_near
signal player_far

@export var god_name: String = "God"
@export var blessings: Array[String] = ["Сила", "Защита"]
@export var blessing_descriptions: Dictionary = {
	"Сила":   "Увеличивает вашу атаку на 20%",
	"Защита": "Снижает входящий урон на 15%"
}

@onready var area: Area2D        = $DetectionArea
@onready var menu: PopupPanel    = $BlessingMenu
@onready var title_label: Label  = $BlessingMenu/VBoxContainer/HBoxContainer/Label
@onready var close_button: Button = $BlessingMenu/VBoxContainer/HBoxContainer/Button
@onready var buttons_vbox: VBoxContainer = $BlessingMenu/VBoxContainer/ButtonsVBox

var _initial_label_text: String
var _tree_was_paused: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	# Настраиваем зону детекции
	if not area.is_connected("body_entered", Callable(self, "_on_detection_area_body_entered")):
		area.connect("body_entered", Callable(self, "_on_detection_area_body_entered"))
	if not area.is_connected("body_exited", Callable(self, "_on_detection_area_body_exited")):
		area.connect("body_exited", Callable(self, "_on_detection_area_body_exited"))

	# Меню должно обрабатывать ввод во время паузы
	menu.process_mode = Node.PROCESS_MODE_ALWAYS

	# Подключаем кнопку крестика
	close_button.pressed.connect(Callable(self, "_on_menu_closed"))

	# Запомним исходный текст заголовка
	_initial_label_text = title_label.text


func interact(_player: Node) -> void:
	_show_menu()


func _show_menu() -> void:
	# Восстанавливаем заголовок
	title_label.text = _initial_label_text

	# Очищаем старые кнопки
	for btn in buttons_vbox.get_children():
		btn.queue_free()

	# Создаём кнопки для каждого благословения
	for blessing in blessings:
		var btn = Button.new()
		btn.text = blessing
		if BlessingManager.get_blessing(god_name) == blessing:
			btn.text += " (выбрано)"
			btn.disabled = true

		# Показ описания при наведении
		var desc = blessing_descriptions.get(blessing, "")
		btn.mouse_entered.connect(Callable(self, "_on_button_hovered").bind(desc))
		btn.mouse_exited.connect(Callable(self, "_on_button_unhovered"))

		# Выбор благословения
		btn.pressed.connect(Callable(self, "_on_blessing_chosen").bind(blessing))
		buttons_vbox.add_child(btn)

	# Пауза игры (остановит игрока и всё, кроме меню)
	_tree_was_paused = get_tree().paused
	get_tree().paused = true

	menu.popup_centered()
	menu.grab_focus()


func _on_menu_closed() -> void:
	menu.hide()
	get_tree().paused = _tree_was_paused


func _on_blessing_chosen(blessing: String) -> void:
	menu.hide()
	get_tree().paused = _tree_was_paused
	BlessingManager.set_blessing(god_name, blessing)
	emit_signal("blessing_selected", god_name, blessing)


func _on_button_hovered(desc: String) -> void:
	title_label.text = desc


func _on_button_unhovered() -> void:
	title_label.text = _initial_label_text


func _on_detection_area_body_entered(body: Node) -> void:
	if body.name == "Player":
		emit_signal("player_near")


func _on_detection_area_body_exited(body: Node) -> void:
	if body.name == "Player":
		emit_signal("player_far")
		
func _input(event: InputEvent) -> void:
	if menu.visible:
		if event.is_action_pressed("exit") \
		or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT \
			and not menu.get_global_rect().has_point(event.global_position)):
			_on_menu_closed()
