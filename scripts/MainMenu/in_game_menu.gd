# pause_menu.gd
# ───────────────────────────────────────────────────────────────────────────────
# Пауза-меню во время игры.
#   • «Продолжить» – снимает паузу и скрывает меню
#   • «Сохранить»  – сохраняет игру в текущий слот SaveManager.current_slot
#   • «Выйти в меню» – (по умолчанию) сохраняет игру и переходит в Main Menu
#     (можно убрать автосохранение, если не нужно)
# ------------------------------------------------------------------------------
extends Control

# ─────────────── Ссылки на узлы UI ─────────────────────────────────────────────
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var continue_button: Button          = $MenuContainer/Button_Continue
@onready var save_button:     Button          = $MenuContainer/Button_Save
@onready var quit_button:     Button          = $MenuContainer/Button_Quit

# ─────────────── Подготовка ───────────────────────────────────────────────────
func _ready() -> void:
	process_mode                 = Node.PROCESS_MODE_ALWAYS
	animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.process_mode  = Node.PROCESS_MODE_ALWAYS
	save_button.process_mode      = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode      = Node.PROCESS_MODE_ALWAYS
	hide()

# ==============================================================================#
#                               ОТКРЫТЬ / ЗАКРЫТЬ
# ==============================================================================#
func open_menu() -> void:
	show()
	get_tree().paused = true
	animation_player.play("fade_in")

func close_menu() -> void:
	get_tree().paused = false
	hide()

# ==============================================================================#
#                               ГОРЯЧАЯ КНОПКА ESC
# ==============================================================================#
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("exit") and not get_tree().paused:
		open_menu()
	elif event.is_action_pressed("exit") and get_tree().paused:
		close_menu()

# ==============================================================================#
#                               КНОПКИ МЕНЮ
# ==============================================================================#
# Продолжить
func _on_button_continue_pressed() -> void:
	close_menu()

# Сохранить
func _on_button_save_pressed() -> void:
	var slot := SaveManager.current_slot
	if slot == "" or slot == null:
		# На случай, если игра почему-то запущена без слота – используем Slot1
		slot = "Slot1"
		SaveManager.current_slot = slot
	SaveManager.save_game(slot)
	# Можно отобразить всплывающую подсказку, что игра сохранена
	print("Игра сохранена в слот:", slot)

# Выйти в главное меню
func _on_button_quit_pressed() -> void:
	# По желанию: автосохранение перед выходом
	var slot := SaveManager.current_slot
	if slot != "" and slot != null:
		SaveManager.save_game(slot)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
