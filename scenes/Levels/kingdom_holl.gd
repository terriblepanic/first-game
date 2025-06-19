extends Node2D

func _ready() -> void:
var player = $Player/Player
		var camera = player.get_node("Camera2D")
		var spawn_point_node = $EntranceRight
		var spawn_position = spawn_point_node.position
		
		$RightExit.monitoring = false
		
		if spawn_position:
		# Ставим игрока на позицию заранее
		player.position = spawn_position + Vector2(100, 0)
		player.set_process(false)
		
		# Делаем камеру активной сразу, чтобы она начала следить за игроком
		camera.make_current()
		
		# Сбрасываем сглаживание, чтобы камера встала сразу на позицию игрока, без дерганий
		if camera.position_smoothing_enabled:
		camera.reset_smoothing()
		
		var tween = get_tree().create_tween()
		tween.tween_property(player, "position", spawn_position, 1.0)
		tween.tween_callback(Callable(self, "_enable_transition_and_player"))
		else:
		player.position = Vector2(100, 100)
		
	func _enable_transition_and_player():
	var player = $Player/Player
	player.set_process(true)
	$RightExit.monitoring = true
	
	func _on_right_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player":
	body.set_process(false)
	TransitionManager.change_scene("res://scenes/Levels/kingdom_king.tscn")
	
	func _load_next_scene():
	pass
