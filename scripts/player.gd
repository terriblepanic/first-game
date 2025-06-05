extends CharacterBody2D

@export var speed := 300.0
@export var jump_velocity := -400.0
@export var gravity := 1200.0

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("ui_left", "ui_right")
	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("ui_up"):
		velocity.y = jump_velocity

	move_and_slide()
