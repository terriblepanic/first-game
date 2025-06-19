extends CanvasLayer
class_name TransitionManager

var fade_rect: ColorRect
	
	func _ready() -> void:
	fade_rect = ColorRect.new()
	fade_rect.color = Color.BLACK
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.visible = false
	add_child(fade_rect)
	
	func change_scene(scene_path: String) -> void:
	fade_rect.visible = true
	fade_rect.modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished
	get_tree().change_scene_to_file(scene_path)
	tween = get_tree().create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
	await tween.finished
	fade_rect.visible = false
