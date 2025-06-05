extends CharacterBody2D

@export var speed := 300.0
@export var jump_velocity := -400.0
@export var gravity := 1200.0
@export var attack_cooldown := 0.2

@onready var attack_area: Area2D = $AttackArea
@onready var attack_animation: GPUParticles2D = $AttackAnimation

var _attack_timer := 0.0
var _is_attacking := false

func _ready() -> void:
	attack_area.monitoring = false
	attack_area.area_entered.connect(_on_attack_area_entered)

func _physics_process(delta: float) -> void:
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attack_area.monitoring = false
			_is_attacking = false

	if Input.is_action_just_pressed("attack") and not _is_attacking:
		perform_attack()

	move_and_slide()

func perform_attack() -> void:
	_is_attacking = true
	attack_animation.restart()
	_attack_timer = attack_cooldown
	attack_area.monitoring = true

func _on_attack_area_entered(area: Area2D) -> void:
	if area.has_method("take_damage"):
		area.take_damage(1)
