# main_menu.gd
# ───────────────────────────────────────────────────────────────────────────────
# Скрипт главного меню:
#   • «Новая игра»  – запускает новую игру и создаёт/назначает слот сохранения
#   • «Продолжить»  – раскрывает список существующих слотов (*.save)
#   • «Загрузить»   – загружает выбранный слот через SaveManager
#   • «Назад»       – возвращает в корневое меню
#   • «Выход»       – завершает приложение
# ------------------------------------------------------------------------------
extends Control

# ─────────────── Ссылки на узлы UI ─────────────────────────────────────────────
@onready var start_container:    Control = $StartContainer
@onready var continue_container: Control = $ContinueContainer
@onready var save_select:        OptionButton = $ContinueContainer/OptionButton
@onready var load_button:        Button = $ContinueContainer/Button_LoadSave
@onready var anim_player:        AnimationPlayer = $AnimationPlayer

# ─────────────── Начальная инициализация ──────────────────────────────────────
func _ready() -> void:
	anim_player.play("fade_in")
	start_container.visible    = true
	continue_container.visible = false
	_refresh_save_list()

# ==============================================================================#
#                               НОВАЯ ИГРА
# ==============================================================================#
# Этот обработчик привязан к кнопке «Новая игра».
# Логика: ищем первый свободный слот (Slot1..Slot3), объявляем его текущим
# в SaveManager и переходим в начальную сцену (Pantheon/Level1 и т.п.).
func _on_button_start_pressed() -> void:
	var slot_name := _find_first_free_slot()
	SaveManager.current_slot = slot_name      # запоминаем, куда будем сохранять
	# (Опционально) сразу сохраняем «чистый» старт, если нужно:
	# SaveManager.save_game(slot_name)

	get_tree().change_scene_to_file("res://scenes/Levels/pantheon.tscn")

# ==============================================================================#
#                               ПРОДОЛЖИТЬ ИГРУ
# ==============================================================================#
# Кнопка «Продолжить» – показать/скрыть контейнер выбора сохранения
func _on_button_continue_pressed() -> void:
	start_container.visible    = !start_container.visible
	continue_container.visible = !continue_container.visible

# Кнопка «Загрузить» – загружаем выбранный слот
func _on_button_load_save_pressed() -> void:
	var slot := save_select.get_item_text(save_select.get_selected_id())
	if slot != "":
		SaveManager.load_game(slot)
	else:
		print("Слот не выбран")

# Кнопка «Назад» – возвращаемся в корневое меню
func _on_button_back_pressed() -> void:
	continue_container.visible = false
	start_container.visible    = true

# ==============================================================================#
#                               ВЫХОД ИЗ ИГРЫ
# ==============================================================================#
func _on_button_quit_pressed() -> void:
	get_tree().quit()

# ==============================================================================#
#                               ВСПОМОГАТЕЛЬНОЕ
# ==============================================================================#
# Сканируем директорию user://saves, заполняем OptionButton списком файлов .save
func _refresh_save_list() -> void:
	save_select.clear()
	var dir := DirAccess.open("user://saves")
	if dir == null:
		load_button.disabled = true
		return

	if dir.list_dir_begin() != OK:
		load_button.disabled = true
		return

	var has_saves := false
	while true:
		var file := dir.get_next()
		if file == "":
			break
		if file.ends_with(".save"):
			has_saves = true
			save_select.add_item(file.replace(".save", ""))
	dir.list_dir_end()

	# Если сохранений нет – блокируем кнопку «Продолжить»
	load_button.disabled = not has_saves

# Находит первый свободный слот из трёх (Slot1..Slot3) или "Slot1" по умолчанию
func _find_first_free_slot() -> String:
	for i in range(1, 4):
		var path := "user://saves/Slot%d.save" % i
		if not FileAccess.file_exists(path):
			return "Slot%d" % i
	# Если все три заняты – выбираем Slot1 (можно добавить подтверждение перезаписи)
	return "Slot1"
