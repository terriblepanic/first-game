# DialogueUI.gd
extends CanvasLayer
class_name DialogueUI

signal dialogue_closed

@export var name_label_path : NodePath
@export var text_label_path : NodePath

@onready var name_label : Label          = get_node(name_label_path)
@onready var text_label : RichTextLabel  = get_node(text_label_path)
@onready var anim       : AnimationPlayer = $AnimationPlayer

const CHAR_SPEED : float = 0.02

var _lines    : PackedStringArray = []
var _line_idx : int               = 0
var _progress : float             = 0.0
var _typing   : bool              = false

func show_dialogue(speaker:String, lines_in:PackedStringArray) -> void:
	if lines_in.is_empty():
		return

	name_label.text = speaker
	_lines          = lines_in
	_line_idx       = 0
	_setup_current_line()

	visible = true
	anim.play("slide_in")
	set_process(true)

func _setup_current_line() -> void:
	text_label.clear()
	_progress = 0.0
	_typing   = true

	text_label.modulate.a = 0.0
	create_tween()\
		.tween_property(text_label, "modulate:a", 1.0, 0.25)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _process(delta:float) -> void:
	if not _typing:
		return

	_progress += delta / CHAR_SPEED
	var full_text : String = _lines[_line_idx]
	var cut_len   : int    = clampi(int(_progress), 0, full_text.length())

	text_label.text = full_text.substr(0, cut_len)

	if cut_len >= full_text.length():
		_typing = false

func _unhandled_input(event:InputEvent) -> void:
	if not visible or not event.is_action_pressed("interact"):
		return

	if _typing:
		text_label.text = _lines[_line_idx]
		_typing = false
	else:
		_line_idx += 1
		if _line_idx < _lines.size():
			_setup_current_line()
		else:
			_end_dialogue()

func _end_dialogue() -> void:
	anim.play("slide_out")
	set_process(false)

func _on_AnimationPlayer_animation_finished(anim_name:String) -> void:
	if anim_name == "slide_out":
		visible = false
		emit_signal("dialogue_closed")
