extends Node

# — ID ландшафта —
const TerrainID := TerrainData.TerrainID
const Item = preload("res://scripts/item.gd")

# минимальная глубина появления руды
const ORE_DEPTH := { "copper": 30, "iron": 40, "gold": 50 }

# Настройки градиента тени
const MAX_DARK_DEPTH := 20.0 # глубина до полного затемнения в тайлах
const SHADE_TILES := 20 # количество теневых тайлов (ID 0…19)
const SHADE_ID_OFFSET := 0 # смещение, если тайлы идут с другого ID

# — Параметры мира —
@export var world_width: int = 1000
@export var world_height: int = 50
@export var surface_base: int = 10
@export var surface_amp: int = 8
@export var surface_amp_desert: int = 6
@export var surface_amp_mountain: int = 40
@export var dirt_depth: int = 10
@export var sand_depth: int = 10
@export var sea_level: int = 20
@export var beach_width: int = 3
# Порог для шума пещер
@export var cave_threshold: float = 0.7
@export var cave_threshold_depth_factor: float = 0.2
# Шансы руды
@export var ore_chances: Dictionary = { "copper": 0.015, "iron": 0.007, "gold": 0.003 }
# Соответствие TerrainID → ID тайла в TileSet

@export var chunk_width: int = 100
@export var world_tiles: TileSet

var SOURCE_ID: Dictionary = TerrainData.SOURCE_ID

var generator: WorldGenerator = WorldGenerator.new()

@onready var tilemap: TileMapLayer = $WorldMap
@onready var player: Node2D = $Player/Player

var _loaded_chunks: Dictionary = {}


func _ready() -> void:
	randomize()
	# включаем процессинг, чтобы _process вызывался каждый кадр
	set_process(true)

	# назначаем основные тайлсеты
	if world_tiles:
		tilemap.tile_set = world_tiles

	# инициализируем генератор
	generator.setup({
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
		"SOURCE_ID": SOURCE_ID
		})

	# спавн игрока и врага
	# спавн игрока и врага
	var spawn_tile: Vector2i = generator.safe_spawn_tile(world_width, 2)
	var ts: Vector2 = tilemap.tile_set.tile_size
	var spawn_pos: Vector2 = Vector2(spawn_tile.x * ts.x, spawn_tile.y * ts.y)
	if player.has_method("set_spawn_position"):
		player.set_spawn_position(spawn_pos)
	if has_node("Enemy") and $Enemy/Enemy.has_method("set_spawn_position"):
		var enemy_spawn: Vector2i = spawn_tile + Vector2i(1, 0)
		var enemy_pos: Vector2 = Vector2(enemy_spawn.x * ts.x, enemy_spawn.y * ts.y)
		$Enemy/Enemy.set_spawn_position(enemy_pos)
	if has_node("HUD/Inventory"):
		var inventory := $HUD/Inventory
		var pickaxe: Item = load("res://items/wooden_pickaxe.tres")
		inventory.add_item(pickaxe)

	# первый вызов _process, чтобы сразу отрисовать чанки и тени
	_process(0.0)
	$Player/Player.player_died.connect(_on_player_died)


func _process(_delta: float) -> void:
	var ts: Vector2 = tilemap.tile_set.tile_size
	var player_cell: int = int(player.global_position.x / ts.x)
	var current_ci: int = player_cell / chunk_width
	var min_ci = max(current_ci - 1, 0)
	var max_ci = min(current_ci + 2, int((world_width - 1) / chunk_width))

	# загрузка новых чанков
	for ci in range(min_ci, max_ci + 1):
		if not _loaded_chunks.has(ci):
			var xs = ci * chunk_width
			var xe = min(xs + chunk_width, world_width)

			# основной мир
			var patt: TileMapPattern = generator.create_chunk_pattern(xs, xe)
			tilemap.set_pattern(Vector2i(xs, 0), patt)

			# тени
			_loaded_chunks[ci] = true

	# удаление старых чанков
	var to_remove: Array = []
	for ci in _loaded_chunks.keys():
		if ci < min_ci or ci > max_ci:
			tilemap.set_pattern(Vector2i(ci * chunk_width, 0), TileMapPattern.new())
			to_remove.append(ci)
	for ci in to_remove:
		_loaded_chunks.erase(ci)

		# --- Utilities ---------------------------------------------------------------


# Удаляет блок и возвращает его TerrainID или -1, если ничего нет
func remove_block(cell: Vector2i) -> int:
	var sid: int = tilemap.get_cell_source_id(cell)
	if sid == -1:
		return - 1
	tilemap.erase_cell(cell)
	for t in SOURCE_ID.keys():
		if SOURCE_ID[t] == sid:
			return t
	return - 1


# Ставит блок указанного типа
func place_block(cell: Vector2i, terrain_id: int) -> void:
	if not SOURCE_ID.has(terrain_id):
		return
	tilemap.set_cell(cell, SOURCE_ID[terrain_id], Vector2i.ZERO, 0)


# Преобразует глобальные координаты в координаты тайла
func position_to_cell(global_pos: Vector2) -> Vector2i:
	var local: Vector2 = tilemap.to_local(global_pos)
	var ts: Vector2 = tilemap.tile_set.tile_size
	return Vector2i(floor(local.x / ts.x), floor(local.y / ts.y))


func _on_player_died() -> void:
	await get_tree().create_timer(2).timeout
	get_tree().reload_current_scene()
