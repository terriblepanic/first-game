extends Node

func _ready() -> void:
    # Ensure the exit is positioned at the player spawn point
    if has_node("Player/Player") and has_node("Exit"):
        $Exit.position = $Player/Player.position

func _on_exit_body_entered(body: Node2D) -> void:
    if body.name == "Player":
        body.set_process(false)
        TransitionManager.change_scene("res://scenes/Main.tscn")

