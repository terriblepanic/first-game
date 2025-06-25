extends CharacterBody2D
###############################################################################
# BossDemonKing.gd  v4.5 — сверх-подробный DEBUG-лог                          #
###############################################################################

# ── LOGGING ────────────────────────────────────────────────────────────────
const DEBUG_LOG     := true    # основной лог
const DEBUG_VERBOSE := true    # мелкие детали (можно выключить)

func _log(msg:String, verbose:bool=false) -> void:
	if DEBUG_LOG and (not verbose or DEBUG_VERBOSE):
		print("[%6.2f] Boss | %s" % [Time.get_ticks_msec() / 1000.0, msg])

# ╔══════════════  EXPORTED  ══════════════╗
@export_group("⛑  Core")
@export var max_health       : int   = 1200
@export var phase2_threshold : float = 0.5
@export var ground_y         : float = 440.0
@export var arena_bounds     : Rect2 = Rect2(Vector2.ZERO, Vector2(700, 500))
@export var attack_gap       : float = 1.0     # пауза между атаками

@export_group("✧ Splash")
@export var teleport_distance_near : float = 128.0
@export var splash_damage          : int   = 30
@export var splash_active_time     : float = 0.4

@export_group("✧ SkyBeams")
@export var beams_phase1 : int   = 8
@export var beams_phase2 : int   = 16
@export var beam_radius  : float = 220.0
@export var lift_height  : float = 200.0

@export_group("✧ Dash")
@export var dash_speed : float = 600.0
@export var dash_time  : float = 0.6

@export_group("✧ Teleport Sky + Orbs")
@export var teleport_height_far : float = 200.0

@export_group("⚔  Enable Attacks")
@export var enable_splash        := true
@export var enable_step_orbs     := true
@export var enable_beams_p1      := true
@export var enable_dash_ball     := true
@export var enable_teleport_orbs := true
@export var enable_beams_p2      := true
# ╚════════════════════════════════════════╝

# ── CHILD NODES ────────────────────────────────────────────────────────────
@onready var sprite       : AnimatedSprite2D   = $AnimatedSprite2D
@onready var splash_fx    : GPUParticles2D     = $MagicSplashParticles
@onready var dash_fx      : GPUParticles2D     = $DashTrailParticles
@onready var summon_fx    : GPUParticles2D     = $SummonCastParticles
@onready var attack_tmr   : Timer              = $attack_timer
@onready var proj_root    : Node               = $projectiles_root
@onready var splash_area  : Area2D             = $MagicSplashArea
@onready var splash_sfx   : AudioStreamPlayer2D = $sfxSplash

# ── STATE ──────────────────────────────────────────────────────────────────
enum State { IDLE, ATTACK, DASH }
var state      : State = State.IDLE
var health     : int
var rng        := RandomNumberGenerator.new()
var player     : CharacterBody2D
var _bag : Array[Callable] = []

# ── HELPERS ────────────────────────────────────────────────────────────────
func _state_to_str(s:int) -> String:
	return ["IDLE", "ATTACK", "DASH"][s]

func _player() -> CharacterBody2D:
	if player and player.is_inside_tree():
		return player
	player = get_tree().get_first_node_in_group("player")
	_log("find player → %s" % player)
	return player

func _go_ground() -> void:
	if abs(global_position.y - ground_y) > 1.0:
		_log("return to ground  Y=%.1f→%.1f" % [global_position.y, ground_y])
	global_position.y = ground_y
	_log("Босс перемещён на землю в точку %s" % global_position, true)

func _fill_bag(phase:int) -> void:
	_bag.clear()
	_log("Заполняю мешок атак для фазы %d" % phase, true)
	if phase == 1:
		if enable_splash:        _bag.append(attack_splash)
		if enable_step_orbs:     _bag.append(attack_step_orbs)
		if enable_beams_p1:      _bag.append(attack_beams_p1)
	else:
		if enable_dash_ball:     _bag.append(attack_dash)
		if enable_teleport_orbs: _bag.append(attack_teleport_orbs)
		if enable_beams_p2:      _bag.append(attack_beams_p2)
	_log("bag filled phase=%d size=%d content=%s"
		% [phase, _bag.size(), _bag.map(func(c): return c.get_method())])

func _update_facing() -> void:
	var p := _player()
	if p == null:           # игрока нет — ничего не делаем
		return
	sprite.flip_h = p.global_position.x < global_position.x

# ── READY ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_log("───────────────────────────")
	_log("Скрипт загружен")
	_log("Инициализация RNG")
	rng.randomize()
	_log("RNG установлен: seed=randomized")
	health = max_health
	_log("Установка HP: %d/%d" % [health, max_health])
	_go_ground()
	sprite.play("1_form")
	_log("Init  HP=%d  pos=%s  bounds=%s" % [health, global_position, arena_bounds])
	
	splash_area.monitoring = false
	
	attack_tmr.one_shot = true
	attack_tmr.timeout.connect(_choose_attack)
	attack_tmr.start(attack_gap)
	_log("Таймер атаки запущен (%.2f сек)" % attack_gap, true)

