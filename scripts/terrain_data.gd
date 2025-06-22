# terrain_data.gd
# ---------------------------------
# Terrain Data Definitions (data-only)
# ---------------------------------
extends Node

## Enum всех типов террейна
# Пронумерованные константы для каждого типа
enum TerrainID {
	AIR,
	DIRT,
	SAND,
	STONE,
	WOOD,
	ORE_COPPER,
	ORE_GOLD,
	ORE_IRON,
	LEAVES,
	GRASS,
	VOID_BLACK
}

## Флаги для направлений (битмаска)
const DIR_N = 1 # север (0001)
const DIR_E = 2 # восток (0010)
const DIR_S = 4 # юг    (0100)
const DIR_W = 8 # запад (1000)

## Базовые спрайты (fallback для одиночных тайлов)
static var SOURCE_ID := {
	TerrainID.AIR: -1,
	TerrainID.DIRT: 0,
	TerrainID.SAND: 1,
	TerrainID.STONE: 2,
	TerrainID.WOOD: 3,
	TerrainID.ORE_COPPER: 4,
	TerrainID.ORE_GOLD: 5,
	TerrainID.ORE_IRON: 6,
	TerrainID.LEAVES: 7, # leaf_isolated
	TerrainID.GRASS: 17, # grass_isolated
	TerrainID.VOID_BLACK: 100
}

## Внешние стыковочные варианты (edge, corner, T, cross)
static var BITMASK_IDS := {
	# LEAVES
	TerrainID.LEAVES: {
		0: 7, # isolated
		DIR_N | DIR_E | DIR_S | DIR_W: 8, # full
		DIR_E | DIR_S | DIR_W: 9,
		DIR_S | DIR_W | DIR_N: 10,
		DIR_W | DIR_N | DIR_E: 11,
		DIR_N | DIR_E | DIR_S: 12,
		DIR_N | DIR_E: 13,
		DIR_E | DIR_S: 14,
		DIR_S | DIR_W: 15,
		DIR_W | DIR_N: 16,
	} ,

	# GRASS
	TerrainID.GRASS: {
		0: 17, # grass_isolated
		DIR_E | DIR_N | DIR_W: 18, # grass_edge_n
		DIR_N | DIR_S | DIR_E: 19, # grass_edge_e
		DIR_S | DIR_E | DIR_W: 20, # grass_edge_s
		DIR_N | DIR_W | DIR_S: 21, # grass_edge_w
		DIR_N | DIR_E: 22, # grass_corner_ne (neighbors south+west) nw ne
		DIR_E | DIR_S: 23, # grass_corner_se (neighbors north+west)
		DIR_W | DIR_S: 24, # grass_corner_sw (neighbors north+east)
		DIR_N | DIR_W: 25, # grass_corner_nw (neighbors south+east)
		DIR_E | DIR_W: 30, # grass_strip_h
		DIR_N | DIR_S: 31, # grass_strip_v
		DIR_N: 32, # grass_t_up   (missing north)
		DIR_E: 33, # grass_t_right (missing east)
		DIR_S: 34, # grass_t_down  (missing south)
		DIR_W: 35, # grass_t_left  (missing west)
		DIR_N | DIR_E | DIR_S | DIR_W: 36, # grass_cross
	} ,
}

## Внутренние (вогнутые) углы – учитывают диагональные соседи
static var INNER_MASK_IDS := {
	TerrainID.LEAVES: {
		DIR_N | DIR_W: 16,
		DIR_N | DIR_E: 13,
		DIR_E | DIR_S: 14,
		DIR_S | DIR_W: 15,
	} ,
	TerrainID.GRASS: {
		DIR_N | DIR_E: 26, # grass_inner_corner_ne
		DIR_N | DIR_W: 27, # grass_inner_corner_nw
		DIR_S | DIR_E: 28, # grass_inner_corner_se
		DIR_S | DIR_W: 29, # grass_inner_corner_sw
	} ,
}

## Выступы в диагоналях (spurs) – только для травы
static var SPUR_IDS := {
	TerrainID.GRASS: {
		"NE": 37,
		"SE": 38,
		"SW": 39,
		"NW": 40,
	} ,
}


## Утилиты
static func is_same_type(t1: int, t2: int) -> bool:
	return t1 == t2


static func is_solid(t: int) -> bool:
	return t != TerrainID.AIR
