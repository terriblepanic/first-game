extends TileMapLayer

@export var player_path: NodePath
var player: CharacterBody2D
var tilemap: TileMap
var layer_id: int
var original_tiles := {}

func _ready():
	player = get_node_or_null(player_path)

	# Получаем родителя TileMap
	tilemap = get_parent() as TileMap
	if tilemap == null:
		push_error("TileMapLayer должен быть дочерним узлом TileMap!")
		return

	# Находим ID текущего слоя
	layer_id = -1
	for i in range(tilemap.get_layers_count()):
		if tilemap.get_layer(i) == self:
			layer_id = i
			break

	if layer_id == -1:
		push_error("Не удалось найти ID для TileMapLayer")
		return

	# Сохраняем изначальные тайлы
	for coords in tilemap.get_used_cells(layer_id):
		original_tiles[coords] = tilemap.get_cell_source_id(layer_id, coords)


func _process(_delta):
	if not player or layer_id == -1:
		return

	var py = player.global_position.y

	for coords in original_tiles.keys():
		var world_y = tilemap.map_to_local(coords).y
		var current_id = tilemap.get_cell_source_id(layer_id, coords)
		var original_id = original_tiles[coords]

		if world_y < py:
			if current_id != -1:
				tilemap.set_cell(layer_id, coords, -1)
		else:
			if current_id == -1:
				tilemap.set_cell(layer_id, coords, original_id)
