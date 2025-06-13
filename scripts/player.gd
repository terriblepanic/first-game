extends CharacterBody2D

@export var mana_cost_attack: int = 10

signal health_changed(value: int, max_value: int)
signal mana_changed(value: int, max_value: int)
signal player_died

@export var speed: float = 300.0
@export var jump_force := 400.0
@export var gravity: float = 1200.0
@export var attack_cooldown: float = 0.2
@export var max_health: float = 100
@export var health_regen_rate: float = 1.0
@export var max_mana: float = 50
@export var mana_regen_rate: float = 5.0

var health: float = max_health
var mana: float = max_mana
var mana_regen_delay: float = 2.0
var mana_regen_timer: float = 0.0
var selected_slot: int = 0

var _is_attacking: bool = false

# Ссылка на камеру, чтобы сбрасывать сглаживание
@onready var camera: Camera2D = $Camera2D

@onready var attack_area: Area2D = $AttackArea
@onready var attack_animation: GPUParticles2D = $AttackAnimation
@onready var attack_animation_2: GPUParticles2D = $AttackAnimation2
@onready var take_damage_animation: GPUParticles2D = $TakeDamageAnimation
@onready var world_map := get_parent() # узел world_map.gd
@onready var inventory: Inventory = $"../../HUD/Inventory"
@onready var death_label: Label = $"../../HUD/DeathLabel"

@onready var jump_handler: Node = $CoyoteJump

var _attack_timer: float = 0.0


func _ready() -> void:
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	emit_signal("health_changed", int(health), max_health)
	emit_signal("mana_changed", int(mana), max_mana)


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = 0.0

	jump_handler.set_on_floor(is_on_floor())

	if jump_handler.consume_jump():
		velocity.y = -jump_force

	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attack_area.monitoring = false
			_is_attacking = false

	if Input.is_action_just_pressed("attack") and not _is_attacking:
		_use_selected_item()

	if Input.is_action_just_pressed("place_block"):
		_place_selected_block()

	mana_regen(delta)
	health_regen(delta)
	move_and_slide()


# Вызывается извне для спавна
func set_spawn_position(pos: Vector2) -> void:
	global_position = pos
	if camera:
		camera.reset_smoothing()


func perform_attack() -> void:
	_is_attacking = true
	attack_animation.restart()
	attack_animation_2.restart()
	_attack_timer = attack_cooldown
	attack_area.monitoring = true


func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	take_damage_animation.restart()
	emit_signal("health_changed", int(health), max_health)
	if health == 0:
		emit_signal("player_died")
		_die()


func respawn() -> void:
	health = max_health
	mana = max_mana
	emit_signal("health_changed", int(health), max_health)
	emit_signal("mana_changed", int(mana), max_mana)
	show()
	set_process(true)


func health_regen(delta: float) -> void:
	if health >= max_health:
		return
	var prev: int = int(health)
	health = clamp(health + health_regen_rate * delta, 0, max_health)
	if int(health) != prev:
		emit_signal("health_changed", int(health), max_health)


func use_mana(amount: int) -> void:
	mana = clamp(mana - amount, 0, max_mana)
	emit_signal("mana_changed", int(mana), max_mana)
	mana_regen_timer = mana_regen_delay


func mana_regen(delta: float) -> void:
	if mana >= max_mana:
		return
	if mana_regen_timer > 0.0:
		mana_regen_timer -= delta
	else:
		var prev: int = int(mana)
		mana = clamp(mana + mana_regen_rate * delta, 0, max_mana)
		if int(mana) != prev:
			emit_signal("mana_changed", int(mana), max_mana)


func _on_attack_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(1)


func _die() -> void:
	set_process(false)
	hide()
	if is_instance_valid(death_label):
		death_label.text = "Вы умерли!"
		death_label.visible = true
	await get_tree().create_timer(2).timeout
	if is_instance_valid(death_label):
		death_label.visible = false
	respawn()


func _get_selected_item() -> Item:
	if inventory and selected_slot >= 0 and selected_slot < inventory.items.size():
		return inventory.items[selected_slot]
	return null


func _use_selected_item() -> void:
	var item := _get_selected_item()
	if item is Pickaxe:
		var cell: Vector2i = world_map.position_to_cell(get_global_mouse_position())
		var tid: int = world_map.remove_block(cell)
		if tid != -1:
			var block_item := BlockItem.new()
			block_item.terrain_id = tid
			inventory.add_item(block_item)
	elif mana >= mana_cost_attack:
		use_mana(mana_cost_attack)
		perform_attack()


func _place_selected_block() -> void:
	var item := _get_selected_item()
	if item is BlockItem:
		var cell: Vector2i = world_map.position_to_cell(get_global_mouse_position())
		world_map.place_block(cell, item.terrain_id)
		inventory.remove_item(selected_slot)
