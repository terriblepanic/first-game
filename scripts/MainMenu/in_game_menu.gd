extends Control

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var continue_button: Button = $MenuContainer/Button_Continue
@onready var quit_button: Button = $MenuContainer/Button_Quit


func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	animation_player.process_mode = Node.PROCESS_MODE_ALWAYS
	continue_button.process_mode = Node.PROCESS_MODE_ALWAYS
	quit_button.process_mode = Node.PROCESS_MODE_ALWAYS

	hide()


func open_menu():
	show()
	get_tree().paused = true
	animation_player.play("fade_in")


func close_menu():
	get_tree().paused = false
	hide()


func _on_button_quit_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_button_continue_pressed() -> void:
	close_menu()
