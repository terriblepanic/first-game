extends Control

@onready var start_options = $StartContainer
@onready var continue_options = $ContinueContainer
@onready var save_select = $ContinueContainer/OptionButton
@onready var load_button = $ContinueContainer/Button_LoadSave

func _ready():
	$AnimationPlayer.play("fade_in")
	continue_options.visible = false
	start_options.visible = true
	load_saves()

func _on_Button_Start_pressed():
	# Новая игра (например, загрузить сцену начального уровня)
	get_tree().change_scene_to_file("res://scenes/Level1.tscn")

func _on_Button_Continue_pressed():
	continue_options.visible = !continue_options.visible

#func _on_Button_LoadSave_pressed():
	#var selected_save = save_select.get_selected_id()
	#var save_name = save_select.get_item_text(selected_save)
	## Путь можно построить как угодно
	#var save_path = "user://saves/%s.save" % save_name
	## Загрузка нужного сохранения
	#load_game(save_path)

func _on_Button_Quit_pressed():
	get_tree().quit()

func load_saves():
	var dir = DirAccess.open("user://saves")
	if dir and dir.list_dir_begin():
		while true:
			var file = dir.get_next()
			if file == "":
				break
			if file.ends_with(".save"):
				save_select.add_item(file.replace(".save", ""))


func _on_button_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Levels/pantheon.tscn")


func _on_button_continue_pressed() -> void:
	start_options.visible = !start_options.visible
	continue_options.visible = !continue_options.visible


func _on_button_load_save_pressed() -> void:
	var selected_id = save_select.get_selected_id()
	var save_name = save_select.get_item_text(selected_id)
	print("Загрузка сохранения:", save_name)


func _on_button_quit_pressed() -> void:
	get_tree().quit()


func _on_button_back_pressed() -> void:
	continue_options.visible = !continue_options.visible
	start_options.visible = !start_options.visible
