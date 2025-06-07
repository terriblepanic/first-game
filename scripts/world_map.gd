extends Node

# — ID ландшафта —
enum TerrainID {
	AIR,
	GRASS,
	DIRT,
	ORE_COPPER,
	ORE_GOLD,
	ORE_IRON,
	SAND,
	STONE
}

# — Параметры мира —
@export var world_width: int    = 2000
@export var world_height: int   = 100
@export var surface_base: int   = 40
@export var surface_amp: int    = 8
@export var dirt_depth: int     = 5
@export var sea_level: int      = 20
@export var beach_width: int    = 3

# Порог для шума пещер
@export var cave_threshold: float = 0.6

# Шансы руды
@export var ore_chances: Dictionary = {
	"copper": 0.015,
	"iron":   0.007,
	"gold":   0.003
}

# Соответствие TerrainID → ID тайла в TileSet
@export var SOURCE_ID: Dictionary = {
	TerrainID.AIR:        0,
	TerrainID.DIRT:       1,
	TerrainID.GRASS:      2,
	TerrainID.ORE_COPPER: 3,
	TerrainID.ORE_GOLD:   4,
	TerrainID.ORE_IRON:   5,
	TerrainID.SAND:       6,
	TerrainID.STONE:      7
}

@export var chunk_width: int = 100
@export var world_tiles: TileSet

# FastNoiseLite для разных шумов
var noise_surface: FastNoiseLite = FastNoiseLite.new()
var noise_biome:   FastNoiseLite = FastNoiseLite.new()
var noise_cave:    FastNoiseLite = FastNoiseLite.new()

@onready var tilemap: TileMapLayer = $WorldMap
@onready var player: Node2D        = $Player

var _loaded_chunks: Dictionary = {}

func _ready() -> void:
	randomize()
	_init_noises()
	if world_tiles:
		tilemap.tile_set = world_tiles
	_process(0.0)

func _init_noises() -> void:
	var noise_seed: int = randi()  # переименовали, чтобы не тенью встроенную seed()
	noise_surface.seed            = noise_seed
	noise_surface.noise_type      = FastNoiseLite.TYPE_PERLIN
	noise_surface.frequency       = 0.015
	noise_surface.fractal_type    = FastNoiseLite.FRACTAL_FBM
	noise_surface.fractal_octaves = 4

	noise_biome.seed       = noise_seed + 1
	noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_biome.frequency  = 0.001

	noise_cave.seed                = noise_seed + 2
	noise_cave.noise_type          = FastNoiseLite.TYPE_SIMPLEX
	noise_cave.frequency           = 0.1
	noise_cave.domain_warp_enabled = true
	noise_cave.domain_warp_type    = FastNoiseLite.DOMAIN_WARP_SIMPLEX

func _create_chunk_pattern(x_start: int, x_end: int) -> TileMapPattern:
	var pattern: TileMapPattern = TileMapPattern.new()
	pattern.set_size(Vector2i(x_end - x_start, world_height))
	var ore_min_depth: int = surface_base + dirt_depth

	for x in range(x_start, x_end):
		var h: int = surface_base + int(noise_surface.get_noise_2d(x, 0) * surface_amp)
		for y in range(world_height):
			if y < h:
				continue
			if noise_cave.get_noise_2d(x, y) > cave_threshold:
				continue

			var terrain: int
			if y == h:
				terrain = TerrainID.SAND if (h >= sea_level and h <= sea_level + beach_width) else TerrainID.GRASS
			elif y <= h + dirt_depth:
				terrain = TerrainID.DIRT
			elif y > ore_min_depth:
				var r: float   = randf()
				var p_gold: float   = ore_chances["gold"]
				var p_iron: float   = p_gold + ore_chances["iron"]
				var p_copper: float = p_iron + ore_chances["copper"]

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

			pattern.set_cell(Vector2i(x - x_start, y), SOURCE_ID[terrain], Vector2i.ZERO, 0)

	return pattern

func _process(_delta: float) -> void:
	var tile_size: float = tilemap.tile_set.tile_size.x
	var player_cell: int = int(player.position.x / tile_size)
	@warning_ignore("integer_division")
	var current_ci: int  = int(player_cell / chunk_width)   # целочисленное деление без предупреждений

	var min_ci: int = max(current_ci - 1, 0)
	@warning_ignore("integer_division")
	var max_ci: int = min(current_ci + 2, int((world_width - 1) / chunk_width))

	# загрузка новых чанков
	for ci in range(min_ci, max_ci + 1):
		if not _loaded_chunks.has(ci):
			var xs: int = ci * chunk_width
			var xe: int = min(xs + chunk_width, world_width)
			var patt: TileMapPattern = _create_chunk_pattern(xs, xe)
			tilemap.set_pattern(Vector2i(xs, 0), patt)
			_loaded_chunks[ci] = true

	# выгрузка устаревших чанков
	var to_remove: Array = []
	for ci in _loaded_chunks.keys():
		if ci < min_ci or ci > max_ci:
			tilemap.set_pattern(Vector2i(ci * chunk_width, 0), TileMapPattern.new())
			to_remove.append(ci)
	for ci in to_remove:
		_loaded_chunks.erase(ci)

func remove_block(cell: Vector2i) -> int:
	var source_id: int = tilemap.get_cell_source_id(cell)
	if source_id == -1:
		return -1
	tilemap.erase_cell(cell)
	for terrain_key in SOURCE_ID.keys():
		if SOURCE_ID[terrain_key] == source_id:
			return terrain_key
	return -1

func place_block(cell: Vector2i, terrain_id: int) -> void:
	if not SOURCE_ID.has(terrain_id):
		return
	tilemap.set_cell(cell, SOURCE_ID[terrain_id], Vector2i.ZERO, 0)

func position_to_cell(global_pos: Vector2) -> Vector2i:
	var local: Vector2 = tilemap.to_local(global_pos)
	var ts: Vector2    = tilemap.tile_set.tile_size
	return Vector2i(floor(local.x / ts.x), floor(local.y / ts.y))
