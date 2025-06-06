extends CanvasLayer

@onready var mat: ShaderMaterial = $ColorRect.material
@onready var cam: Camera2D       = get_viewport().get_camera_2d()

func _process(_delta: float) -> void:
	if cam == null:
		return

	# 1) Определяем, где «солнце» в мире
	var sun_world_pos: Vector2 = Vector2(100, 200)  # поставь сюда свою точку, например Vector2(100, 200)

	# 2) Получаем размер видимой области в пикселях
	var view_size: Vector2 = get_viewport().get_visible_rect().size

	# 3) Вычисляем смещение от центра камеры (в пикселях)
	#    cam.global_position — это координаты центра экрана в мировых единицах
	var cam_offset: Vector2 = (sun_world_pos - cam.global_position) + (view_size * 0.5)

	# 4) Получаем UV [0..1] = делим на размер экрана
	var sun_screen: Vector2 = Vector2(
		cam_offset.x / view_size.x,
		cam_offset.y / view_size.y
	)

	# 5) Передаём в шейдер
	mat.set_shader_parameter("light_pos_screen", sun_screen)
