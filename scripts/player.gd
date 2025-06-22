extends CharacterBody2D
# ──────────── Сигналы ────────────
signal health_changed(value: int, max_value: int)
signal mana_changed  (value: int, max_value: int)
signal player_died

# ──────────── Камера ─────────────
enum ViewMode { SIDE_VIEW, TOP_DOWN }
@export var view_mode: ViewMode = ViewMode.SIDE_VIEW

# ───── Константы времён ──────────
const MELEE_ANIM_TIME : float = 0.5
const MAGIC_ANIM_TIME : float = 1.0
const LANDING_TIME    : float = 0.3
const JUMP_PREP_TIME  : float = 0.2
const APEX_TIME       : float = 0.3
const MELEE_HIT_DELAY : float = 0.4
const MAGIC_HIT_DELAY : float = 0.4
const MINING_TIME     : float = 1.2

# ───── Экспортируемые параметры ──
@export var max_health        : float = 100
@export var health_regen_rate : float = 1
@export var max_mana          : float = 50
@export var mana_regen_rate   : float = 5
@export var mana_cost_magic   : int   = 10
@export var gravity           : float = 1200
@export var gravity_up_factor : float = 0.6
@export var gravity_down_factor : float = 1.0
@export var speed             : float = 300
@export var jump_force        : float = 400
@export var melee_damage      : int   = 1
@export var critical_hit_chance : float = 0.1

# ───── Внутренние переменные ─────
var health: float
var mana  : float
var _is_attacking : bool  = false
var _attack_timer : float = 0.0
var _was_on_floor : bool  = true
var _jump_prep_timer : float = 0.0
var _apex_timer      : float = 0.0
var _landing_timer   : float = 0.0
var _mana_regen_delay: float = 2
var _mana_regen_timer: float = 0.0
var _melee_is_critical : bool = false
var _melee_offset_x: float
var _magic_offset_x: float

# ───── Добыча ─────
var _is_mining        : bool     = false
var _mining_timer     : float    = 0.0
var _mining_cell      : Vector2i = Vector2i.ZERO

# ───────────── ДОПОЛНИТЕЛЬНЫЕ ПЕРЕМЕННЫЕ ─────────────
# хранит оверлеи: cell → Polygon2D
var _mining_overlays: Dictionary = {}
# размер тайла
var _tile_size: Vector2 = Vector2.ZERO

# ──────── Ноды ────────
@onready var anim            : AnimatedSprite2D = $AnimatedSprite2D
@onready var melee_area      : Area2D           = $MeleeAttackArea
@onready var magic_area      : Area2D           = $MagicAttackArea
@onready var part_attack_1   : GPUParticles2D   = $AttackAnimation
@onready var part_attack_2   : GPUParticles2D   = $AttackAnimation2
@onready var part_hurt       : GPUParticles2D   = $TakeDamageAnimation
@onready var jump_handler                    = $CoyoteJump
@onready var interact_area   : Area2D           = $InteractArea
@onready var mining_area     : Area2D           = $MiningArea
@onready var hud = get_tree().current_scene.get_node("HUD")
@onready var inventory = hud.get_node("Inventory")
@onready var death_label = hud.get_node("DeathLabel")
@onready var world_map                        = get_parent().get_parent()
@onready var tilemap: TileMapLayer = (world_map.get_node_or_null("WorldMap") as TileMapLayer)
@onready var inv_data := InventoryData

# ───────────── READY ─────────────
func _ready() -> void:
	add_to_group("player")
	health = max_health
	mana   = max_mana
	_emit_stats()

	melee_area.monitoring = false
	magic_area.monitoring = false
	melee_area.body_entered.connect(_on_melee_body_entered)
	magic_area.body_entered.connect(_on_magic_body_entered)

	_melee_offset_x = melee_area.position.x
	_magic_offset_x = magic_area.position.x
	_sync_hitboxes()
	_was_on_floor = is_on_floor()

	# после инициализации tilemap:
	if tilemap:
		_tile_size = tilemap.tile_set.tile_size

# ───────── PHYSICS LOOP ──────────
func _physics_process(delta: float) -> void:
	match view_mode:
		ViewMode.SIDE_VIEW: _process_side_view(delta)
		ViewMode.TOP_DOWN : _process_top_down(delta)

