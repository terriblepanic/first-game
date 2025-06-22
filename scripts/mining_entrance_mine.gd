extends Node2D

@export_file("*.tscn") var next_level_path := "res://scenes/Levels/cave_level.tscn"
@onready var hint_popup: PopupPanel = $EntranceMineUI
@onready var player = $Player/Player

var player_inside = false

func _ready() -> void:
	hint_popup.hide()

func _on_entrance_mine_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		hint_popup.popup()
		player_inside = true
	

func _on_entrance_mine_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		hint_popup.hide()
		player_inside = false

func _process(_delta):
	if player_inside and Input.is_action_just_pressed("interact"):
		TransitionManager.change_scene(next_level_path)


func _on_left_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		TransitionManager.change_scene("res://scenes/Levels/Street.tscn")
