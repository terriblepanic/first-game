extends Node  # важно для Autoload

# Определение enum для всех типов террейна
enum TerrainID {
	AIR,
	DIRT,
	GRASS,
	ORE_COPPER,
	ORE_GOLD,
	ORE_IRON,
	SAND,
	STONE
}

# Словарь сопоставления типа террейна с ID тайлов
var SOURCE_ID := {
	TerrainID.AIR: 0,
	TerrainID.DIRT: 1,
	TerrainID.GRASS: 2,
	TerrainID.ORE_COPPER: 3,
	TerrainID.ORE_GOLD: 4,
	TerrainID.ORE_IRON: 5,
	TerrainID.SAND: 6,
	TerrainID.STONE: 7
}
