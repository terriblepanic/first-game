extends Node2D

@export_file("*.tscn") var next_level_path := "res://scenes/Levels/Street.tscn"
@export_file("*.tscn") var next_level_path2 := "res://scenes/Levels/guild_in.tscn"

@onready var hint_popup: PopupPanel = $EntranceGuildUI
@onready var player = $Player/Player
@onready var player_sprite = $Player/Player/AnimatedSprite2D

@onready var spawn_points = {
	"left": $SpawnMarkers/Right,  # Для выхода на улицу
	"center": $SpawnMarkers/Center,  # Для входа в гильдию
	"right": $SpawnMarkers/Right  # Для других возможных выходов
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
	
	match entry_dir:
		"left":  # Пришли с улицы
			spawn_point = spawn_points.left
			flip_h = true
			offset = Vector2(100, 0)
		"center":  # Пришли изнутри гильдии
			spawn_point = spawn_points.center
			offset = Vector2(0, -20)
			flip_h = true
		"right":
			spawn_point = spawn_points.right
			flip_h = false
			offset = Vector2(100, 0)
	
	player.position = spawn_point.position + offset
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

func _on_entrance_guild_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_spawning:
		hint_popup.popup()
		player_inside = true

func _on_entrance_guild_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		hint_popup.hide()
		player_inside = false

func _on_right_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_spawning:
		Global.last_exit_direction = "right"
		TransitionManager.change_scene(next_level_path)

func _process(_delta):
	if player_inside and Input.is_action_just_pressed("interact") and not is_spawning:
		Global.last_exit_direction = "center"
		TransitionManager.change_scene(next_level_path2)
