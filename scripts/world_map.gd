extends Node

# — ID ландшафта —
enum TerrainID { AIR, GRASS, DIRT, ORE_COPPER, ORE_GOLD, ORE_IRON, SAND, STONE }

# — Параметры мира —
@export var world_width: int = 6000
@export var world_height: int = 100
@export var surface_base: int = 0
@export var surface_amp: int = 8
@export var surface_amp_desert: int = 6
@export var surface_amp_mountain: int = 12
@export var dirt_depth: int = 5
@export var sand_depth: int = 4
@export var sea_level: int = 20
@export var beach_width: int = 3

# Порог для шума пещер
@export var cave_threshold: float = 0.6
@export var cave_threshold_depth_factor: float = 0.2

# Шансы руды
@export var ore_chances: Dictionary = {"copper": 0.015, "iron": 0.007, "gold": 0.003}

# минимальная глубина появления руды
const ORE_DEPTH := {"copper": 30, "iron": 40, "gold": 50}

# Соответствие TerrainID → ID тайла в TileSet
@export var SOURCE_ID: Dictionary = {
	TerrainID.AIR: 0,
	TerrainID.DIRT: 1,
	TerrainID.GRASS: 2,
	TerrainID.ORE_COPPER: 3,
	TerrainID.ORE_GOLD: 4,
	TerrainID.ORE_IRON: 5,
	TerrainID.SAND: 6,
	TerrainID.STONE: 7
}

@export var chunk_width: int = 100
@export var world_tiles: TileSet

var generator: WorldGenerator = WorldGenerator.new()

@onready var tilemap: TileMapLayer = $WorldMap
@onready var player: Node2D = $Player

var _loaded_chunks: Dictionary = {}


func _ready() -> void:
	randomize()
	if world_tiles:
		tilemap.tile_set = world_tiles

		# 1) Рассчитываем тайловую точку спавна и конвертируем в пиксели

		# 2) Спавним игрока и сбрасываем сглаживание камеры

		# 3) Спавним врага на 1 тайл правее

		# 4) Загружаем чанки вокруг игрока

		# 5) Подписываемся на сигнал смерти
	(
		generator
		. setup(
			{
				"world_height": world_height,
				"surface_base": surface_base,
				"surface_amp": surface_amp,
				"surface_amp_desert": surface_amp_desert,
				"surface_amp_mountain": surface_amp_mountain,
				"dirt_depth": dirt_depth,
				"sand_depth": sand_depth,
				"sea_level": sea_level,
				"beach_width": beach_width,
				"cave_threshold": cave_threshold,
				"cave_threshold_depth_factor": cave_threshold_depth_factor,
				"ore_chances": ore_chances,
				"SOURCE_ID": SOURCE_ID,
			}
		)
	)

	# 1) Рассчитываем тайловую точку спавна и конвертируем в пиксели
	var spawn_tile: Vector2i = generator.safe_spawn_tile(world_width, 2)
	var ts: Vector2 = tilemap.tile_set.tile_size
	var spawn_pos: Vector2 = Vector2(spawn_tile.x * ts.x, spawn_tile.y * ts.y)

	# 2) Спавним игрока и сбрасываем сглаживание камеры
	if player.has_method("set_spawn_position"):
		player.set_spawn_position(spawn_pos)

		# 3) Спавним врага на 1 тайл правее

		# 4) Загружаем чанки вокруг игрока

		# 5) Подписываемся на сигнал смерти
	if has_node("Enemy") and $Enemy.has_method("set_spawn_position"):
		var enemy_spawn: Vector2i = spawn_tile + Vector2i(1, 0)
		var enemy_pos: Vector2 = Vector2(enemy_spawn.x * ts.x, enemy_spawn.y * ts.y)
		$Enemy.set_spawn_position(enemy_pos)

		# 4) Загружаем чанки вокруг игрока

		# 5) Подписываемся на сигнал смерти
	_process(0.0)

	# 5) Подписываемся на сигнал смерти
	$Player.player_died.connect(_on_player_died)


func _on_player_died() -> void:
	await get_tree().create_timer(2).timeout
	get_tree().reload_current_scene()


func _process(_delta: float) -> void:
	var ts: Vector2 = tilemap.tile_set.tile_size
	var player_cell: int = int(player.global_position.x / ts.x)
	var current_ci: int = player_cell / chunk_width

	var min_ci: int = max(current_ci - 1, 0)
	var max_ci: int = min(current_ci + 2, int((world_width - 1) / chunk_width))

	for ci in range(min_ci, max_ci + 1):
		if not _loaded_chunks.has(ci):
			var xs: int = ci * chunk_width
			var xe: int = min(xs + chunk_width, world_width)
			var patt: TileMapPattern = generator.create_chunk_pattern(xs, xe)
			tilemap.set_pattern(Vector2i(xs, 0), patt)
			_loaded_chunks[ci] = true

		# удаляем устаревшие чанки
	var to_remove := []
	for ci in _loaded_chunks.keys():
		if ci < min_ci or ci > max_ci:
			tilemap.set_pattern(Vector2i(ci * chunk_width, 0), TileMapPattern.new())
			to_remove.append(ci)
	for ci in to_remove:
		_loaded_chunks.erase(ci)


func remove_block(cell: Vector2i) -> int:
	var sid: int = tilemap.get_cell_source_id(cell)
	if sid == -1:
		return -1
	tilemap.erase_cell(cell)
	for t in SOURCE_ID.keys():
		if SOURCE_ID[t] == sid:
			return t
	return -1


func place_block(cell: Vector2i, terrain_id: int) -> void:
	if not SOURCE_ID.has(terrain_id):
		return
	tilemap.set_cell(cell, SOURCE_ID[terrain_id], Vector2i.ZERO, 0)


func position_to_cell(global_pos: Vector2) -> Vector2i:
	var local: Vector2 = tilemap.to_local(global_pos)
	var ts: Vector2 = tilemap.tile_set.tile_size
	return Vector2i(floor(local.x / ts.x), floor(local.y / ts.y))
