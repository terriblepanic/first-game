extends SubViewport

@export var camera_node : Camera2D
@export var player_node : Node2D

func _ready() -> void:
	# Подключаем SubViewport к основному миру
	self.world_2d = get_tree().root.world_2d
	# Делаем камеру активной для этого вьюпорта
	camera_node.make_current()

func _process(_delta: float) -> void:
	if is_instance_valid(player_node):
		camera_node.global_position = player_node.global_position
