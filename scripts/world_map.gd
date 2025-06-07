# scripts/world.gd
extends Node

# — Параметры мира —
@export var world_width:    int = 200
@export var world_height:   int = 100
@export var surface_base:   int = 40
@export var surface_amp:    int = 8
@export var dirt_depth:     int = 5
@export var sea_level:      int = 20
@export var beach_width:    int = 3

# Шансы руды
@export var ore_chances := {
	"copper": 0.015,   # 1.5%
	"iron":   0.0075,  # 0.75%
	"gold":   0.003    # 0.3%
}

@export var world_tiles: TileSet
@onready var tilemap: TileMapLayer = $WorldMap

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

	generate_world()

func _init_noises() -> void:
	var noise_seed = randi()

	# Поверхностный шум
	noise_surface.seed            = noise_seed
	noise_surface.noise_type      = FastNoiseLite.TYPE_PERLIN
	noise_surface.frequency       = 0.015
	noise_surface.fractal_type    = FastNoiseLite.FRACTAL_FBM
	noise_surface.fractal_octaves = 4

	# Биомный шум (можно использовать для разных биомов)
	noise_biome.seed       = noise_seed + 1
	noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_biome.frequency  = 0.001

	# Пещерный шум
	noise_cave.seed                = noise_seed + 2
	noise_cave.noise_type          = FastNoiseLite.TYPE_SIMPLEX
	noise_cave.frequency           = 0.1
	noise_cave.domain_warp_enabled = true
	noise_cave.domain_warp_type    = FastNoiseLite.DOMAIN_WARP_SIMPLEX  # или BASIC_GRID

func generate_world() -> void:
	tilemap.clear()

	var ore_min_depth = surface_base + dirt_depth

	for x in range(world_width):
		var h = surface_base + int(noise_surface.get_noise_2d(x, 0) * surface_amp)

		for y in range(world_height):
			if y < h:
				continue

			var terrain: int

			if y == h:
				# пляж
				if h >= sea_level and h <= sea_level + beach_width:
					terrain = TerrainID.SAND
				else:
					terrain = TerrainID.GRASS
			elif y <= h + dirt_depth:
				terrain = TerrainID.DIRT
			elif y > ore_min_depth:
				# единый бросок
				var r = randf()
				# кумулятивные пороги
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

			tilemap.set_cell(Vector2i(x, y), SOURCE_ID[terrain], Vector2i(0, 0), 0)
