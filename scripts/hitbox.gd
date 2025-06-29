# Hitbox.gd (вешаем на дочерний Area2D)
extends Area2D

func apply_damage(amount: int) -> void:
	get_parent().apply_damage(amount)   # прокси к манекену
