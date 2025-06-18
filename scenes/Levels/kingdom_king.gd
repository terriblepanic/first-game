extends Node2D


func _ready() -> void:
	var player = $Player
	var spawn_point_node = $Entrance
	var spawn_position = spawn_point_node.position

	$Exit.monitoring = false # отключить зону выхода

	if spawn_position:
		player.position = spawn_position + Vector2(0.0, 100.0)
		player.set_process(false)

		var tween = get_tree().create_tween()
		tween.tween_property(player, "position", spawn_position, 1.0)
		tween.tween_callback(Callable(self, "_enable_transition_and_player"))
	else:
		player.position = Vector2(100.0, 100.0)


func _enable_transition_and_player():
	var player = $Player
	player.set_process(true)
	$Exit.monitoring = true


func _on_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		var fade_rect = $FX/Fade
		fade_rect.visible = true
		fade_rect.modulate.a = 0.0
		var tween = get_tree().create_tween()
		tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
		body.set_process(false)
		tween.tween_property(body, "position:x", body.position.x + 100, 1.0)
		tween.tween_callback(Callable(self, "_load_next_scene"))


func _load_next_scene():
	get_tree().change_scene_to_file("res://scenes/Levels/kingdom_holl.tscn")
