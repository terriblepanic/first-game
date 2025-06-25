extends Node2D

@onready var _altar_scene: PackedScene = preload("res://scenes/altar.tscn")

const VIDEO_PATH = "res://media/splash.ogv"

var _chosen: Dictionary = {}

@onready var _animated_sprite = $Fire
@onready var hint_popup: PopupPanel = $AltarUI

func _ready() -> void:
	hint_popup.hide()
	process_mode = Node.PROCESS_MODE_PAUSABLE
	show_splash()

# ---------- ЗАСТАВКА ----------
func show_splash() -> void:
	get_tree().paused = true                # ставим игру на паузу

	var splash_layer := CanvasLayer.new()
	splash_layer.name = "SplashLayer"
	splash_layer.layer = 100
	splash_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(splash_layer)

	# тёмный фон
	var bg := ColorRect.new()
	bg.color = Color.BLACK                  # исправили
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.process_mode = Node.PROCESS_MODE_ALWAYS
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	splash_layer.add_child(bg)

	# видеоплеер
	var vp := VideoStreamPlayer.new()       # <-- новый класс
	vp.name = "SplashVideo"
	vp.stream = load(VIDEO_PATH)
	vp.expand = true
	vp.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.autoplay = false
	vp.process_mode = Node.PROCESS_MODE_ALWAYS
	splash_layer.add_child(vp)

	# сигналы
	vp.play()
	vp.finished.connect(_on_splash_finished)
	bg.gui_input.connect(_on_splash_input)
	

func _on_splash_finished() -> void:
	var layer := get_node_or_null("SplashLayer")
	if layer: layer.queue_free()
	get_tree().paused = false               # снимаем паузу
	_spawn_altars()                         # запускаем логику уровня

func _on_splash_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var vp := get_node_or_null("SplashLayer/SplashVideo") as VideoStreamPlayer
		if vp and vp.playing:
			vp.stop()
			_on_splash_finished()

func _process(delta: float) -> void:
	_animated_sprite.play("fire")


func _spawn_altars() -> void:
	var hud := get_node_or_null("HUD")

	var altar1: GodAltar = _altar_scene.instantiate()
	altar1.position = Vector2(-72, 64)
	altar1.god_name = "GodA"
	altar1.blessings = ["Сила", "Защита"]
	add_child(altar1)

	altar1.connect(
		"player_near",
		Callable(self, "_on_altar_player_near").bind(altar1)
	)
	altar1.connect(
		"player_far",
		Callable(self, "_on_altar_player_far")
	)
	
	altar1.blessing_selected.connect(_on_blessing_selected)
	if hud:
		altar1.blessing_selected.connect(hud.update_blessings_list)

	var altar2: GodAltar = _altar_scene.instantiate()
	altar2.position = Vector2(72, 64)
	altar2.god_name = "GodB"
	altar2.blessings = ["Мудрость", "Удача"]
	add_child(altar2)
		
	altar2.connect(
		"player_near",
		Callable(self, "_on_altar_player_near").bind(altar2)
	)
	altar2.connect(
		"player_far",
		Callable(self, "_on_altar_player_far")
	)

	altar2.blessing_selected.connect(_on_blessing_selected)
	if hud:
		altar2.blessing_selected.connect(hud.update_blessings_list)


func _on_blessing_selected(god: String, blessing: String) -> void:
	_chosen[god] = blessing
	if _chosen.size() >= 2:
		TransitionManager.change_scene("res://scenes/Levels/kingdom_king.tscn")

func _on_altar_player_near(altar: GodAltar) -> void:
	# можно сместить подсказку над алтарём
	hint_popup.popup()

func _on_altar_player_far() -> void:
	hint_popup.hide()
