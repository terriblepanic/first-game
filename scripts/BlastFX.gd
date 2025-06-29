extends Node
# ===============================
#  Экранный эффект: круговые волны
#  от позиции игрока (UV-координаты)
# ===============================

@export var shader_scene: PackedScene = preload("res://scenes/wave_ca.tscn")
@export var duration:    float       = 0.6
@export var max_amp:     float       = 2.5

var _layer: CanvasLayer
var _rect:  ColorRect
var _timer: float = 0.0
var _active: bool  = false

func _ready() -> void:
	# Инстанс сцены эффекта и фуллскрин ColorRect
	_layer = shader_scene.instantiate() as CanvasLayer
	_rect  = _layer.get_node("ColorRect") as ColorRect
	_rect.visible = false
	# Anchor full screen
	_rect.anchor_left   = 0
	_rect.anchor_top    = 0
	_rect.anchor_right  = 1
	_rect.anchor_bottom = 1
	_rect.position = Vector2.ZERO

	get_tree().root.call_deferred("add_child", _layer)
	set_process(true)

#───────────────────────────────────────────
# Конвертация мировой позиции → UV [0..1]
# с учётом лимитов и зума камеры
func _world_to_uv(world_pos: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Vector2(0.5, 0.5)

	var vp := get_viewport()
	var vp_size := vp.get_visible_rect().size

	# Точка мира, что находится в центре экрана
	var screen_center_world: Vector2 = cam.get_screen_center_position()

	# Смещение игрока относительно этого центра (в мировых юнитах)
	var offset_world: Vector2 = world_pos - screen_center_world

	# Переводим в пиксели с учётом зума
	var offset_px: Vector2 = offset_world * cam.zoom

	# Экранная точка (px) от левого-верхнего угла
	var screen_pos: Vector2 = offset_px + vp_size * 0.5

	# Нормализуем в UV (0..1)
	return screen_pos / vp_size

#───────────────────────────────────────────
# Вызывать так:
#    BlastFX.trigger_blast(player.global_position)
func trigger_blast(world_pos: Vector2) -> void:
	var uv := _world_to_uv(world_pos)
	var vp_size := get_viewport().get_visible_rect().size

	var mat := _rect.material as ShaderMaterial
	mat.set_shader_parameter("center_uv",  uv)
	mat.set_shader_parameter("screen_size", vp_size)

	_timer  = 0.0
	_active = true
	_rect.visible = true
	_update_shader()

func _process(delta: float) -> void:
	if _active:
		_timer += delta
		_update_shader()
		if _timer >= duration:
			_active = false
			_rect.visible = false

func _update_shader() -> void:
	var mat := _rect.material as ShaderMaterial
	var t:    float = clamp(_timer / duration, 0.0, 1.0)
	var fade: float = 1.0 - t
	mat.set_shader_parameter("time",      _timer)
	mat.set_shader_parameter("wave_amp",  max_amp * fade)
	mat.set_shader_parameter("fade_out",  fade)
