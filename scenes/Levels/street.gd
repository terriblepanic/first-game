extends Node2D

@export_file("*.tscn") var to_hall := "res://scenes/Levels/kingdom_holl.tscn"
@export_file("*.tscn") var to_mine := "res://scenes/Levels/mining.tscn"
@export_file("*.tscn") var to_guild := "res://scenes/Levels/guild.tscn"

@onready var hint_popup: PopupPanel = $EntranceCastleUI
@onready var player = $Player/Player
@onready var player_sprite = $Player/Player/AnimatedSprite2D
@onready var spawn_points = {
	"left": $SpawnMarkers/Left,
	"center": $SpawnMarkers/Center,
	"right": $SpawnMarkers/Right
}

var player_inside = false
var is_spawning = true

func _ready() -> void:
	hint_popup.hide()
	_setup_spawn()

func _setup_spawn():
	var entry_dir = Global.last_exit_direction if "last_exit_direction" in Global else "center"
	var spawn_point = spawn_points.center
	var offset = Vector2(100, 0)
	var flip_h = true
	
	if entry_dir == "center": # Пришли из королевского зала
		spawn_point = spawn_points.center
		offset = Vector2(0, -50)  # Смещение влево для правого появления
		flip_h = true
	
	match entry_dir:
		"left":
			spawn_point = spawn_points.right
			flip_h = true
		"right":
			spawn_point = spawn_points.left
			flip_h = false
	
	player.position = spawn_point.position + (offset * (-1 if entry_dir == "right" else 1))
	player.set_physics_process(false)
	player_sprite.play("walking")
	player_sprite.flip_h = flip_h
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "position", spawn_point.position, 1.0)
	tween.tween_callback(_enable_player)

func _enable_player() -> void:
	player.set_physics_process(true)
	player_sprite.stop()
	is_spawning = false
	_check_exit_overlap()          # <<< новая строка

func _check_exit_overlap() -> void:    # <<< новая функция
	player_inside = true
	hint_popup.popup()

func _on_entrance_castle_body_entered(body: Node2D):
	if body.name == "Player" and not is_spawning:
		hint_popup.popup()
		player_inside = true

func _on_entrance_castle_body_exited(body: Node2D):
	if body.name == "Player":
		hint_popup.hide()
		player_inside = false

func _on_left_exit_body_entered(body: Node2D):
	if body.name == "Player" and not is_spawning:
		Global.last_exit_direction = "left"
		TransitionManager.change_scene(to_guild)

func _on_right_exit_body_entered(body: Node2D):
	if body.name == "Player" and not is_spawning:
		Global.last_exit_direction = "right"
		TransitionManager.change_scene(to_mine)

func _process(_delta):
	if player_inside and Input.is_action_just_pressed("interact") and not is_spawning:
		Global.last_exit_direction = "center"
		TransitionManager.change_scene(to_hall)
