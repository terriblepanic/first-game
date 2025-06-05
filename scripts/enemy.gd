extends Area2D

@export var max_health := 3
@onready var health_bar = $HPBar/ProgressBar
@onready var health_bar_timer = $HealthBarTimer
@onready var death_animation: GPUParticles2D = $DeathAnimation

var health := max_health

func take_damage(amount: int) -> void:
	$HPBar.visible = true
	health -= amount
	health = clamp(health, 0, max_health)
	health_bar.value = health

	if health == 0:
		set_process(false)
		$CollisionShape2D.set_deferred("disabled", true)  # 🛠️ отложенное отключение
		$HPBar.visible = false
		$Sprite2D.visible = false  # 🔁 убрать спрайт врага
		death_animation.restart()

		await get_tree().create_timer(0.6).timeout  # ⏱️ зависит от lifetime у частиц
		queue_free()
		return

	health_bar_timer.start()

func _on_health_bar_timer_timeout() -> void:
	$HPBar.visible = false
