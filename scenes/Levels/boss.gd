extends Node2D

@onready var player         : CharacterBody2D      = $Player/Player
@onready var player_sprite  : AnimatedSprite2D     = $Player/Player/AnimatedSprite2D
@onready var spawn_marker   : Node2D               = $SpawnMarkers/Left
@onready var boss           : CharacterBody2D      = $BossDemonKing
@onready var music_player   : AudioStreamPlayer2D  = $AudioStreamPlayer2D

var is_spawning     : bool = true
var _death_handled  := false

func _ready() -> void:
	_setup_spawn()
	player.connect("player_died", Callable(self, "_on_player_died"))
	boss.connect(  "boss_died",   Callable(self, "_on_boss_died"))

func _setup_spawn() -> void:
	var start_offset := Vector2(-100, 0)
	player.global_position = spawn_marker.global_position + start_offset
	player.set_physics_process(false)

	player_sprite.play("walking")
	player_sprite.flip_h = false

	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "global_position",
		spawn_marker.global_position, 1.0)
	tween.tween_callback(_enable_player)

func _enable_player() -> void:
	player.set_physics_process(true)
	player_sprite.stop()
	is_spawning = false

# —————— Обработка смерти игрока ——————
func _on_player_died() -> void:
	if _death_handled:
		return
	_death_handled = true

	# Небольшая пауза для "Game Over"
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()

# —————— Обработка смерти босса ——————
func _on_boss_died() -> void:
	if _death_handled:
		return
	_death_handled = true

	# Отключаем игрока
	player.set_process(false)
	player.set_physics_process(false)

	# Отложенный старт сцены титров
	call_deferred("_start_credits_sequence")

func _start_credits_sequence() -> void:
	# 1) Плавно затухаем музыку
	var fade_tween = create_tween()
	fade_tween.tween_property(music_player, "volume_db", -80.0, 2.0)
	fade_tween.tween_callback(music_player.stop)

	# 2) Ждём, пока музыка затухнет
	await get_tree().create_timer(2.0).timeout

	# 3) Уходим в сцену титров
	get_tree().change_scene_to_file("res://ui/credits.tscn")