# ───────── SIDE VIEW ─────────────
func _process_side_view(delta: float) -> void:
	if _is_attacking and is_on_floor():
		velocity.x = 0
	else:
		var dir_h := Input.get_axis("move_left", "move_right")
		velocity.x = dir_h * speed
		if dir_h != 0:
			anim.flip_h = dir_h < 0
			_sync_hitboxes()

	if not is_on_floor():
		velocity.y += gravity * (gravity_up_factor if velocity.y < 0 else gravity_down_factor) * delta
	elif Input.is_action_just_pressed("jump"):
		anim.play("jump_preparation")
		_jump_prep_timer = JUMP_PREP_TIME

	jump_handler.set_on_floor(is_on_floor())
	if jump_handler.consume_jump():
		velocity.y = -jump_force

	_handle_inputs()
	_handle_attack_cooldown(delta)
	_tick_timers(delta)
	_update_animation()
	move_and_slide()

# ───────── TOP DOWN ──────────────
func _process_top_down(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up"))
	velocity = dir.normalized() * speed if dir != Vector2.ZERO else Vector2.ZERO

	if dir.x != 0:
		anim.flip_h = dir.x < 0
		_sync_hitboxes()

	_handle_inputs()
	_handle_attack_cooldown(delta)
	_tick_timers(delta)
	_update_animation()
	move_and_slide()

# ───────── INPUT ─────────
func _handle_inputs() -> void:
	# ближняя атака только если на земле и не в другом действии
	if Input.is_action_just_pressed("attack") and not _is_attacking and is_on_floor():
		_melee_attack()
	# магическая атака только если на земле и не в другом действии
	if Input.is_action_just_pressed("magic_attack") and not _is_attacking and is_on_floor():
		_magic_attack()

	# добыча
	if Input.is_action_just_pressed("mine"):
		_start_mining()
	elif Input.is_action_just_released("mine"):
		_cancel_mining()

	if Input.is_action_just_pressed("interact"):
		_on_interact()

# ─────────── ОБНОВЛЕНИЕ ТАЙМЕРОВ ───────────
func _tick_timers(delta: float) -> void:
	if _jump_prep_timer > 0: _jump_prep_timer -= delta
	if _apex_timer      > 0: _apex_timer      -= delta
	if _landing_timer   > 0: _landing_timer   -= delta

	# Добыча через оверлей
	if _is_mining:
		_mining_timer -= delta
		var prog := 1.0 - _mining_timer / MINING_TIME
		var overlay: Polygon2D = _mining_overlays.get(_mining_cell)
		if overlay:
			overlay.color.a = clamp(prog * 0.8, 0.0, 0.8)
		if _mining_timer <= 0.0:
			_break_block()
			_remove_mining_overlay()

	health_regen(delta)
	mana_regen(delta)

# ───────── COOLDOWN ─────────
func _handle_attack_cooldown(delta: float) -> void:
	if _attack_timer > 0:
		_attack_timer -= delta
		if _attack_timer <= 0:
			melee_area.monitoring = false
			magic_area.monitoring = false
			_is_attacking = false

# ───────── АНИМАЦИИ ─────────
func _update_animation() -> void:
	if _is_attacking or _jump_prep_timer > 0 or _landing_timer > 0:
		return

	if view_mode == ViewMode.TOP_DOWN:
		anim.play("walking" if velocity.length() > 10 else "idle")
		return

	if not is_on_floor() and abs(velocity.y) < 20 and _apex_timer <= 0:
		anim.play("jumping_reload")
		_apex_timer = APEX_TIME
		return
	if _apex_timer > 0: return

	if not is_on_floor():
		anim.play("flying_up" if velocity.y < 0 else "falling")
	else:
		if not _was_on_floor:
			anim.play("landing")
			_landing_timer = LANDING_TIME
		elif abs(velocity.x) > 0.1:
			anim.play("running")
		else:
			anim.play("idle")
	_was_on_floor = is_on_floor()

# ───────── АТАКИ ─────────
func _melee_attack() -> void:
	_is_attacking = true
	_melee_is_critical = randf() < critical_hit_chance
	anim.play("critical_attack" if _melee_is_critical else "attack")
	_attack_timer = MELEE_ANIM_TIME
	get_tree().create_timer(MELEE_HIT_DELAY).timeout.connect(func():
		melee_area.monitoring = true)

func _magic_attack() -> void:
	if mana < mana_cost_magic: return
	use_mana(mana_cost_magic)
	_is_attacking = true
	anim.play("spell_cast")
	_attack_timer = MAGIC_ANIM_TIME
	get_tree().create_timer(MAGIC_HIT_DELAY).timeout.connect(func():
		magic_area.monitoring = true
		part_attack_1.restart()
		part_attack_2.restart())

func _on_melee_body_entered(body: Node) -> void:
	if body != self and body.has_method("take_damage"):
		var dmg: int = melee_damage * (2 if _melee_is_critical else 1)
		body.take_damage(dmg)

func _on_magic_body_entered(body: Node) -> void:
	if body != self and body.has_method("take_damage"):
		body.take_damage(1)

# ───── НАЧАЛО ДОБЫЧИ ────────────
func _start_mining() -> void:
	if tilemap == null or _is_mining or _is_attacking:
		return

	var shape: CircleShape2D = mining_area.get_node("CollisionShape2D").shape as CircleShape2D
	var local_mouse: Vector2 = mining_area.to_local(get_global_mouse_position())
	if local_mouse.length() > shape.radius:
		return

	var cell: Vector2i = world_map.position_to_cell(get_global_mouse_position())
	if tilemap.get_cell_source_id(cell) == -1:
		return

	_is_mining    = true
	_mining_timer = MINING_TIME
	_mining_cell  = cell

	# создаём оверлей
	var overlay := Polygon2D.new()
	overlay.polygon = [
		Vector2i(-7, -7),
		Vector2i(7, -7),
		Vector2i(7, 7),
		Vector2i(-7, 7),
	]
	overlay.color = Color(0, 0, 0, 0)
	overlay.position = tilemap.map_to_local(cell)
	world_map.add_child(overlay)
	_mining_overlays[cell] = overlay

# ─────────── ОТМЕНА ДОБЫЧИ ───────────
func _cancel_mining() -> void:
	if not _is_mining:
		return
	_is_mining = false
	_remove_mining_overlay()

# ─────────── ВЗЛОМ БЛОКА ───────────
func _break_block() -> void:
	_remove_mining_overlay()

	var tid: int = world_map.remove_block(_mining_cell)
	if tid == -1:
		return

	var drop: Resource = null
	match tid:
		TerrainData.TerrainID.ORE_COPPER: drop = load("res://items/copper_ore.tres")
		TerrainData.TerrainID.ORE_IRON:   drop = load("res://items/iron_ore.tres")
		TerrainData.TerrainID.ORE_GOLD:   drop = load("res://items/gold_ore.tres")
		TerrainData.TerrainID.SAND:       drop = load("res://items/sand.tres")
		TerrainData.TerrainID.DIRT:       drop = load("res://items/dirt.tres")
		TerrainData.TerrainID.STONE:      drop = load("res://items/stone.tres")

	if drop:
		inv_data.add_item(drop)           # ← добавляем в глобальное хранилище
		if is_instance_valid(inventory):  #   и сразу обновляем визуальный HUD
			inventory.refresh()


# ─────────── УДАЛЕНИЕ ОВЕРЛЕЯ ───────────
func _remove_mining_overlay() -> void:
	var overlay: Polygon2D = _mining_overlays.get(_mining_cell)
	if overlay and overlay.is_inside_tree():
		overlay.queue_free()
	_mining_overlays.erase(_mining_cell)

# ───── REGEN & СМЕРТЬ ─────
func health_regen(delta: float) -> void:
	if health < max_health:
		var prev := int(health)
		health = clamp(health + health_regen_rate * delta, 0, max_health)
		if int(health) != prev:
			emit_signal("health_changed", int(health), max_health)

func mana_regen(delta: float) -> void:
	if mana < max_mana:
		if _mana_regen_timer > 0:
			_mana_regen_timer -= delta
		else:
			var prev := int(mana)
			mana = clamp(mana + mana_regen_rate * delta, 0, max_mana)
			if int(mana) != prev:
				emit_signal("mana_changed", int(mana), max_mana)

func use_mana(amount: int) -> void:
	mana = clamp(mana - amount, 0, max_mana)
	emit_signal("mana_changed", int(mana), max_mana)
	_mana_regen_timer = _mana_regen_delay

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
	health = max_health
	mana   = max_mana
	_emit_stats()
	show()
	set_process(true)

# ───── INTERACT ─────
func _on_interact() -> void:
	for area in interact_area.get_overlapping_areas():
		if area.has_method("interact"):
			area.interact(self)

# ───── ХЕЛПЕРЫ ─────
func _sync_hitboxes() -> void:
	var s := -1 if anim.flip_h else 1
	melee_area.position.x = _melee_offset_x * s
	magic_area.position.x = _magic_offset_x * s

func _emit_stats() -> void:
	emit_signal("health_changed", int(health), max_health)
	emit_signal("mana_changed",   int(mana),   max_mana)
