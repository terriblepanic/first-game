extends Node2D

@export_file("*.tscn") var next_level_path := "res://scenes/Levels/mining.tscn"
@export_file("*.tscn") var next_level_path2 := "res://scenes/Levels/kingdom_holl.tscn"
@export_file("*.tscn") var next_level_path3 := "res://scenes/Levels/guild.tscn"

@onready var hint_popup: PopupPanel = $EntranceCastleUI
@onready var player = $Player/Player

var player_inside = false

func _ready() -> void:
	hint_popup.hide()
	var spawn_point_node = $EntranceRight
	var spawn_position = spawn_point_node.position
	$RightExit.monitoring = false

	if spawn_position:
		player.position = spawn_position + Vector2(100, 0)
		player.set_process(false)
		var tween = get_tree().create_tween()
		tween.tween_property(player, "position", spawn_position, 1.0)
		tween.tween_callback(Callable(self, "_enable_transition_and_player"))

func _enable_transition_and_player():
	var player = $Player/Player
	player.set_process(true)
	$RightExit.monitoring = true

func _on_entrance_castle_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		hint_popup.popup()
		player_inside = true

func _on_entrance_castle_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		hint_popup.hide()
		player_inside = false
		
func _on_right_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.set_process(false)
		TransitionManager.change_scene(next_level_path)

func _on_left_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		body.set_process(false)
		TransitionManager.change_scene(next_level_path3)
func _process(_delta):
	if player_inside and Input.is_action_just_pressed("interact"):
		TransitionManager.change_scene(next_level_path2)
