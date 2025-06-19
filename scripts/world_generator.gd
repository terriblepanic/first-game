# world_generator.gd
# ---------------------------------
# World generation using TerrainData definitions
# ---------------------------------
class_name WorldGenerator
extends Object

const TerrainID = TerrainData.TerrainID # из Autoload
const ORE_DEPTH := { "copper": 15, "iron": 25, "gold": 35 }

var SOURCE_ID: Dictionary # будет установлен в setup()

# Параметры мира (настраиваются в setup)
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

# Noise-генераторы
var noise_surface: FastNoiseLite
var noise_biome: FastNoiseLite
var noise_cave: FastNoiseLite
var noise_cave2: FastNoiseLite


func _init_noises() -> void:
	var seed_val := randi()
	# Поверхностной шум
	noise_surface.seed = seed_val
	noise_surface.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_surface.frequency = 0.015
	noise_surface.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_surface.fractal_octaves = 1
	# Биомный шум
	noise_biome.seed = seed_val + 1
	noise_biome.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_biome.frequency = 0.001
	noise_biome.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise_biome.fractal_octaves = 1
	# Пещерные шумы
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


func setup(params: Dictionary) -> void:
	# Инициализируем SOURCE_ID
	SOURCE_ID = TerrainData.SOURCE_ID
	# Устанавливаем параметры мира
	for key in params.keys():
		set(key, params[key])
	# Создаём и настраиваем шума
	noise_surface = FastNoiseLite.new()
	noise_biome = FastNoiseLite.new()
	noise_cave = FastNoiseLite.new()
	noise_cave2 = FastNoiseLite.new()
	_init_noises()


func get_biome(x: int) -> String:
	var val := noise_biome.get_noise_2d(x, 0)
	if val < -0.3:
		return "desert"
	elif val > 0.3:
		return "mountain"
	return "forest"


func surface_height(x: int, biome: String) -> int:
	var amp := surface_amp
	match biome:
		"desert": amp = surface_amp_desert
		"mountain": amp = surface_amp_mountain
	return surface_base + int(noise_surface.get_noise_2d(x, 0) * amp)


func is_cave(x: int, y: int) -> bool:
	var threshold := cave_threshold - cave_threshold_depth_factor * float(y) / float(world_height)
	return noise_cave.get_noise_2d(x, y) > threshold or noise_cave2.get_noise_2d(x, y) > threshold


func terrain_for_cell(x: int, y: int, surface_h: int, ore_start: int, biome: String) -> int:
	# Поверхностный слой
	if y == surface_h:
		match biome:
			"desert":
				return TerrainID.SAND
			"mountain":
				return TerrainID.STONE
			"forest":
				if surface_h >= sea_level and surface_h <= sea_level + beach_width:
					return TerrainID.SAND
				return TerrainID.GRASS
			_:
				if surface_h >= sea_level and surface_h <= sea_level + beach_width:
					return TerrainID.SAND
				return TerrainID.DIRT
	# Подповерхностные слои
	if biome == "forest" and y <= surface_h + dirt_depth:
		return TerrainID.DIRT
	if biome == "desert" and y <= surface_h + sand_depth:
		return TerrainID.SAND
	# Руды и камень
	if y >= ore_start:
		var r := randf()
		if y > ORE_DEPTH["gold"] and r < float(ore_chances["gold"]):
			return TerrainID.ORE_GOLD
		if y > ORE_DEPTH["iron"] and r < float(ore_chances["iron"]):
			return TerrainID.ORE_IRON
		if y > ORE_DEPTH["copper"] and r < float(ore_chances["copper"]):
			return TerrainID.ORE_COPPER
		return TerrainID.STONE
	return TerrainID.STONE


func get_tile_id(grid: Array, x: int, y: int) -> int:
	var t: int = grid[x][y]
	# 1) Специальная простая логика для травы на поверхности
	if t == TerrainID.GRASS:
		# проверяем, что под травой — твёрдый, но не трава
		var is_surface: bool = false
		if y < grid[x].size() - 1:
			var below: int = grid[x][y + 1]
			if TerrainData.is_solid(below) and below != TerrainID.GRASS:
				is_surface = true
		if is_surface:
			# Временно считаем нижний блок травой и используем стандартный автотайлинг
			var orig = grid[x][y + 1]
			grid[x][y + 1] = TerrainID.GRASS
			var tile := _default_tile_id(grid, x, y)
			grid[x][y + 1] = orig
			return tile
	# 2) Все остальные случаи — дефолтная битмаска-логика
	return _default_tile_id(grid, x, y)


func create_chunk_pattern(x_start: int, x_end: int) -> TileMapPattern:
	var width = x_end - x_start
	var height = world_height
	var pattern = TileMapPattern.new()
	pattern.set_size(Vector2i(width, height))

	# Шаг 1: строим grid из TerrainID
	var grid := []
	grid.resize(width)
	for i in range(width):
		grid[i] = []

	for i in range(width):
		var wx = x_start + i
		var biome = get_biome(wx)
		var h = surface_height(wx, biome)
		var ore_s = h
		if biome == "desert":
			ore_s += sand_depth
		for y in range(height):
			if y < h or is_cave(wx, y):
				grid[i].append(TerrainID.AIR)
			else:
				grid[i].append(terrain_for_cell(wx, y, h, ore_s, biome))

	# Шаг 2: ставим тайлы в паттерн
	for i in range(width):
		for y in range(height):
			var t = grid[i][y]
			if t == TerrainID.AIR or t == TerrainID.LEAVES or t == TerrainID.WOOD:
				continue
			var tile_id = get_tile_id(grid, i, y)
			pattern.set_cell(Vector2i(i, y), tile_id, Vector2i.ZERO, 0)

	return pattern


