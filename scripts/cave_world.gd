# cave_world.gd
# ------------------------------------------------------------------------------
# Пещерный уровень - ставит вокруг «нережибельной» зоны чёрный тайл-пустоту
# ------------------------------------------------------------------------------
extends Node

@export_file("*.tscn") var to_mine := "res://scenes/Levels/mining.tscn"

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
@onready var exit_area  : Area2D       = $SpawnMarkers/CenterExit
@onready var Inv := InventoryData

@onready var hint_popup: PopupPanel = $ExitUI
@onready var player = $Player/Player
@onready var player_sprite = $Player/Player/AnimatedSprite2D
@onready var spawn_points = {
	"center": $SpawnMarkers/Center,
}

var player_inside = false
var is_spawning = true

#==============================================================================#
#  ИНИЦИАЛИЗАЦИЯ
#==============================================================================#
func _ready() -> void:
	randomize()
	if world_tiles:
		tilemap.tile_set = world_tiles

	_setup_generator()
	_fill_world()
	_position_player_and_exit()
	Inv.add_item(load("res://items/wooden_pickaxe.tres"), 1)

	$Player/Player.player_died.connect(_on_player_died)
	$HUD/Inventory.refresh()

	hint_popup.hide()
	_setup_spawn()   # <<< плавное появление


func _setup_spawn():
	var entry_dir = Global.last_exit_direction if "last_exit_direction" in Global else "center"
	var spawn_point = spawn_points.center
	var offset = Vector2(100, 0)
	var flip_h = true
	
	if entry_dir == "center":
		spawn_point = spawn_points.center
		offset = Vector2(0, -50) 
		flip_h = true
	
	match entry_dir:
		"left":
			spawn_point = spawn_points.right
			flip_h = true
		"right":
			spawn_point = spawn_points.left
			flip_h = false
	
	player.position = spawn_point.position + (offset * (-1 if entry_dir == "right" else 1))
	player.set_physics_process(false)
	player_sprite.play("walking")
	player_sprite.flip_h = flip_h
	
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(player, "position", spawn_point.position, 1.0)
	tween.tween_callback(_enable_player)

func _enable_player() -> void:
	player.set_physics_process(true)
	player_sprite.stop()
	is_spawning = false
	_check_exit_overlap()          # <<< новая строка

func _check_exit_overlap() -> void:    # <<< новая функция
	if exit_area.get_overlapping_bodies().has(player):
		player_inside = true
		hint_popup.popup()
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
	var cx := world_width / 2
	var cy := world_height / 2
	var spawn_tile := Vector2i(cx, cy)

	# очищаем 5×5 под площадку
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var cell := spawn_tile + Vector2i(dx, dy)
			if dy < 2:
				tilemap.erase_cell(cell)
			else:
				tilemap.set_cell(cell, VOID_SOURCE_ID, Vector2i.ZERO, 0)

	# перевод в пиксели
	var ts := tilemap.tile_set.tile_size
	var spawn_pos := Vector2(spawn_tile.x * ts.x, spawn_tile.y * ts.y)

	# переносим МАРКЕР (а не игрока)
	spawn_points.center.position = spawn_pos
	exit_area.position = spawn_pos



#==============================================================================#
#  ВЫХОД – СИГНАЛЫ И КНОПКА
#==============================================================================#
func _on_exit_body_entered(body: Node2D) -> void:
	if body.name == "Player" and not is_spawning:
		hint_popup.popup()
		player_inside = true


func _on_exit_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		hint_popup.hide()
		player_inside = false


func _process(_delta: float) -> void:
	if player_inside and Input.is_action_just_pressed("interact") and not is_spawning:
		# ⬇ автосохранение перед сменой сцены, чтобы добытая руда не потерялась
		SaveManager.save_game(SaveManager.current_slot)
		Global.last_exit_direction = "center"
		TransitionManager.change_scene(to_mine)


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
