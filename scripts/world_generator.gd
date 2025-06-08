extends Object
class_name WorldGenerator

const TerrainID = TerrainData.TerrainID  # из Autoload
var SOURCE_ID: Dictionary  # будет установлен в setup()

# world parameters
var world_height: int
var surface_base: int
var surface_amp: int
var surface_amp_desert: int
var surface_amp_mountain: int
var dirt_depth: int
var sand_depth: int
var sea_level: int
var beach_width: int
var cave_threshold: float
var cave_threshold_depth_factor: float
var ore_chances: Dictionary

const ORE_DEPTH := {"copper": 30, "iron": 40, "gold": 50}

var noise_surface: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_cave: FastNoiseLite
var noise_cave2: FastNoiseLite


func setup(params: Dictionary) -> void:
	SOURCE_ID = TerrainData.SOURCE_ID  # инициализация

	for key in params.keys():
		if key in self:
			self.set(key, params[key])

	noise_surface = FastNoiseLite.new()
	noise_biome = FastNoiseLite.new()
	noise_cave = FastNoiseLite.new()
	noise_cave2 = FastNoiseLite.new()

	_init_noises()


func _init_noises() -> void:
	var seed_val := randi()

	noise_surface.seed = seed_val
	noise_surface.noise_type = FastNoiseLite.TYPE_PERLIN
	noise_surface.frequency = 0.015
	noise_surface.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_surface.fractal_octaves = 4

	noise_biome.seed = seed_val + 1
	noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_biome.frequency = 0.001

	noise_cave.seed = seed_val + 2
	noise_cave.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_cave.frequency = 0.1
	noise_cave.domain_warp_enabled = true
	noise_cave.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX

	noise_cave2.seed = seed_val + 3
	noise_cave2.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise_cave2.frequency = 0.05
	noise_cave2.domain_warp_enabled = true
	noise_cave2.domain_warp_type = FastNoiseLite.DOMAIN_WARP_SIMPLEX


func get_biome(x: int) -> String:
	if noise_biome == null:
		return "forest"
	var val := noise_biome.get_noise_2d(x, 0)
	if val < -0.3:
		return "desert"
	elif val > 0.3:
		return "mountain"
	return "forest"


func surface_height(x: int, biome: String) -> int:
	if noise_surface == null:
		return surface_base
	var amp := surface_amp
	match biome:
		"desert":
			amp = surface_amp_desert
		"mountain":
			amp = surface_amp_mountain
	return surface_base + int(noise_surface.get_noise_2d(x, 0) * amp)


func is_cave(x: int, y: int) -> bool:
	if noise_cave == null or noise_cave2 == null:
		return false
	var threshold := cave_threshold - cave_threshold_depth_factor * float(y) / float(world_height)
	return noise_cave.get_noise_2d(x, y) > threshold or noise_cave2.get_noise_2d(x, y) > threshold


func terrain_for_cell(_x: int, y: int, surface_h: int, ore_start: int, biome: String) -> int:
	if y == surface_h:
		match biome:
			"desert":
				return TerrainID.SAND
			"mountain":
				return TerrainID.STONE
			_:
				if surface_h >= sea_level and surface_h <= sea_level + beach_width:
					return TerrainID.SAND
				return TerrainID.DIRT
	elif biome == "forest" and y <= surface_h + dirt_depth:
		return TerrainID.GRASS
	elif biome == "desert" and y <= surface_h + sand_depth:
		return TerrainID.SAND
	elif y >= ore_start:
		var r := randf()
		if y > ORE_DEPTH["gold"] and r < float(ore_chances["gold"]):
			return TerrainID.ORE_GOLD
		if y > ORE_DEPTH["iron"] and r < float(ore_chances["iron"]):
			return TerrainID.ORE_IRON
		if y > ORE_DEPTH["copper"] and r < float(ore_chances["copper"]):
			return TerrainID.ORE_COPPER
		return TerrainID.STONE
	else:
		return TerrainID.STONE


func create_chunk_pattern(x_start: int, x_end: int) -> TileMapPattern:
	var pattern := TileMapPattern.new()
	pattern.set_size(Vector2i(x_end - x_start, world_height))
	for x in range(x_start, x_end):
		var biome := get_biome(x)
		var h := surface_height(x, biome)
		var ore_start := h
		match biome:
			"desert":
				ore_start += sand_depth
			"forest":
				ore_start += dirt_depth
			"mountain":
				pass
		for y in range(world_height):
			if y < h:
				continue
			if is_cave(x, y):
				continue
			var terrain := terrain_for_cell(x, y, h, ore_start, biome)
			pattern.set_cell(Vector2i(x - x_start, y), SOURCE_ID[terrain], Vector2i.ZERO, 0)
	return pattern


func safe_spawn_tile(world_width: int, offset: int) -> Vector2i:
	var center_x := world_width / 2
	var biome := get_biome(center_x)
	var base_h := surface_height(center_x, biome)
	var spawn_y := base_h - offset
	while spawn_y >= 0:
		if not is_cave(center_x, spawn_y):
			return Vector2i(center_x, spawn_y)
		spawn_y -= 1
	return Vector2i(center_x, base_h - offset)
