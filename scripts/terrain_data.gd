extends Node

## Enum всех типов террейна
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

## Сопоставление типа террейна с ID в TileSet
static var SOURCE_ID: Dictionary = {
	TerrainID.AIR: 0,
	TerrainID.DIRT: 1,
	TerrainID.GRASS: 2,
	TerrainID.ORE_COPPER: 3,
	TerrainID.ORE_GOLD: 4,
	TerrainID.ORE_IRON: 5,
	TerrainID.SAND: 6,
	TerrainID.STONE: 7
}
