extends Node

# — Параметры мира —
@export var world_width:    int = 2000
@export var world_height:   int = 100
@export var surface_base:   int = 40
@export var surface_amp:    int = 8
@export var dirt_depth:     int = 5
@export var sea_level:      int = 20
@export var beach_width:    int = 3

# Порог для шума пещер: значения выше создают пустоты
@export var cave_threshold: float = 0.6

# Шансы руды
@export var ore_chances := {
	"copper": 0.015,
	"iron":   0.0075,
	"gold":   0.003
}

@export var world_tiles: TileSet
@export var chunk_width: int = 100
@export var player_path: NodePath = NodePath("Player")

@onready var tilemap: TileMapLayer = $WorldMap
@onready var player: Node2D    = get_node(player_path)

# Кэш загруженных чанков: индекс чанка -> true
var _loaded_chunks := {}

enum TerrainID { DIRT, GRASS, SAND, STONE, ORE_COPPER, ORE_IRON, ORE_GOLD }
var SOURCE_ID = {
	TerrainID.DIRT:       1,
	TerrainID.GRASS:      2,
	TerrainID.ORE_COPPER: 3,
	TerrainID.ORE_GOLD:   4,
	TerrainID.ORE_IRON:   5,
	TerrainID.SAND:       6,
	TerrainID.STONE:      7
}

# Шумы
var noise_surface := FastNoiseLite.new()
var noise_biome   := FastNoiseLite.new()
var noise_cave    := FastNoiseLite.new()

func _ready() -> void:
	randomize()
	_init_noises()

	if world_tiles:
		tilemap.tile_set = preload("res://assets/tilesets/world_tiles.tres") as TileSet

	# При старте загружаем первый диапазон чанков
	_process(0.0)

func _init_noises() -> void:
	var seed = randi()
	noise_surface.seed            = seed
	noise_surface.noise_type      = FastNoiseLite.TYPE_PERLIN
	noise_surface.frequency       = 0.015
	noise_surface.fractal_type    = FastNoiseLite.FRACTAL_FBM
	noise_surface.fractal_octaves = 4

	noise_biome.seed       = seed + 1
	noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_biome.frequency  = 0.001

	noise_cave.seed                = seed + 2
	noise_cave.noise_type          = FastNoiseLite.TYPE_SIMPLEX
	noise_cave.frequency           = 0.1
	noise_cave.domain_warp_enabled = true
	noise_cave.domain_warp_type    = FastNoiseLite.DOMAIN_WARP_SIMPLEX

func _create_chunk_pattern(x_start: int, x_end: int) -> TileMapPattern:
	var pattern := TileMapPattern.new()
	pattern.set_size(Vector2i(x_end - x_start, world_height))
	var ore_min_depth = surface_base + dirt_depth

	for x in range(x_start, x_end):
		var h = surface_base + int(noise_surface.get_noise_2d(x, 0) * surface_amp)
		for y in range(world_height):
			if y < h:
				continue
			if noise_cave.get_noise_2d(x, y) > cave_threshold:
				continue

			var terrain: int
			if y == h:
				if h >= sea_level and h <= sea_level + beach_width:
					terrain = TerrainID.SAND
				else:
					terrain = TerrainID.GRASS
			elif y <= h + dirt_depth:
				terrain = TerrainID.DIRT
			elif y > ore_min_depth:
				var r = randf()
				var p_gold   = ore_chances.gold
				var p_iron   = p_gold + ore_chances.iron
				var p_copper = p_iron + ore_chances.copper

				if r < p_gold:
					terrain = TerrainID.ORE_GOLD
				elif r < p_iron:
					terrain = TerrainID.ORE_IRON
				elif r < p_copper:
					terrain = TerrainID.ORE_COPPER
				else:
					terrain = TerrainID.STONE
			else:
				terrain = TerrainID.STONE

			pattern.set_cell(Vector2i(x - x_start, y), SOURCE_ID[terrain], Vector2i(0, 0), 0)

	return pattern

func _process(delta: float) -> void:
	var tile_size   = tilemap.tile_set.tile_size.x
	var player_cell = int(player.position.x / tile_size)
	var current_ci  = int(player_cell / chunk_width)

	# хотим видеть чанки от (current_ci - 1) до (current_ci + 2)
	var min_ci = max(current_ci - 1, 0)
	var max_ci = min(current_ci + 2, int((world_width - 1) / chunk_width))

	# ЗАГРУЗКА новых чанков
	for ci in range(min_ci, max_ci + 1):
		if not _loaded_chunks.has(ci):
			var xs = ci * chunk_width
			var xe = min(xs + chunk_width, world_width)
			var patt = _create_chunk_pattern(xs, xe)
			tilemap.set_pattern(Vector2i(xs, 0), patt)
			_loaded_chunks[ci] = true

	# ВЫГРУЗКА удалённых чанков
	var to_remove := []
	for ci in _loaded_chunks.keys():
		if ci < min_ci or ci > max_ci:
			var xs = ci * chunk_width
			tilemap.set_pattern(Vector2i(xs, 0), TileMapPattern.new())
			to_remove.append(ci)

	for ci in to_remove:
		_loaded_chunks.erase(ci)
