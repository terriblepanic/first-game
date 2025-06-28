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
# Жизнь / мана
@export var max_health        : float = 100
@export var health_regen_rate : float = 1
@export var max_mana          : float = 50
@export var mana_regen_rate   : float = 5
@export var mana_cost_magic   : int   = 10

# Движение
@export_group("Movement")
@export var max_speed              : float = 150   # ← вместо старого speed
@export var accel                  : float = 2500
@export var air_accel              : float = 1500
@export var drag                   : float = 3000
@export var air_drag               : float = 500
@export var gravity                : float = 1200
@export var gravity_up_factor      : float = 0.55
@export var gravity_down_factor    : float = 1.6
@export var jump_force             : float = 400
@export var coyote_time            : float = 0.1
@export var jump_buffer_time       : float = 0.08
@export var jump_cut_factor        : float = 0.4      # обрезка прыжка

# Dash
@export_group("Dash")
@export var dash_speed             : float = 680
@export var dash_time              : float = 0.15
@export var dash_cooldown          : float = 0.35

# Бой
@export var melee_damage           : int   = 1
@export var critical_hit_chance    : float = 0.1

@export_group("SFX • Footsteps")
@export var sfx_carpet  : Array[AudioStream] = []
@export var sfx_dirt    : Array[AudioStream] = []
@export var sfx_tile    : Array[AudioStream] = []
@export var sfx_wood    : Array[AudioStream] = []
@export var sfx_default : Array[AudioStream] = []   # если поверхность не распознана
@export var step_pixels    : float = 24.0              # «шаг» в пикселях

@export_group("Surface Query")
@export var default_surface   : String = "dirt"
@export var floor_layer       : int    = 0   # реальный пол (SIDE VIEW)
@export var virtual_floor_bit : int    = 8   # виртуальный пол (Area2D)
@onready var floor_ray : RayCast2D    = $FloorRay               # ↓ луч под ногой
@onready var top_floor : TileMapLayer = get_node_or_null("/root/CurrentScene/Floor")
# если в сцене узел пола называется иначе — поправьте путь ↑

# ───── Debug / Throttle ─────
@export var debug_log           : bool  = false    # включить/выключить вообще
@export var debug_log_interval  : float = 0.5     # сек между логами
var _debug_log_timer            : float = 0.0

var _step_bank  : Dictionary
var _step_delta : float = 0.0
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

# движение
var _jump_buffer  : float = 0.0
var _coyote_timer : float = 0.0

# dash
var _dash_timer : float = 0.0
var _dash_cd    : float = 0.0
var _is_dashing : bool  = false

# шаги
var _footstep_sets : Dictionary
var _step_accum    : float = 0.0
var stationary_t : float = 0.0

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

func _load_footstep_bank(path: String) -> Array[AudioStream]:
	var result: Array[AudioStream] = []
	var dir = DirAccess.open(path)
	if not dir:
		push_error("Cannot open dir: %s" % path)
		return result

	dir.list_dir_begin()
	var fname = dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			var ext = fname.get_extension().to_lower()
			# Только аудио форматы
			if ext in ["ogg", "wav", "mp3", "flac"]:
				# Собираем полный путь вручную
				var full_path = path + "/" + fname
				var res = ResourceLoader.load(full_path)
				if res and res is AudioStream:
					result.append(res)
				else:
					push_warning("Failed to load AudioStream: %s" % full_path)
		fname = dir.get_next()
	dir.list_dir_end()
	return result

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
	
	sfx_carpet  = _load_footstep_bank("res://assets/sounds/char/Carpet")
	sfx_dirt    = _load_footstep_bank("res://assets/sounds/char/Dirt")
	sfx_tile    = _load_footstep_bank("res://assets/sounds/char/Tiles")
	sfx_wood    = _load_footstep_bank("res://assets/sounds/char/Wood")
	sfx_default = _load_footstep_bank("res://assets/sounds/char/Floor")
	
	randomize()
	_step_bank = {
		"carpet":  sfx_carpet,
		"dirt":    sfx_dirt,
		"tile":    sfx_tile,
		"wood":    sfx_wood,
		"default": sfx_default,
	}

	# FloorRay видит слой пола и слой виртуального Area2D-пола
	floor_ray.collision_mask = (1 << floor_layer) | (1 << virtual_floor_bit)
	# после инициализации tilemap:
	if tilemap:
		_tile_size = tilemap.tile_set.tile_size
		
