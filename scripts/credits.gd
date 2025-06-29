extends Control

@export var menu_path : String = "res://scenes/main_menu.tscn"

# Путь к AnimationPlayer и к контейнеру (если надо)
@onready var anim_player : AnimationPlayer = $AnimationPlayer

func _ready() -> void:
	# Запускаем анимацию «credits»
	anim_player.play("credits")
	# Подписываемся на окончание анимации
	anim_player.connect("animation_finished", Callable(self, "_on_animation_finished"))
	# Разрешаем приём ввода для скипа
	set_process_input(true)

func _input(event: InputEvent) -> void:
	# Если нажали пробел, Enter или Esc — пропускаем
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("attack") :
		_end_credits()

func _on_animation_finished(anim_name: String) -> void:
	if anim_name == "credits":
		_end_credits()

func _end_credits() -> void:
	# Защита от двойного вызова
	if get_tree().current_scene != self:
		return
	# Переходим в главное меню
	get_tree().change_scene_to_file(menu_path)
