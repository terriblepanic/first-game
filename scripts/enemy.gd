extends RigidBody2D

@export var max_health := 10
@export var attack_cooldown := 2.0
@export var attack_damage := 50

@onready var health_bar        = $HPBar/ProgressBar
@onready var health_bar_timer  = $HealthBarTimer
@onready var death_animation   : GPUParticles2D = $DeathAnimation
@onready var attack_timer      = $AttackTimer
@onready var attack_area       : Area2D = $AttackArea
@onready var attack_animation  : GPUParticles2D = $AttackAnimation

var health := max_health

func _ready() -> void:
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_timer.wait_time = attack_cooldown
	attack_timer.start()

func set_spawn_position(pos: Vector2) -> void:
	global_position = pos

func take_damage(amount: int) -> void:
	$HPBar.visible = true
	health -= amount
	health = clamp(health, 0, max_health)
	health_bar.value = health

	if health <= 0:
		set_process(false)
		$CollisionShape2D.set_deferred("disabled", true)
		$Sprite2D.visible = false
		death_animation.restart()
		await get_tree().create_timer(death_animation.lifetime).timeout
		queue_free()
		return

	health_bar_timer.start()

func _on_health_bar_timer_timeout() -> void:
	$HPBar.visible = false

func _on_attack_timer_timeout() -> void:
	attack_animation.restart()
	attack_area.monitoring = true
	await get_tree().create_timer(attack_animation.lifetime).timeout
	attack_area.monitoring = false
	attack_timer.start()

func _on_attack_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
