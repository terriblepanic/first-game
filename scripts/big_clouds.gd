extends ParallaxLayer

@export var scroll_speed := Vector2(10, 0)

func _process(delta: float) -> void:
	motion_offset.x += delta * scroll_speed.x
