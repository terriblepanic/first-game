# KingNPC.gd — вешайте на Node2D, указывайте area_path и popup_path в инспекторе
extends Node2D

@export var area_path  : NodePath
@export var popup_path : NodePath
@export var npc_id     : String = "king"
@export var flip_sprite: bool = false

@onready var area       : Area2D     = get_node(area_path)
@onready var hint_popup : PopupPanel = get_node(popup_path)
@onready var sprite     : AnimatedSprite2D = $AnimatedSprite2D
@onready var dlg_ui     : DialogueUI = preload("res://scenes/DialogueUI.tscn").instantiate()

var _player_inside : bool = false
	
func _ready() -> void:
	sprite.play()
	sprite.flip_h = flip_sprite
	set_process(true)
	set_process_unhandled_input(true)

	get_tree().root.call_deferred("add_child", dlg_ui)
	dlg_ui.dialogue_closed.connect(_on_dialogue_closed)

	if not area.is_connected("body_entered", Callable(self, "_on_body_entered")):
		area.body_entered.connect(_on_body_entered)
	if not area.is_connected("body_exited", Callable(self, "_on_body_exited")):
		area.body_exited.connect(_on_body_exited)

	hint_popup.hide()

func _on_body_entered(body:Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		hint_popup.popup()

		# достаём Panel и ставим "игнор"
		var panel = hint_popup.get_child(0) as Control
		if panel:
			panel.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_body_exited(body:Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		hint_popup.hide()

func _process(_delta:float) -> void:
	if _player_inside and Input.is_action_just_pressed("interact"):
		_start_dialogue()

func _start_dialogue() -> void:
	_player_inside = false
	hint_popup.hide()

	var speaker_name := DialogueMgr.get_npc_name(npc_id)
	var raw   : String            = DialogueMgr.get_line(npc_id)
	var lines : PackedStringArray = raw.split("\n")
	dlg_ui.show_dialogue(speaker_name, lines)

func _on_dialogue_closed() -> void:
	if area.get_overlapping_bodies().any(func(b): return b.is_in_group("player")):
		_player_inside = true
		hint_popup.popup()
