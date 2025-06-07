extends SubViewport

@export var camera_node : Node2D
@export var player_node : Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	 # "world_2d" refers to this SubViewport's own 2D world.
	 # "get_tree().root" will fetch the game's main viewport.
	world_2d = get_tree().root.world_2d

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	# Let camera move with player
	camera_node.position = player_node.position
