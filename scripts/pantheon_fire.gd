extends Node2D

@onready var _animated_sprite = $Fire

func _process(delta: float) -> void:
	_animated_sprite.play("fire")
