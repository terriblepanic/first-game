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

# Reference to the Inventory node
@onready var inventory: Inventory = get_parent().get_node("HUDLayer/Inventory")
# Reference to the world map script (parent node)
@onready var world_map := get_parent()

# Currently selected quick-slot index
var selected_slot: int = 0

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
               _use_selected_item()

       if Input.is_action_just_pressed("place_block"):
               _place_selected_block()

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

func _get_selected_item() -> Item:
       if inventory and selected_slot >= 0 and selected_slot < inventory.items.size():
               return inventory.items[selected_slot]
       return null

func _use_selected_item() -> void:
       var item = _get_selected_item()
       if item is Pickaxe:
               var cell := world_map.position_to_cell(get_global_mouse_position())
               var terrain_id := world_map.remove_block(cell)
               if terrain_id != -1:
                       var block_item := BlockItem.new()
                       block_item.terrain_id = terrain_id
                       inventory.add_item(block_item)
       else:
               perform_attack()

func _place_selected_block() -> void:
       var item = _get_selected_item()
       if item is BlockItem:
               var cell := world_map.position_to_cell(get_global_mouse_position())
               world_map.place_block(cell, item.terrain_id)
               inventory.remove_item(selected_slot)
