extends Area2D

@export var health := 1

func take_damage(amount: int) -> void:
    health -= amount
    if health <= 0:
        queue_free()
