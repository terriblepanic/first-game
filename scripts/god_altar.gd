extends Area2D
class_name GodAltar
## --------------------------------------------------
##  Алтарь: фикс-широкое окно + авто-прокрутка описания
## --------------------------------------------------

signal blessing_selected(god: String, blessing: String)
signal player_near
signal player_far

@export var god_name: String = "God"
@export var blessings: Array[String] = [
	"Благословение прилива",
	"Глубинный покой",
	"Пылающий клинок",
	"Фениксовое пламя"
]
@export var blessing_descriptions: Dictionary = {
	"Благословение прилива": "Заклинания становятся волнами разрушения.",
	"Глубинный покой":       "Мана возвращается, как прилив после отлива.",
	"Пылающий клинок":       "Клинок алчет новых ожогов на врагах.",
	"Фениксовое пламя":      "Даже смерть отступает перед твоим жаром."
}

@onready var area         : Area2D        = $DetectionArea
@onready var menu         : PopupPanel    = $BlessingMenu
@onready var title_label  : Label         = $BlessingMenu/VBoxContainer/HBoxContainer/Mask/Label
@onready var close_button : Button        = $BlessingMenu/VBoxContainer/HBoxContainer/Button
@onready var buttons_box  : VBoxContainer = $BlessingMenu/VBoxContainer/ButtonsVBox

const MASK_WIDTH := 228
const SCROLL_SPEED := 30.0

var _base_pos      : Vector2
var _tween         : Tween = null
var _initial_title : String
var _was_paused    : bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED

	area.body_entered.connect(_on_body_enter)
	area.body_exited.connect(_on_body_exit)
	close_button.pressed.connect(_close_menu)

	title_label.custom_minimum_size.x = MASK_WIDTH
	_base_pos = title_label.position
	_initial_title = title_label.text

func interact(_player: Node) -> void:
	_open_menu()

func _open_menu() -> void:
	_reset_title()
	for c in buttons_box.get_children():
		c.queue_free()

	for b_name in blessings:
		var btn := Button.new()
		btn.text = b_name
		if BlessingManager.get_blessing(god_name) == b_name:
			btn.text += " (выбрано)"
			btn.disabled = true

		var desc: String = blessing_descriptions.get(b_name, "")
		btn.mouse_entered.connect(_show_desc.bind(desc))
		btn.mouse_exited.connect(_reset_title)
		btn.pressed.connect(_choose.bind(b_name))

		buttons_box.add_child(btn)

	_was_paused = get_tree().paused
	get_tree().paused = true
	menu.popup_centered()

func _choose(blessing: String) -> void:
	_close_menu()
	BlessingManager.set_blessing(god_name, blessing)
	emit_signal("blessing_selected", god_name, blessing)

func _show_desc(desc: String) -> void:
	title_label.text = desc
	_start_scroll_if_needed()

func _reset_title() -> void:
	title_label.text = _initial_title
	_cancel_scroll()

func _start_scroll_if_needed() -> void:
	_cancel_scroll()

	var font := title_label.get_theme_font("font")
	var text := title_label.text
	var text_width := font.get_string_size(text).x
	var overflow := text_width - MASK_WIDTH
	if overflow <= 0:
		return

	var duration := overflow / SCROLL_SPEED
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.set_loops()

	_tween.tween_property(title_label, "position:x", _base_pos.x - overflow, duration)
	_tween.tween_property(title_label, "position:x", _base_pos.x, duration)

func _cancel_scroll() -> void:
	if _tween:
		_tween.kill()
		_tween = null
	title_label.position = _base_pos

func _close_menu() -> void:
	menu.hide()
	get_tree().paused = _was_paused
	_cancel_scroll()

func _on_body_enter(body: Node) -> void:
	if body.is_in_group("player"):
		emit_signal("player_near")

func _on_body_exit(body: Node) -> void:
	if body.is_in_group("player"):
		emit_signal("player_far")

func _input(e: InputEvent) -> void:
	if menu.visible and (
		e.is_action_pressed("exit")
		or (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
		and not menu.get_global_rect().has_point(e.global_position))
	):
		_close_menu()
