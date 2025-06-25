extends "res://scripts/item.gd"           # Наследуем базовый Item (или Resource, если у вас иначе)
class_name BlockItem                     # ← ОБЯЗАТЕЛЬНО!

@export var terrain_id: int = -1         # ID блока в тайл-карте / world_map
