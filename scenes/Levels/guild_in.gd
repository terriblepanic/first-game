extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var player_sprite = $Player/AnimatedSprite2D
@onready var entrance = $SpawnMarkers/Center
@onready var exit = $SpawnMarkers/CenterExit

@onready var spawn_point = $SpawnMarkers/Center  # Добавьте маркер появления в центре сцены

var is_spawning = true

func _ready() -> void:
	exit.monitoring = false
	_setup_spawn()

func _setup_spawn():
	var entry_dir = Global.last_exit_direction if "last_exit_direction" in Global else "center"
	var offset = Vector2(0, 100)  # Появляемся сверху от точки входа
	var flip_h = false
	
	player.global_position = spawn_point.global_position + offset
	player.set_physics_process(false)
	player_sprite.play("walking")
	player_sprite.flip_h = flip_h
	
	var tween = get_tree().create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "global_position", spawn_point.global_position, 1.0)
	tween.tween_callback(_enable_transition_and_player)

func _enable_transition_and_player() -> void:
	player.set_physics_process(true)
	exit.monitoring = true
	player_sprite.stop()
	is_spawning = false

func _on_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_spawning:
		Global.last_exit_direction = "center"
		TransitionManager.change_scene("res://scenes/Levels/guild.tscn")
