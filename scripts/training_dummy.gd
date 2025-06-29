extends Node2D
class_name TrainingDummy

@export var max_health: int = 1_000_000
var health: int

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var head  : Node2D           = $Head

const NUM_SCENE := preload("res://ui/damage_number.tscn")

var _is_taking_hit := false

func _ready() -> void:
	health = max_health
	sprite.play("idle")
	# слушаем завершение любой анимации
	sprite.animation_finished.connect(_on_anim_finished)

func apply_damage(amount: int) -> void:
	if amount <= 0 or _is_taking_hit:
		return

	_is_taking_hit = true
	_show_number(amount)
	sprite.play("hit")           # «hit» должна быть НЕ зацикленной

func _on_anim_finished() -> void:
	if sprite.animation == "hit":
		sprite.play("idle")
		_is_taking_hit = false

func _show_number(amount: int) -> void:
	var n := NUM_SCENE.instantiate() as Label
	n.text = str(amount)
	get_tree().current_scene.add_child(n)
	n.global_position = head.global_position