func safe_spawn_tile(world_width: int, offset: int) -> Vector2i:
	var cx = world_width / 2
	var by = surface_height(cx, get_biome(cx))
	var y0 = by - offset
	while y0 >= 0:
		if not is_cave(cx, y0):
			return Vector2i(cx, y0)
		y0 -= 1
	return Vector2i(cx, by - offset)

func find_cave_spawn_tile(world_width: int, world_height: int) -> Vector2i:
	var attempts: int = 1000
	while attempts > 0:
		var x: int = randi() % world_width
		var y: int = randi() % (world_height - 1)
		if is_cave(x, y) and not is_cave(x, y + 1):
			return Vector2i(x, y)
		attempts -= 1
	return Vector2i(world_width / 2, world_height / 2)


func _default_tile_id(grid: Array, x: int, y: int) -> int:
	# Шаг 1: Узнаём, какой тип блока находится в этой клетке
	var current_type = grid[x][y]

	# Если для этого типа нет описания "соседей" (битмасок) — вернём его простой ID
	if not TerrainData.BITMASK_IDS.has(current_type):
		return TerrainData.SOURCE_ID.get(current_type, -1)

	# Шаг 2: Начинаем определять, какие стороны у блока заняты такими же блоками
	var mask = 0 # это как флажки: каждая сторона = 1 бит

	# Смотрим ВВЕРХ: если там такой же и он твёрдый — добавляем северный бит
	if y > 0 and TerrainData.is_same_type(grid[x][y - 1], current_type) and TerrainData.is_solid(grid[x][y - 1]):
		mask |= TerrainData.DIR_S

	# Смотрим ВПРАВО
	if x < grid.size() - 1 and TerrainData.is_same_type(grid[x + 1][y], current_type) and TerrainData.is_solid(grid[x + 1][y]):
		mask |= TerrainData.DIR_W

	# Смотрим ВНИЗ
	if y < grid[x].size() - 1 and TerrainData.is_same_type(grid[x][y + 1], current_type) and TerrainData.is_solid(grid[x][y + 1]):
		mask |= TerrainData.DIR_N

	# Смотрим ВЛЕВО
	if x > 0 and TerrainData.is_same_type(grid[x - 1][y], current_type) and TerrainData.is_solid(grid[x - 1][y]):
		mask |= TerrainData.DIR_E

	# Шаг 3: Проверка диагоналей — нужны ли "вогнутые углы"
	var inner_corner_tiles = TerrainData.INNER_MASK_IDS.get(current_type, {})

	# Проверяем 4 диагонали (NW, NE, SE, SW)
	var has_sw = x > 0 and y > 0 and TerrainData.is_same_type(grid[x - 1][y - 1], current_type) and TerrainData.is_solid(grid[x - 1][y + 1])
	var has_se = x < grid.size() - 1 and y > 0 and TerrainData.is_same_type(grid[x + 1][y - 1], current_type) and TerrainData.is_solid(grid[x + 1][y + 1])
	var has_nw = x < grid.size() - 1 and y < grid[x].size() - 1 and TerrainData.is_same_type(grid[x + 1][y + 1], current_type) and TerrainData.is_solid(grid[x + 1][y - 1])
	var has_ne = x > 0 and y < grid[x].size() - 1 and TerrainData.is_same_type(grid[x - 1][y + 1], current_type) and TerrainData.is_solid(grid[x - 1][y - 1])

	# Если, например, блок сверху и слева есть, и ещё и по диагонали (северо-запад) — ставим специальный угол
	if mask == (TerrainData.DIR_N | TerrainData.DIR_W) and has_nw and inner_corner_tiles.has(TerrainData.DIR_N | TerrainData.DIR_W):
		return inner_corner_tiles[TerrainData.DIR_N | TerrainData.DIR_W]

	if mask == (TerrainData.DIR_N | TerrainData.DIR_E) and has_ne and inner_corner_tiles.has(TerrainData.DIR_N | TerrainData.DIR_E):
		return inner_corner_tiles[TerrainData.DIR_N | TerrainData.DIR_E]

	if mask == (TerrainData.DIR_E | TerrainData.DIR_S) and has_se and inner_corner_tiles.has(TerrainData.DIR_E | TerrainData.DIR_S):
		return inner_corner_tiles[TerrainData.DIR_E | TerrainData.DIR_S]

	if mask == (TerrainData.DIR_S | TerrainData.DIR_W) and has_sw and inner_corner_tiles.has(TerrainData.DIR_S | TerrainData.DIR_W):
		return inner_corner_tiles[TerrainData.DIR_S | TerrainData.DIR_W]

	# Шаг 4: Если вообще нет соседей по прямым, но есть по диагонали — проверим "выступающие диагонали"
	if mask == 0 and TerrainData.SPUR_IDS.has(current_type):
		var spurs = TerrainData.SPUR_IDS[current_type]
		if has_ne: return spurs["NE"]
		if has_se: return spurs["SE"]
		if has_sw: return spurs["SW"]
		if has_nw: return spurs["NW"]

	# Шаг 5: Вернём нужный ID блока, исходя из маски
	# Если для маски есть спрайт — используем его. Если нет — берём стандартный.
	return TerrainData.BITMASK_IDS[current_type].get(mask, TerrainData.SOURCE_ID[current_type])
