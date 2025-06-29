extends Label

@export var rise := 32.0      # пикселей вверх
@export var lifetime := 0.8   # секунд

func _ready() -> void:
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# подъём
	tw.tween_property(self, "position:y", position.y - rise, lifetime)
	# параллельно растворяем
	tw.parallel().tween_property(self, "modulate:a", 0.0, lifetime)
	tw.tween_callback(queue_free)