# ── PHYSICS ────────────────────────────────────────────────────────────────
func _physics_process(delta:float) -> void:
	if state == State.DASH:
		move_and_slide()
		_log("DASH move pos=%s vel=%s" % [global_position, velocity], true)

	# ограничение X-координаты
	var old_x := global_position.x
	global_position.x = clamp(
		global_position.x,
		arena_bounds.position.x + 32,
		arena_bounds.end.x       - 32)
	_update_facing()
	if old_x != global_position.x:
		_log("clamp X  %.1f→%.1f" % [old_x, global_position.x], true)

# ── AI ─────────────────────────────────────────────────────────────────────
func _choose_attack() -> void:
	_log("Таймер атаки истёк")
	if state != State.IDLE:
		_log("Выбор атаки пропущен, текущее состояние=%s" % _state_to_str(state))
		attack_tmr.start(attack_gap)
		return

	var phase := 1 if health > max_health * phase2_threshold else 2
	_log("Текущее HP: %d, порог фазы 2: %.1f, выбрана фаза: %d"
		% [health, max_health * phase2_threshold, phase])

	if _bag.is_empty():
		_log("Мешок атак пуст, начинаю заполнение")
		_fill_bag(phase)
	else:
		_log("Мешок атак содержит %d: %s" %
			[_bag.size(), _bag.map(func(c): return c.get_method())], true)

	if _bag.is_empty():
		_log("Все атаки выключены — задержка")
		attack_tmr.start(attack_gap)
		return

	var atk : Callable = _bag[rng.randi() % _bag.size()]
	_log("Случайно выбрана атака: %s" % atk.get_method())
	_bag.erase(atk)

	state = State.ATTACK
	_log("ATTACK → %s  HP=%d  bag=%d" %
		[atk.get_method(), health, _bag.size()])
	atk.call()

func _finish(delay:float, land:bool = true) -> void:
	# ждём указанную задержку, не создавая лишний Timer-узел
	await get_tree().create_timer(delay).timeout

	if land:
		_go_ground()

	_log("STATE → IDLE (было %s)" % _state_to_str(state))
	state = State.IDLE
	attack_tmr.start(attack_gap)
	_log("Таймер следующей атаки запущен (%.2f сек)" % attack_gap)

# ── ATTACKS ────────────────────────────────────────────────────────────────
# 1  Splash ────────────────────────────────────────────────────────────────
func attack_splash() -> void:
	var p := _player()
	if p == null:
		_log("Атака Splash отменена: игрок не найден!")
		_finish(0.1)
		return

	# всегда на земле
	_go_ground()

	# вычисляем только горизонтальное смещение
	var angle    := rng.randf_range(0, TAU)
	var offset   := Vector2(teleport_distance_near, 0).rotated(angle)
	var target_x : int = clamp(
		p.global_position.x + offset.x,
		arena_bounds.position.x + 32,
		arena_bounds.end.x       - 32
	)

	# не телепортироваться слишком близко
	if abs(target_x - global_position.x) < 32:
		target_x = clamp(
			target_x + sign(offset.x) * 64,
			arena_bounds.position.x + 32,
			arena_bounds.end.x       - 32
		)

	splash_sfx.play()
	global_position = Vector2(target_x, ground_y)
	_log("Splash TP на землю → %s" % global_position)

	# ориентация и эффекты
	var face_left := p.global_position.x < global_position.x
	sprite.flip_h = face_left
	var rot = 0.0
	if face_left == true:
		rot = 180.0
	else:
		rot = 0.0
	splash_fx.rotation_degrees  = rot
	splash_area.rotation_degrees = rot

	splash_fx.restart()
	splash_area.global_position = global_position
	splash_area.monitoring      = true
	_log("Splash hitbox ON (pos=%s)" % global_position)

	# сразу же логируем, кто уже внутри зоны
	var bodies = splash_area.get_overlapping_bodies()
	_log("Overlapping bodies count: %d" % bodies.size())
	for body in bodies:
		_log("  → overlapping: %s, groups: %s" % [body, body.get_groups()])
		if body.is_in_group("player") and body.has_method("take_damage"):
			_log("  → overlapping player, наносим %d урона" % splash_damage)
			body.take_damage(splash_damage)
		else:
			_log("  → тело не подходит: groups=%s, has take_damage? %s"
				% [body.get_groups(), body.has_method("take_damage")])

	await get_tree().create_timer(splash_active_time).timeout
	splash_area.monitoring = false
	_log("Splash hitbox OFF")

	# возвращаемся в IDLE, но без доп. посадки (мы уже на земле)
	_finish(1.0, false)
	
