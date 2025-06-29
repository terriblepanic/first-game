extends CanvasLayer

var fade_rect: ColorRect

func _ready() -> void:
	# Создаём full-screen чёрный прямоугольник и прячем
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.visible = false
	add_child(fade_rect)

func change_scene(scene_path: String) -> void:
	# Плавный fade out
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	
	var tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished
	
	# Смена сцены
	get_tree().change_scene_to_file(scene_path)
	# Плавный fade in
	tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	fade_rect.visible = false
