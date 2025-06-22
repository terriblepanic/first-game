extends Node2D

# Один раз получаем правильный путь
@onready var player: CharacterBody2D = $Player
@onready var entrance = $Entrance
@onready var exit = $Exit


func _ready() -> void:
	exit.monitoring = false # блокируем выход
	var spawn_position = entrance.position

	player.global_position = spawn_position + Vector2(0, 100)
	player.set_physics_process(false) # Godot 4; для 3.x — set_process(false)

	var tween = get_tree().create_tween()
	tween.tween_property(player, "global_position", spawn_position, 1.0)
	tween.tween_callback(Callable(self, "_enable_transition_and_player"))


func _enable_transition_and_player() -> void:
	player.set_physics_process(true)
	exit.monitoring = true


func _on_exit_body_entered(body: Node2D) -> void:
	if body == player:
		player.set_physics_process(false)
		TransitionManager.change_scene("res://scenes/Levels/kingdom_holl.tscn")
