extends Node2D

@export_file("*.tscn") var to_hall := "res://scenes/Levels/kingdom_holl.tscn"

@onready var player = $Player
@onready var player_sprite = $Player/AnimatedSprite2D
@onready var center_spawn = $SpawnMarkers/Center
@onready var center_exit = $SpawnMarkers/CenterExit
@onready var camera = $Player/Camera2D

var is_spawning = true

func _ready() -> void:
	_setup_spawn()

func _setup_spawn():

	var spawn_pos = center_spawn.position
	player.position = spawn_pos + Vector2(0, 100)
	player.set_physics_process(false)
	
	if player_sprite:
		player_sprite.play("walking")
		player_sprite.flip_h = false
	
	if camera:
		camera.make_current()
		camera.reset_smoothing()
	
	center_exit.monitoring = false
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "position", spawn_pos, 1.0)
	tween.tween_callback(_enable_player)

func _enable_player():
	player.set_physics_process(true)
	
	if player_sprite:
		player_sprite.stop()
	
	center_exit.monitoring = true
	is_spawning = false
	
func _on_center_exit_body_entered(body: Node2D) -> void:
	print("Тело вошло в зону выхода: ", body.name)
	
	if body == player and not is_spawning:
		Global.last_exit_direction = "right"  # Меняем на "right" для появления справа в холле
		player.set_physics_process(false)
		TransitionManager.change_scene(to_hall)