# ───────── ДВИЖЕНИЕ / ДЭШ ─────────
func _apply_horizontal(delta: float, dir: float) -> void:
	var target := dir * max_speed
	var a := accel if is_on_floor() else air_accel
	var d := drag if is_on_floor() else air_drag

	if abs(target) > abs(velocity.x):
		velocity.x = move_toward(velocity.x, target, a * delta)
	else:
		velocity.x = move_toward(velocity.x, target, d * delta)

func _buffer_jump(delta: float) -> void:
	_jump_buffer = max(_jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = jump_buffer_time

func _consume_buffered_jump() -> bool:
	if (_jump_buffer > 0 or jump_handler.consume_jump()):
		_jump_buffer = 0.0
		return true
	return false

func _try_dash() -> void:
	if _is_dashing or _dash_cd > 0: return
	if Input.is_action_just_pressed("dash"):
		_is_dashing = true
		_dash_timer = dash_time
		_dash_cd    = dash_cooldown

		var dir := (-1 if anim.flip_h else 1)          # ←-1 = влево, +1 = вправо
		velocity   = Vector2(dir * dash_speed, 0)
		_orient_dash_particles(dir)                # ★
		$DashParticles.restart()                   #  уже есть у вас
		if has_node("Hurtbox"): $Hurtbox.disabled = true
			
# ───────── DASH PARTICLES ─────────
func _orient_dash_particles(dir: int) -> void:
	if not has_node("DashParticles"): return
	var p := $DashParticles
	# базовый scale.x должен быть >0 (частицы «стреляют» вправо);
	# для рывка вправо надо развернуть ←
	p.scale.x = abs(p.scale.x) * (-dir)   # dir = -1 (влево) → +, dir = +1 (вправо) → –
	
# ───────── ДОБАВЬТЕ ГДЕ-НИБУДЬ В ЛЮБОМ МЕСТЕ СКРИПТА (лучше сразу после _ready) ─────────
func take_damage(amount: int) -> void:
	# отфильтруем «мусорные» вызовы
	if amount <= 0 or health <= 0:
		return

	# частицы урона, если есть
	if is_instance_valid(part_hurt):
		part_hurt.restart()

	# короткая тряска камеры при получении урона
	if has_node("PlayerCamera"):
		$PlayerCamera.add_trauma(0.4)
	else:
		var cam := get_viewport().get_camera_2d()
		if cam and cam.has_method("add_trauma"):
			cam.add_trauma(0.4)

	# уменьшаем здоровье
	var prev := int(health)
	health = clamp(health - amount, 0, max_health)

	# уведомляем HUD
	if int(health) != prev:
		emit_signal("health_changed", int(health), max_health)

	# смерть игрока
	if health == 0:
		emit_signal("player_died")
		_die()

# ───────── PHYSICS LOOP ──────────
func _physics_process(delta: float) -> void:
	match view_mode:
		ViewMode.SIDE_VIEW: _process_side_view(delta)
		ViewMode.TOP_DOWN : _process_top_down(delta)

# ───────── SIDE VIEW ─────────────
func _process_side_view(delta: float) -> void:
	# ——— таймеры / буферы
	_buffer_jump(delta)
	if _dash_cd  > 0: _dash_cd  -= delta
	if _coyote_timer > 0: _coyote_timer -= delta

	# ——— DASH режим (приоритетнее остального)
	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false
			if has_node("Hurtbox"):
				$Hurtbox.disabled = false
		
		move_and_slide()
		_handle_attack_cooldown(delta)
		_tick_timers(delta)
		_update_animation()
		return                             # обычное движение пропускаем

	# ——— Горизонталь
	var dir_h := Input.get_axis("move_left", "move_right")
	_apply_horizontal(delta, dir_h)
	if dir_h != 0:
		anim.flip_h = dir_h < 0
		_sync_hitboxes()

	# ——— Вертикаль / гравитация
	if not is_on_floor():
		velocity.y += gravity * (gravity_up_factor if velocity.y < 0 else gravity_down_factor) * delta
	else:
		_coyote_timer = coyote_time
		if _consume_buffered_jump():
			velocity.y = -jump_force

	# обрезаем прыжок при отпускании кнопки
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= jump_cut_factor

	# ——— Прочие системы
	_try_dash()
	_handle_inputs()
	_handle_attack_cooldown(delta)
	_tick_timers(delta)
	_update_animation()
	_maybe_footstep(delta)
	move_and_slide()

# ───────── TOP DOWN ──────────────
func _process_top_down(delta: float) -> void:
	var dir := Vector2(
		Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
		Input.get_action_strength("move_down")  - Input.get_action_strength("move_up"))
	velocity = dir.normalized() * max_speed if dir != Vector2.ZERO else Vector2.ZERO

	if dir.x != 0:
		anim.flip_h = dir.x < 0
		_sync_hitboxes()

	_handle_inputs()
	_handle_attack_cooldown(delta)
	_tick_timers(delta)
	_update_animation()
	_maybe_footstep(delta)
	move_and_slide()

# ───────── INPUT ─────────
func _handle_inputs() -> void:
	if _is_dashing:
		return   # во время dash кнопки игнорируем

	if Input.is_action_just_pressed("attack") and not _is_attacking and is_on_floor():
		_melee_attack()

	if Input.is_action_just_pressed("magic_attack") and not _is_attacking and is_on_floor():
		_magic_attack()

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

# ───────── FOOTSTEPS ─────────
# ───────── Определение поверхности под игроком ─────────
func _surface_under_player() -> String:
	# 1) Top-Down + TileMapLayer
	if view_mode == ViewMode.TOP_DOWN and top_floor:
		var local = top_floor.to_local(global_position)
		var cell  = top_floor.local_to_map(local)
		var td    = top_floor.get_cell_tile_data(cell)
		if td and td.has_custom_data("surface"):
			var surf = td.get_custom_data("surface")
			return surf

	var p = PhysicsPointQueryParameters2D.new()
	p.position            = global_position
	p.collision_mask      = 1 << virtual_floor_bit
	p.collide_with_areas  = true
	p.collide_with_bodies = true
	p.exclude             = [self]
	var hits = get_world_2d().direct_space_state.intersect_point(p)
	for i in range(hits.size()):
		var h = hits[i]
		var col = h.collider
		if col and col.has_meta("surface"):
			var surf = col.get_meta("surface")
			return surf
	# 3) Side-View: RayCast2D «под ногами»
	var colliding = floor_ray.is_colliding()
	if colliding:
		var col = floor_ray.get_collider()
		if col.has_meta("surface"):
			var surf = col.get_meta("surface")
			return surf

		if col is TileMapLayer:
			var tm    : TileMapLayer = col
			var lp    = tm.to_local(floor_ray.get_collision_point())
			var cell2 = tm.local_to_map(lp)
			var td2   = tm.get_cell_tile_data(cell2)
			if td2 and td2.has_custom_data("surface"):
				var surf = td2.get_custom_data("surface")
				return surf

	return default_surface


# ───────── Проигрыш звука шага ─────────
func _maybe_footstep(delta: float) -> void:
	# 1) В Side-View: если луч не видит пол — сброс и выход
	if view_mode == ViewMode.SIDE_VIEW and not floor_ray.is_colliding():
		_step_delta = 0
		return

	# 2) Вычисляем скорость: abs(velocity.x) if SIDE_VIEW, иначе длину вектора
	var speed: float = abs(velocity.x) if view_mode == ViewMode.SIDE_VIEW else velocity.length()

	# 3) Накопление дистанции, только когда скорость достаточна
	if speed >= 20.0:
		_step_delta += speed * delta

	# 4) Как только накопили step_pixels — сбрасываем и играем шаг
	if _step_delta >= step_pixels:
		_step_delta = 0

		# 5) Определяем поверхность
		var surf = _surface_under_player()
		var bank = _step_bank.get(surf, _step_bank["default"])
		if bank.size() == 0:
			return

		# 6) Берём случайный клип и проигрываем
		var clip = bank[randi() % bank.size()]
		$FootstepPlayer.stream      = clip
		$FootstepPlayer.pitch_scale = randf_range(0.95, 1.05)
		$FootstepPlayer.play()
