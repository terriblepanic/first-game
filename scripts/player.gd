# player.gd
extends CharacterBody2D

@export var speed: float = 300.0
@export var jump_velocity: float = -400.0
@export var gravity: float = 1200.0
@export var attack_cooldown: float = 0.2
@export var max_health: int = 100
@export var max_mana: float = 50
@export var mana_regen_rate: float = 5.0

signal health_changed(value: int, max_value: int)
signal mana_changed(value: int, max_value: int)
signal player_died

@onready var attack_area: Area2D = $AttackArea
@onready var attack_animation: GPUParticles2D = $AttackAnimation
@onready var attack_animation_2: GPUParticles2D = $AttackAnimation2
@onready var take_damage_animation: GPUParticles2D = $TakeDamageAnimation
@onready var world_map := get_parent()  # узел мира
@onready var inventory: Inventory = $"../HUDLayer/Inventory" # или путь к вашему Inventory
@onready var death_label: Label = $"../HUDLayer/DeathLabel"


var _attack_timer: float = 0.0
var _is_attacking: bool = false
var health: int = max_health
var mana: float = max_mana
var mana_regen_delay := 2.0
var mana_regen_timer := 0.0

# индекс текущего quick-слота
var selected_slot: int = 0

func _ready() -> void:
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	emit_signal("health_changed", health, max_health)
	emit_signal("mana_changed", int(mana), max_mana)

func _physics_process(delta: float) -> void:
	# движение и гравитация
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * speed

	if not is_on_floor():
		velocity.y += gravity * delta
	elif Input.is_action_just_pressed("jump"):
		velocity.y = jump_velocity

	# откат атаки
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			attack_area.monitoring = false
			_is_attacking = false

	# действия по вводу
	if Input.is_action_just_pressed("attack") and not _is_attacking:
		_use_selected_item()

	if Input.is_action_just_pressed("place_block"):
		_place_selected_block()
		
	mana_regen(delta)
	move_and_slide()

func perform_attack() -> void:
	_is_attacking = true
	attack_animation.restart()
	attack_animation_2.restart()
	_attack_timer = attack_cooldown
	attack_area.monitoring = true

func _on_attack_area_body_entered(body: Node) -> void:
	if body == self:
		return
	if body.has_method("take_damage"):
		body.take_damage(1)

func take_damage(amount: int) -> void:
	health = clamp(health - amount, 0, max_health)
	take_damage_animation.restart()
	emit_signal("health_changed", health, max_health)

	if health == 0:
		_die()


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


func respawn() -> void:
	# Задай координаты спавна вручную, или сделай export var spawn_position
	global_position = Vector2(100, 100)  # ← укажи нужную точку
	health = max_health
	mana = max_mana
	emit_signal("health_changed", health, max_health)
	emit_signal("mana_changed", int(mana), max_mana)
	show()
	set_process(true)    # удаляем после задержки

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
		var previous_mana := int(mana)
		mana = clamp(mana + mana_regen_rate * delta, 0, max_mana)
		if int(mana) != previous_mana:
			emit_signal("mana_changed", int(mana), max_mana)


func _get_selected_item() -> Item:
	if inventory and selected_slot >= 0 and selected_slot < inventory.items.size():
		return inventory.items[selected_slot]
	return null

func _use_selected_item() -> void:
	var item := _get_selected_item()
	if item is Pickaxe:
		var cell: Vector2i = world_map.position_to_cell(get_global_mouse_position())
		var terrain_id: int = world_map.remove_block(cell)
		if terrain_id != -1:
			var block_item := BlockItem.new()
			block_item.terrain_id = terrain_id
			inventory.add_item(block_item)
	elif mana >= 10:
		use_mana(10)
		perform_attack()
	else:
		pass

func _place_selected_block() -> void:
	var item := _get_selected_item()
	if item is BlockItem:
		var cell: Vector2i = world_map.position_to_cell(get_global_mouse_position())
		world_map.place_block(cell, item.terrain_id)
		inventory.remove_item(selected_slot)
