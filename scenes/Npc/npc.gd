extends Node2D
class_name NPCController
## --------------------------------------------------
##  • всплывающая подсказка «E»
##  • запуск диалога через DialogueMgr / DialogueUI
##  • интеграция с QuestMgr через QuestCatalog
## --------------------------------------------------

# ---------- Editor exports ----------
@export var area_path  : NodePath
@export var popup_path : NodePath
@export var npc_id     : String      = "king"
@export var flip_sprite: bool        = false

# ---------- onready ----------
@onready var area_detector : Area2D           = get_node(area_path)
@onready var hint_popup    : PopupPanel       = get_node(popup_path)
@onready var sprite        : AnimatedSprite2D = $AnimatedSprite2D
@onready var dialogue_ui   : DialogueUI       = preload("res://scenes/DialogueUI.tscn").instantiate()

var _player_inside := false        # стоит ли игрок в зоне

# ---------- КТО КАКИЕ КВЕСТЫ ОБСЛУЖИВАЕТ ----------
# порядок в массиве = порядок цепочки (первый выдаём, потом сдаём, переходим ко второму…)
const NPC_QUEST_CHAIN : Dictionary = {
	"guildmaster": ["guild_copper"]    # добавляй ещё id по мере роста цепочки
	# "blacksmith": ["forge_sword", "sharpen_blade"],
}

# ==================================================
#  READY
# ==================================================
func _ready() -> void:
	sprite.play()
	sprite.flip_h = flip_sprite

	get_tree().root.call_deferred("add_child", dialogue_ui)
	dialogue_ui.dialogue_closed.connect(_on_dialogue_closed)

	area_detector.body_entered.connect(_on_body_entered)
	area_detector.body_exited .connect(_on_body_exited)

	hint_popup.hide()

# ==================================================
#  TRIGGER ZONE
# ==================================================
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = true
		_show_popup()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_inside = false
		hint_popup.hide()

# ==================================================
#  PROCESS
# ==================================================
func _process(_delta: float) -> void:
	if _player_inside and Input.is_action_just_pressed("interact"):
		_start_dialogue()

# ==================================================
#  DIALOGUE
# ==================================================
func _start_dialogue() -> void:
	_player_inside = false
	hint_popup.hide()

	var speaker := DialogueMgr.get_npc_name(npc_id)
	var lines   := DialogueMgr.get_line(npc_id).split("\n")
	dialogue_ui.show_dialogue(speaker, lines)

func _on_dialogue_closed() -> void:
	_handle_quests_for_npc()

	# если игрок всё ещё рядом — снова показать подсказку
	if area_detector.get_overlapping_bodies().any(func(b): return b.is_in_group("player")):
		_player_inside = true
		_show_popup()

# ==================================================
#  QUEST LOGIC (generic)
# ==================================================
func _handle_quests_for_npc() -> void:
	if !NPC_QUEST_CHAIN.has(npc_id):
		return                             # этот NPC не связан с квестами

	for quest_id in NPC_QUEST_CHAIN[npc_id]:
		# 1) ещё не получен -> выдаём
		if !QuestMgr.has_quest(quest_id):
			var q := QuestCatalog.get_quest(quest_id)
			QuestMgr.add_quest(quest_id, q.title, q.need, q.reward, QuestMgr.State.ACTIVE)
			GameState.set_flag("hero_joined_guild")        # пример: можешь заменить/убрать
			return
		# 2) готов к сдаче -> принимаем
		elif QuestMgr.ready_to_complete(quest_id):
			QuestMgr.complete_quest(quest_id)
			GameState.set_flag("guild_quest_completed")    # пример: можешь заменить/убрать
			return
		# 3) иначе: либо уже выполнен, либо ещё собирается — проверяем следующий

# ==================================================
#  UI HELPERS
# ==================================================
func _show_popup() -> void:
	hint_popup.popup()
	var panel := hint_popup.get_child(0) as Control
	if panel:
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
