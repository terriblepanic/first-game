extends Label

var debug_visible: bool = false

var world_map: Node = null
var player: Node = null
var enemy: Node = null
var tilemap: Node = null  # TileMapLayer
var generator: Object = null

func _ready() -> void:
	world_map = get_node_or_null("/root/Main")
	if world_map:
		player = get_node_or_null("/root/Main/Player/Player")
		enemy = get_node_or_null("/root/Main/Enemy/Enemy")
		tilemap = world_map.get_node_or_null("WorldMap")  # TileMapLayer напрямую
		if "generator" in world_map:
			generator = world_map.generator
	visible = false

func _process(_delta: float) -> void:
	if not debug_visible \
	or world_map == null \
	or player == null \
	or enemy == null \
	or tilemap == null:
		return

	var W = world_map.world_width
	var H = world_map.world_height

	var top_left = Vector2i(0, 0)
	var top_right = Vector2i(W - 1, 0)
	var bottom_left = Vector2i(0, H - 1)
	var bottom_right = Vector2i(W - 1, H - 1)
	var player_tile = world_map.position_to_cell(player.global_position)
	var enemy_tile = world_map.position_to_cell(enemy.global_position)

	var biome_name := "?"
	if generator and generator.has_method("get_biome"):
		biome_name = generator.get_biome(player_tile.x)

	var loaded_chunks = []
	if "_loaded_chunks" in world_map:
		loaded_chunks = world_map._loaded_chunks
	var loaded_chunks_count = loaded_chunks.size()

	var camera = get_viewport().get_camera_2d()
	var visible_tiles_x = 0
	if camera:
		var screen_world = get_viewport_rect().size * camera.zoom
		var tl = world_map.position_to_cell(camera.get_screen_center_position() - screen_world / 2)
		var br = world_map.position_to_cell(camera.get_screen_center_position() + screen_world / 2)
		var terrain_map = world_map.SOURCE_ID
		var air_id = int(terrain_map[world_map.TerrainID.AIR])

		for x in range(tl.x, br.x):
			for y in range(tl.y, br.y):
				# ✅ TileMapLayer напрямую:
				var t = tilemap.get_cell_source_id(Vector2i(x, y))
				if t != air_id and t != -1:
					visible_tiles_x += 1

	var fps = int(round(Engine.get_frames_per_second()))
	var world_mouse = tilemap.get_global_mouse_position()
	var cursor_tile = world_map.position_to_cell(world_mouse)

	text = ""
	text += "🌍 Мир (тайлов):         %d × %d\n" % [W, H]
	text += "🔼 Верх левый тайл:      %s\n" % str(top_left)
	text += "🔼 Верх правый тайл:     %s\n" % str(top_right)
	text += "🔽 Низ левый тайл:       %s\n" % str(bottom_left)
	text += "🔽 Низ правый тайл:      %s\n" % str(bottom_right)
	text += "👤 Игрок (тайл):         %s\n" % str(player_tile)
	text += "🏞 Биом игрока:          %s\n" % biome_name
	text += "👾 Враг (тайл):          %s\n" % str(enemy_tile)
	text += "📦 Загружено чанков:     %d\n" % loaded_chunks_count
	text += "🧱 Видимые тайлы:        %d\n" % visible_tiles_x
	text += "🚀 FPS:                  %d\n" % fps
	text += "🖱 Курсор (тайл):        %s" % str(cursor_tile)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F3:
		debug_visible = not debug_visible
		visible = debug_visible
