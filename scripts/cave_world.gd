# cave_world.gd
# ------------------------------------------------------------------------------
# Пещерный уровень - ставит вокруг «нережибельной» зоны чёрный тайл-пустоту
# ------------------------------------------------------------------------------
extends Node

const Item      = preload("res://scripts/item.gd")
const TerrainID = TerrainData.TerrainID

# -----------------------------------------------------------------------------#
#  ID ЧЁРНОГО ТАЙЛА – берём тот же самый, что хранится в TerrainData
# -----------------------------------------------------------------------------#
const VOID_SOURCE_ID : int = 100

# -----------------------------------------------------------------------------#
#  ПАРАМЕТРЫ МИРА (можно менять из инспектора)
# -----------------------------------------------------------------------------#
@export var world_width  : int = 41
@export var world_height : int = 41

@export var cave_threshold              : float  = 0.4
@export var cave_threshold_depth_factor : float  = 0.2
@export var ore_chances : Dictionary = { "copper": 0.015, "iron": 0.007, "gold": 0.003 }

@export var world_tiles : TileSet               # назначьте свой TileSet

var SOURCE_ID : Dictionary        = TerrainData.SOURCE_ID
var generator  : WorldGenerator   = WorldGenerator.new()

# — сцены / узлы — -------------------------------------------------------------
@onready var tilemap    : TileMapLayer = $WorldMap
@onready var player     : Node2D       = $Player/Player
@onready var exit_area  : Area2D       = $Exit
@onready var hint_popup : PopupPanel   = $ExitUI
@onready var Inv := InventoryData

var _player_inside_exit := false


#==============================================================================#
#  ИНИЦИАЛИЗАЦИЯ
#==============================================================================#
func _ready() -> void:
	randomize()
	if world_tiles:
		tilemap.tile_set = world_tiles

	# 1 — генератор
	_setup_generator()

	# 2 — заполняем мир тайлами + чёрной рамкой
	_fill_world()

	# 3 — площадка спавна и игрок
	_position_player_and_exit()

	# 4 — стартовый предмет в инвентаре
	Inv.add_item(load("res://items/wooden_pickaxe.tres"), 1)

	# 5 — сигналы
	$Player/Player.player_died.connect(_on_player_died)
	hint_popup.hide()
	$HUD/Inventory.refresh()


#------------------------------------------------------------------------------#
#  НАСТРОЙКА ГЕНЕРАТОРА
#------------------------------------------------------------------------------#
func _setup_generator() -> void:
	generator.setup({
		"world_height": world_height,
		"surface_base": -10,          # «поверхности» нет — только пещеры
		"surface_amp": 0,
		"surface_amp_desert": 0,
		"surface_amp_mountain": 0,
		"dirt_depth": 10,
		"sand_depth": 10,
		"sea_level": -1000,
		"beach_width": 0,
		"cave_threshold": cave_threshold,
		"cave_threshold_depth_factor": cave_threshold_depth_factor,
		"ore_chances": ore_chances,
		"SOURCE_ID": SOURCE_ID,
	})


#------------------------------------------------------------------------------#
#  ЗАПОЛНЯЕМ ТАЙЛЫ + ДОБАВЛЯЕМ ЧЁРНУЮ «ОБЛАСТЬ-ЗАПРЕТКУ»
#------------------------------------------------------------------------------#
func _fill_world() -> void:
	var patt := generator.create_chunk_pattern(0, world_width)
	tilemap.set_pattern(Vector2i.ZERO, patt)

	# Толщина черной границы
	var border_thickness := 3

	for x in range(world_width):
		for y in range(world_height):
			var near_edge := x < border_thickness or x >= world_width - border_thickness \
						  or y < border_thickness or y >= world_height - border_thickness
			if near_edge:
				tilemap.set_cell(Vector2i(x, y), VOID_SOURCE_ID, Vector2i.ZERO, 0)



#------------------------------------------------------------------------------#
#  СПАВН ИГРОКА + ВЫХОД
#------------------------------------------------------------------------------#
func _position_player_and_exit() -> void:
	var cx := world_width  / 2
	var cy := world_height / 2
	var spawn_tile := Vector2i(cx, cy)

	# очищаем 5 × 5 под ногами
	for dx in range(-2, 3):
		for dy in range(-2, 2):
			tilemap.erase_cell(spawn_tile + Vector2i(dx, dy))
		for dy in range(2, 3):
			var cell := spawn_tile + Vector2i(dx, dy)
			tilemap.set_cell(cell, VOID_SOURCE_ID, Vector2i.ZERO, 0)

	# координаты в пикселях
	var ts := tilemap.tile_set.tile_size
	var spawn_pos := Vector2(spawn_tile.x * ts.x, spawn_tile.y * ts.y)

	# игрок
	if player.has_method("set_spawn_position"):
		player.set_spawn_position(spawn_pos)
	else:
		player.global_position = spawn_pos

	# и там-же выход
	exit_area.position = spawn_pos


#==============================================================================#
#  ВЫХОД – СИГНАЛЫ И КНОПКА
#==============================================================================#
func _on_exit_body_entered(body: Node2D) -> void:
	if body == player:
		hint_popup.popup()
		_player_inside_exit = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body == player:
		hint_popup.hide()
		_player_inside_exit = false


func _process(_delta: float) -> void:
	if _player_inside_exit and Input.is_action_just_pressed("interact"):
		# ⬇ автосохранение перед сменой сцены, чтобы добытая руда не потерялась
		SaveManager.save_game(SaveManager.current_slot)
		TransitionManager.change_scene("res://scenes/Levels/mining.tscn")


#==============================================================================#
#  ПРОЧЕЕ
#==============================================================================#
func _on_player_died() -> void:
	await get_tree().create_timer(2).timeout
	get_tree().reload_current_scene()


#==============================================================================#
#  API ДЛЯ БЛОКОВ
#==============================================================================#
func remove_block(cell: Vector2i) -> int:
	var sid := tilemap.get_cell_source_id(cell)
	if sid == -1 or sid == VOID_SOURCE_ID:
		return -1
	tilemap.erase_cell(cell)
	for t in SOURCE_ID:
		if SOURCE_ID[t] == sid:
			return t
	return -1


func place_block(cell: Vector2i, terrain_id: int) -> void:
	if SOURCE_ID.has(terrain_id):
		tilemap.set_cell(cell, SOURCE_ID[terrain_id], Vector2i.ZERO, 0)


func position_to_cell(global_pos: Vector2) -> Vector2i:
	var local := tilemap.to_local(global_pos)
	var ts := tilemap.tile_set.tile_size
	return Vector2i(floor(local.x / ts.x), floor(local.y / ts.y))
