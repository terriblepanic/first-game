extends Node2D

var _chosen: Dictionary = {}

@onready var _animated_sprite = $Fire
@onready var _altar_scene: PackedScene = preload("res://scenes/altar.tscn")


func _ready() -> void:
	_spawn_altars()


func _process(delta: float) -> void:
	_animated_sprite.play("fire")


func _spawn_altars() -> void:
        var altar1: GodAltar = _altar_scene.instantiate()
        altar1.position = Vector2(-72, 64)
        altar1.god_name = "GodA"
        altar1.blessings = ["Сила", "Защита"]
        add_child(altar1)
        altar1.blessing_selected.connect(_on_blessing_selected)
        var hud = get_node_or_null("HUD")
        if hud != null:
                altar1.blessing_selected.connect(hud.update_blessings_list)

        var altar2: GodAltar = _altar_scene.instantiate()
        altar2.position = Vector2(72, 64)
        altar2.god_name = "GodB"
        altar2.blessings = ["Мудрость", "Удача"]
        add_child(altar2)
        altar2.blessing_selected.connect(_on_blessing_selected)
        if hud != null:
                altar2.blessing_selected.connect(hud.update_blessings_list)


func _on_blessing_selected(god: String, blessing: String) -> void:
	_chosen[god] = blessing
	if _chosen.size() >= 2:
		TransitionManager.change_scene("res://scenes/Levels/kingdom_king.tscn")
