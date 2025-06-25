extends Area2D
###############################################################################
#  SkyBeam.gd — одна “рана” на всю волну                                     #
###############################################################################

## ── EXPORTED (как раньше) ───────────────────────────────────────────────────
@export_category("Timing")
@export var marker_delay : float = 0.15
@export var warn_time    : float = 1.00

@export_category("Geometry")
@export var ground_y     : float = 500.0
@export var spawn_height : float = 600.0

@export_category("Damage / FX")
@export var active_time        : float = 0.6
@export var damage             : int   = 40
@export var damage_during_fall : bool  = false

@export_category("Wave logic")
@export var wave_window : float = 0.25          # за сколько секунд считать “одну волну”

## ── STATIC SHARED STATE (общий на все экземпляры) ──────────────────────────
static var _wave_counter      : int   = 0       # индекс текущей волны
static var _last_wave_stamp   : float = 0.0     # время последнего спавна
static var _damaged_wave_id   : int   = -1      # волна, в которой уже нанесён урон

## ── CALCULATED ──────────────────────────────────────────────────────────────
var _fall_speed     : float
var _telegraph_time : float
var _wave_id        : int                        # волна, к которой принадлежит луч

@onready var marker_fx  : GPUParticles2D = $BeamParticlesMarker
@onready var beam_fx    : GPUParticles2D = $BeamParticles
@onready var marker_sfx : AudioStreamPlayer2D = $MarkerSfx
@onready var impact_sfx : AudioStreamPlayer2D = $ImpactSfx

var _active := false

## ── TIMING CALC ─────────────────────────────────────────────────────────────
func _update_timing() -> void:
	_telegraph_time = warn_time * 0.4
	var fall_dur: float = max(warn_time - _telegraph_time, 0.05)
	_fall_speed = spawn_height / fall_dur

func _notification(what):
	if what == NOTIFICATION_POSTINITIALIZE:
		_update_timing()

## ── READY ──────────────────────────────────────────────────────────────────
func _ready() -> void:
	_update_timing()

	# 1. назначаем волну
	var now : float = Time.get_ticks_msec() / 1000.0
	if now - _last_wave_stamp > wave_window:
		_wave_counter += 1                        # новая волна
	_last_wave_stamp = now
	_wave_id = _wave_counter

	# 2. ставим луч “в небо”
	position.y      = ground_y - spawn_height
	collision_layer = 1
	collision_mask  = 1
	connect("body_entered", _on_body_entered)

	await get_tree().create_timer(marker_delay).timeout
	_show_marker()

	await get_tree().create_timer(_telegraph_time).timeout
	_start_fall()

func _show_marker() -> void:
	marker_fx.position.y = ground_y - position.y
	marker_fx.emitting   = true
	marker_sfx.play()

func _start_fall() -> void:
	marker_fx.emitting = false
	beam_fx.emitting   = true

	var dist : float = ground_y - position.y
	var dur  : float = abs(dist) / _fall_speed

	create_tween()\
		.tween_property(self, "position:y", ground_y, dur)\
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)\
		.finished.connect(_activate_hitbox)

func _activate_hitbox() -> void:
	_active = true
	beam_fx.restart()
	impact_sfx.play()
	_deal_overlap_damage()

	await get_tree().create_timer(active_time).timeout
	queue_free()

## ── DAMAGE ROUTINES ────────────────────────────────────────────────────────
func _hit_player(body: Node) -> void:
	if _wave_id == _damaged_wave_id:            # уже били в этой волне
		return
	body.take_damage(damage)
	_damaged_wave_id = _wave_id                 # помечаем, что удар нанесён

func _deal_overlap_damage() -> void:
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			_hit_player(body)

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player") or not body.has_method("take_damage"):
		return
	if (damage_during_fall or _active):
		_hit_player(body)
