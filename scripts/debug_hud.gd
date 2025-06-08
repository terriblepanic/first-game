extends Label

@onready var world_map := get_node("/root/Main")
@onready var player := world_map.get_node("Player")
@onready var enemy := world_map.get_node("Enemy")
@onready var tilemap := world_map.get_node("WorldMap")
@onready var generator: WorldGenerator = world_map.generator

var debug_visible: bool = false

func _input(event):
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_visible = !debug_visible
		visible = debug_visible

func _process(_delta):
	if not debug_visible:
		return

	var W: int = world_map.world_width
	var H: int = world_map.world_height

	var top_left: Vector2i = Vector2i(0, 0)
	var top_right: Vector2i = Vector2i(W - 1, 0)
	var bottom_left: Vector2i = Vector2i(0, H - 1)
	var bottom_right: Vector2i = Vector2i(W - 1, H - 1)

	var player_tile: Vector2i = world_map.position_to_cell(player.global_position)
	var enemy_tile: Vector2i = world_map.position_to_cell(enemy.global_position)

	# Получаем биом по X-позиции игрока
	var biome_name := "?"
	if generator:
		biome_name = generator.get_biome(player_tile.x)

	var camera := get_viewport().get_camera_2d()
	var visible_tiles_x := 0
	if camera:
		var screen_size_world: Vector2 = get_viewport_rect().size * camera.zoom
		var top_left_tile: Vector2i = world_map.position_to_cell(camera.get_screen_center_position() - screen_size_world / 2)
		var bottom_right_tile: Vector2i = world_map.position_to_cell(camera.get_screen_center_position() + screen_size_world / 2)

		var terrain_map: Dictionary = world_map.SOURCE_ID
		var air_id: int = int(terrain_map[world_map.TerrainID.AIR])

		for x in range(top_left_tile.x, bottom_right_tile.x):
			for y in range(top_left_tile.y, bottom_right_tile.y):
				var tile: int = tilemap.get_cell_source_id(Vector2i(x, y))
				if tile != air_id and tile != -1:
					visible_tiles_x += 1

	var fps: int = round(Engine.get_frames_per_second())

	var world_mouse: Vector2 = tilemap.get_global_mouse_position()
	var cursor_tile: Vector2i = world_map.position_to_cell(world_mouse)

	text = ""
	text += "🌍 Мир (тайлов):         %d × %d\n" % [W, H]
	text += "🔼 Верх левый тайл:      %s\n" % str(top_left)
	text += "🔼 Верх правый тайл:     %s\n" % str(top_right)
	text += "🔽 Низ левый тайл:       %s\n" % str(bottom_left)
	text += "🔽 Низ правый тайл:      %s\n" % str(bottom_right)
	text += "👤 Игрок (тайл):         %s\n" % str(player_tile)
	text += "🏞 Биом игрока:          %s\n" % biome_name
	text += "👾 Враг (тайл):          %s\n" % str(enemy_tile)
	text += "📦 Загружено чанков:     %d\n" % world_map._loaded_chunks.size()
	text += "🧱 Видимые тайлы:        %d\n" % visible_tiles_x
	text += "🚀 FPS:                  %d\n" % fps
	text += "🖱 Курсор (тайл):        %s" % str(cursor_tile)