# 2  Step + Orbs ------------------------------------------------------------
func attack_step_orbs() -> void:
	var p := _player()
	if p == null:
		_finish(0.1)
		return

	# 1. выбираем направление к игроку
	var dir : int = sign(p.global_position.x - global_position.x)
	if dir == 0: dir = 1  # если точно под нами – шагаем вправо

	var old_x := global_position.x

	# 2. считаем кандидат-позицию
	var candidate := global_position.x + dir * 64
	candidate = clamp(candidate,
		arena_bounds.position.x + 32,
		arena_bounds.end.x       - 32)

	# 3. если не смогли сдвинуться (упёрлись в стену) – идём в обратную сторону
	if candidate == old_x:
		dir *= -1
		candidate = clamp(old_x - dir * 64,
			arena_bounds.position.x + 32,
			arena_bounds.end.x       - 32)

	global_position.x = candidate
	_log("StepOrbs dir=%d  X %.1f→%.1f" % [dir, old_x, global_position.x])

	summon_fx.restart()

	# 4. спавним 3 орба с интервалами 0.5 с
	for i in 3:
		_spawn_orb()
		if i < 2:                        # пауза только перед 2-м и 3-м
			await get_tree().create_timer(0.5).timeout

	_finish(1.2)

# 3 / 6  SkyBeams -----------------------------------------------------------
func attack_beams_p1() -> void: _spawn_beams(beams_phase1)
func attack_beams_p2() -> void: _spawn_beams(beams_phase2)

func _spawn_beams(cnt:int) -> void:
	var p := _player()
	if p == null:
		_finish(0.1)
		return

	# поднимаемся в воздух
	global_position.y = ground_y - lift_height
	_log("Beams spawn cnt=%d  lift Y=%.1f" % [cnt, global_position.y])

	var max_time := 0.0          # самая “долгая” полоса

	for i in cnt:
		var beam := preload("res://scenes/SkyBeam.tscn").instantiate()

		# считаем длительность эффекта этого конкретного луча
		var beam_life : float = beam.marker_delay + beam.warn_time + beam.active_time
		max_time = max(max_time, beam_life)

		# выбираем X в радиусе вокруг игрока
		var x : int = clamp(
			p.global_position.x + rng.randf_range(-beam_radius, beam_radius),
			arena_bounds.position.x + 16,
			arena_bounds.end.x       - 16)

		beam.global_position = Vector2(x, arena_bounds.position.y - 100)
		beam.ground_y        = ground_y
		proj_root.add_child(beam)
		_log("  beam[%d] X=%.1f" % [i, x], true)

	_log("Beams done  longest=%.2f s" % max_time)

	# ждём: время самого длинного луча + маленький буфер
	_finish(max_time + 0.2)
	
# 4  Dash ───────────────────────────────────────────────────────────────────
func attack_dash() -> void:
	_go_ground()                                     # стартуем с земли

	var p := _player()
	if p == null:
		_finish(0.1)
		return

	# только горизонтальный рывок
	var dir : int = sign(p.global_position.x - global_position.x)
	velocity = Vector2(dir, 0) * dash_speed
	_log("Dash start  dir=%d  vel=%s" % [dir, velocity])

	dash_fx.emitting = true
	await get_tree().create_timer(dash_time).timeout

	dash_fx.emitting = false
	velocity = Vector2.ZERO
	_log("Dash end")
	_finish(0.1)
	state = State.DASH   # движение обрабатывается в _physics_process

# 5  Teleport Sky + Orbs ----------------------------------------------------
func attack_teleport_orbs() -> void:
	var p := _player()
	if p == null:
		_finish(0.1)
		return
	var old := global_position
	global_position = (p.global_position + Vector2(0, -teleport_height_far)
	).clamp(arena_bounds.position + Vector2(32,32),
			arena_bounds.end      - Vector2(32,32))
	_log("TeleportOrbs %s → %s" % [old, global_position])

	summon_fx.restart()
	_spawn_orb()
	_finish(1.0)

# ── ORB --------------------------------------------------------------------
func _spawn_orb() -> void:
	var orb := preload("res://scenes/HomingOrb.tscn").instantiate()

	# 1. Вставляем в иерархию
	proj_root.add_child(orb)

	# 2. Ставим точно над боссом (-32 px по Y)
	orb.global_position = global_position + Vector2(0, -32)
	#  ─ или ─  orb.position = Vector2(0, -32)  # локально, если проще

	_log("Orb spawn pos=%s" % orb.global_position)

# ── DAMAGE / DEATH ---------------------------------------------------------
func take_damage(amount:int) -> void:
	var old := health
	health = max(health - amount, 0)
	_log("HP %d → %d (-%d)" % [old, health, amount])
	if health == 0:
		_log("DEAD (босс уничтожен)")
		queue_free()


func _on_magic_splash_area_body_entered(body: Node) -> void:
	_log("Signal _on_magic_splash_area_body_entered fired with: %s" % body)
	if not splash_area.monitoring:
		_log("  → но monitoring == false, выходим")
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		_log("  → в зоне игрок, наносим %d урона" % splash_damage)
		body.take_damage(splash_damage)
	else:
		_log("  → тело не подходит: groups=%s, has take_damage? %s"
			% [body.get_groups(), body.has_method("take_damage")])
