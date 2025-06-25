extends Area2D
###############################################################################
# HomingOrbSprite.gd — спрайтовый орб: хвост «долёт-усыхание» + Hit/Tail FX  #
###############################################################################

# ── EXPORTED ────────────────────────────────────────────────────────────────
@export_group("Charge / Telegraph")
@export var charge_time  : float = 0.45
@export var pulse_scale  : float = 0.12
@export var pulse_rate   : float = 6.0

@export_group("Movement")
@export var accel        : float = 350.0
@export var max_speed    : float = 280.0
@export var turn_speed   : float = 140.0
@export var random_start : float = 25.0

@export_group("Lifetime / Damage")
@export var life_time : float = 2.5
@export var damage    : int   = 20

@export_group("Collision")
@export var hit_radius : float = 4.0:
	set = _set_radius

@export_group("Trail")
@export var trail_max_points : int   = 25
@export var trail_step       : float = 0.016   # сек между точками

# ── CHILD NODES ─────────────────────────────────────────────────────────────
@onready var orb      : AnimatedSprite2D   = $Sprite
@onready var trail    : Line2D             = $Trail
@onready var shape    : CollisionShape2D   = $Collision
@onready var sfx      : AudioStreamPlayer2D = $"SfxCharge"
@onready var hitfx    : GPUParticles2D     = $HitParticles
@onready var trailfx  : GPUParticles2D     = $TrailParticles   # ← ваш дым/искры

# ── INTERNAL VARS ───────────────────────────────────────────────────────────
const TAU := PI * 2
var _vel        : Vector2 = Vector2.ZERO
var _player     : CharacterBody2D
var _charging   : bool = true
var _pulse_acc  : float = 0.0
var _trail_acc  : float = 0.0
var _dead       : bool = false
var _shrinking  : bool = false           # хвост «режется», новые точки не добавляем

# ── SETTER ──────────────────────────────────────────────────────────────────
func _set_radius(r: float) -> void:
	hit_radius = max(r, 2.0)
	if shape.shape == null:
		shape.shape = CircleShape2D.new()
	(shape.shape as CircleShape2D).radius = hit_radius

# ── EDITOR PREVIEW ─────────────────────────────────────────────────────────
func _notification(what):
	if what == NOTIFICATION_POSTINITIALIZE and Engine.is_editor_hint():
		_set_radius(hit_radius)
		_setup_trail()
	elif what == NOTIFICATION_PROCESS and Engine.is_editor_hint():
		if _charging:
			_pulse_acc += get_process_delta_time() * pulse_rate
			orb.scale = Vector2.ONE * (1.0 + pulse_scale * sin(_pulse_acc))

# ── READY ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_set_radius(hit_radius)
	_setup_trail()
	hitfx.emitting    = false
	trailfx.emitting  = true
	trailfx.one_shot  = false

	_player = get_tree().get_first_node_in_group("player")
	_vel    = Vector2.RIGHT.rotated(randf_range(0, TAU)) * random_start

	orb.play()
	shape.disabled = true
	sfx.play()

	connect("body_entered", _on_body_entered)

	await get_tree().create_timer(charge_time).timeout
	_charging = false
	shape.disabled = false
	orb.scale = Vector2.ONE

	if life_time > 0:
		await get_tree().create_timer(life_time).timeout
		call_deferred("_despawn")

# ── TRAIL ──────────────────────────────────────────────────────────────────
func _setup_trail() -> void:
	trail.clear_points()
	trail.set_as_top_level(true)
	var curve := Curve.new()
	curve.add_point(Vector2(1,0.4))
	curve.add_point(Vector2(0,0))
	trail.width_curve = curve
	trail.add_point(global_position)

# ── MAIN LOOP ──────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if _charging:
		_pulse_acc += delta * pulse_rate
		orb.scale = Vector2.ONE * (1.0 + pulse_scale * sin(_pulse_acc))

	_update_homing(delta)
	global_position += _vel * delta
	_update_trail(delta)

func _update_homing(delta: float) -> void:
	if _player == null or not _player.is_inside_tree():
		_player = get_tree().get_first_node_in_group("player")
		return

	var desired_dir := (_player.global_position - global_position).normalized()
	var desired_vel := desired_dir * max_speed

	var ang_diff := _vel.angle_to(desired_vel)
	var max_rot  := deg_to_rad(turn_speed) * delta
	_vel = _vel.rotated(clamp(ang_diff, -max_rot, max_rot))
	_vel = _vel.move_toward(desired_vel, accel * delta).limit_length(max_speed)

func _update_trail(delta: float) -> void:
	_trail_acc += delta
	if _trail_acc < trail_step:
		return
	_trail_acc = 0.0

	if _shrinking:
		if trail.points.size() > 0:
			trail.remove_point(0)                # «срезаем» хвост
		else:
			queue_free()                         # хвост исчез — удаляем узел
		return

	trail.add_point(global_position)
	if trail.points.size() > trail_max_points:
		trail.remove_point(0)

# ── DAMAGE ────────────────────────────────────────────────────────────────
func _on_body_entered(body: Node) -> void:
	if _dead:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		call_deferred("_despawn")

func _despawn() -> void:
	if _dead:
		return
	_dead      = true
	_shrinking = true                        # запускаем усыхание Line2D

	shape.set_deferred("disabled", true)
	orb.visible       = false
	hitfx.emitting    = true                 # вспышка попадания
	trailfx.one_shot  = true                 # чтобы не спавнил новые
	trailfx.emitting  = false               # остаётся только догорание
