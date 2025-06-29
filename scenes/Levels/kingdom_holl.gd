extends Node2D

@onready var player = $Player/Player
@onready var player_sprite = $Player/Player/AnimatedSprite2D
@onready var spawn_points = {
	"left": $SpawnMarkers/Left,
	"right": $SpawnMarkers/Right
}

var is_spawning = true

func _ready():
	_setup_spawn()

func _setup_spawn():
	var entry_dir = Global.last_exit_direction if "last_exit_direction" in Global else "center"
	var spawn_point = spawn_points.left
	var start_offset = Vector2(-100, 0)  # Стандартное смещение для левого появления
	var flip_h = false
	
	if entry_dir == "right": # Пришли из королевского зала
		spawn_point = spawn_points.right
		start_offset = Vector2(100, 0)  # Смещение влево для правого появления
		flip_h = true
	
	# Начальная позиция (за пределами экрана)
	player.position = spawn_point.position + start_offset
	player.set_physics_process(false)
	player_sprite.play("walking")
	player_sprite.flip_h = flip_h
	
	# Анимация движения к точке спавна
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "position", spawn_point.position, 1.0)
	tween.tween_callback(_enable_player)

func _enable_player():
	player.set_physics_process(true)
	player_sprite.stop()
	is_spawning = false

# Остальные функции без изменений
func _on_right_exit_body_entered(body: Node2D):
	if body.name == "Player" and not is_spawning:
		Global.last_exit_direction = "right"
		TransitionManager.change_scene("res://scenes/Levels/kingdom_king.tscn")

func _on_left_exit_body_entered(body: Node2D):
	if body.name == "Player" and not is_spawning:
		Global.last_exit_direction = "center"
		TransitionManager.change_scene("res://scenes/Levels/Street.tscn")
