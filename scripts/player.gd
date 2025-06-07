extends CharacterBody2D

@export var speed := 300.0
@export var jump_velocity := -400.0
@export var gravity := 1200.0
@export var attack_cooldown := 0.2
@export var max_health := 100
@export var max_mana := 50

signal health_changed(value: int, max_value: int)
signal mana_changed(value: int, max_value: int)

@onready var attack_area: Area2D = $AttackArea
@onready var attack_animation: GPUParticles2D = $AttackAnimation
@onready var attack_animation_2: GPUParticles2D = $AttackAnimation2
@onready var take_damage_animation: GPUParticles2D = $TakeDamgeAnimation

var _attack_timer := 0.0
var _is_attacking := false
var health := max_health
var mana := max_mana

func _ready() -> void:
		attack_area.monitoring = false
		attack_area.area_entered.connect(_on_attack_area_entered)
		emit_signal("health_changed", health, max_health)
		emit_signal("mana_changed", mana, max_mana)

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
	attack_animation_2.restart()
	_attack_timer = attack_cooldown
	attack_area.monitoring = true

func _on_attack_area_entered(area: Area2D) -> void:
		if area.has_method("take_damage"):
				area.take_damage(1)

func take_damage(amount: int) -> void:
		health = clamp(health - amount, 0, max_health)
		take_damage_animation.restart()
		emit_signal("health_changed", health, max_health)

func use_mana(amount: int) -> void:
		mana = clamp(mana - amount, 0, max_mana)
		emit_signal("mana_changed", mana, max_mana)
