extends Node2D
class_name NPCController
## --------------------------------------------------
##  всплывающая подсказка «E» • диалоги • цепочка квестов
## --------------------------------------------------

@export var area_path  : NodePath
@export var popup_path : NodePath
@export var npc_id     : String = "king"
@export var flip_sprite: bool   = false

@onready var area_detector : Area2D           = get_node(area_path)
@onready var hint_popup    : PopupPanel       = get_node(popup_path)
@onready var sprite        : AnimatedSprite2D = $AnimatedSprite2D
@onready var dialogue_ui   : DialogueUI       = preload("res://scenes/DialogueUI.tscn").instantiate()

var _player_inside := false

# порядок = порядок выполнения
const NPC_QUEST_CHAIN := {
	"guildmaster": [
		"guild_copper",
		"guild_stone",
		"guild_iron"
	]
}

# --------------------------------------------------
func _ready() -> void:
	sprite.play()
	sprite.flip_h = flip_sprite
	get_tree().root.call_deferred("add_child", dialogue_ui)
	dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)
	area_detector.body_entered.connect(_on_body_entered)
	area_detector.body_exited .connect(_on_body_exited)
	hint_popup.hide()

# ---------- зона ----------
func _on_body_entered(b): if b.is_in_group("player"): _player_inside = true;  _show_popup()
func _on_body_exited(b) : if b.is_in_group("player"): _player_inside = false; hint_popup.hide()

# ---------- процесс ----------
func _process(_d): if _player_inside and Input.is_action_just_pressed("interact"): _start_dialogue()

# --------------------------------------------------
#  ОСНОВНАЯ БЕСЕДА
# --------------------------------------------------
func _start_dialogue() -> void:
	_player_inside = false
	hint_popup.hide()

	_resolve_quests()                                   # ← сначала логика

	var speaker := DialogueMgr.get_npc_name(npc_id)
	var lines   := DialogueMgr.get_line(npc_id).split("\n")
	dialogue_ui.show_dialogue(speaker, lines)

func _on_dialogue_closed() -> void:
	if area_detector.get_overlapping_bodies().any(func(b): return b.is_in_group("player")):
		_player_inside = true
		_show_popup()

# --------------------------------------------------
#  РЕШЕНИЕ КВЕСТОВ (до диалога!)
# --------------------------------------------------
func _resolve_quests() -> void:
	if !NPC_QUEST_CHAIN.has(npc_id):
		return

	var chain : Array = NPC_QUEST_CHAIN[npc_id]
	var active : String = ""
	var ready  : String = ""
	var next   : String = ""

	for qid in chain:
		if QuestMgr.has_quest(qid):
			if QuestMgr.is_completed(qid): continue
			active = qid
			if QuestMgr.ready_to_complete(qid):
				ready = qid
			break
		else:
			next = qid
			break

	# ----- сдача -----
	if ready != "":
		QuestMgr.complete_quest(ready)                       # награда сразу
		GameState.set_flag("%s_completed" % ready)           # напр. guild_stone_completed
		return                                               # новая задача – в след. визит

	# ----- выдача -----
	if active == "" and next != "":
		var q := QuestCatalog.get_quest(next)
		QuestMgr.add_quest(next, q.title, q.need, q.reward, QuestMgr.State.ACTIVE)
		GameState.set_flag("%s_taken" % next)                # guild_stone_taken

# --------------------------------------------------
func _show_popup():
	hint_popup.popup()
	var panel := hint_popup.get_child(0) as Control
	if panel: panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
