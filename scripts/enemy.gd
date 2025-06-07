# Enemy.gd
extends Area2D

@export var max_health := 10
@export var attack_cooldown := 2.0  # время между атаками в секундах
@export var attack_damage := 10      # урон за одну атаку

@onready var health_bar        = $HPBar/ProgressBar
@onready var health_bar_timer  = $HealthBarTimer
@onready var death_animation   : GPUParticles2D = $DeathAnimation

@onready var attack_timer      = $AttackTimer
@onready var attack_area       : Area2D       = $AttackArea
@onready var attack_animation  : GPUParticles2D = $AttackAnimation

var health := max_health

func _ready() -> void:
	# прячем область атаки до первого удара
	attack_area.monitoring = false
	# сигналы
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	# стартуем первый отсчёт
	attack_timer.wait_time = attack_cooldown
	attack_timer.start()

func take_damage(amount: int) -> void:
	$HPBar.visible = true
	health -= amount
	health = clamp(health, 0, max_health)
	health_bar.value = health

	if health == 0:
		set_process(false)
		$CollisionShape2D.disabled = true
		$Sprite2D.visible = false
		death_animation.restart()
		await get_tree().create_timer(death_animation.lifetime).timeout
		queue_free()
		return

	health_bar_timer.start()

func _on_health_bar_timer_timeout() -> void:
	$HPBar.visible = false

func _on_attack_timer_timeout() -> void:
	# проигрываем анимацию атаки и включаем зону удара
	attack_animation.restart()
	attack_area.monitoring = true

	# ждём, пока частицы (эффект атаки) отработают
	await get_tree().create_timer(attack_animation.lifetime).timeout

	# выключаем зону удара и снова запускаем отсчёт до следующей атаки
	attack_area.monitoring = false
	attack_timer.start()

func _on_attack_area_body_entered(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)
