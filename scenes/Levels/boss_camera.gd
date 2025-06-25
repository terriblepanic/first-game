extends Camera2D
@export var trauma_decay   : float = 5.0
@export var max_offset     : float = 4.0
@export var max_rotation   : float = 0.05
var trauma : float = 0.0

func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(delta: float) -> void:
	if trauma == 0.0:
		offset   = Vector2.ZERO
		rotation = 0.0
		return
	trauma      = max(trauma - trauma_decay * delta, 0.0)
	var shake   = trauma * trauma           # квадратичная затухающая кривая
	offset.x    = randf_range(-1, 1) * max_offset   * shake
	offset.y    = randf_range(-1, 1) * max_offset   * shake
	rotation    = randf_range(-1, 1) * max_rotation * shake
