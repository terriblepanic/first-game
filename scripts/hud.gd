extends CanvasLayer

## --------------------------------------------------
##  UI-контроллер верхнего уровня
##  Занимается: орбами HP/MP, инвентарной панелью,
##  вкладкой «Задания гильдии» и её автоперерисовкой
## --------------------------------------------------

# ---------- preload ----------
const OrbUIController = preload("res://scripts/OrbUIController.gd")
const Inventory = preload("res://scripts/inventory.gd")
const QuestEntryScene = preload("res://ui/QuestEntry.tscn") # prefab одной строки квеста

# ---------- ORBS ----------
var hp_orb: OrbUIController
var mp_orb: OrbUIController

@onready var orb_hp_sprite: Sprite2D = $HUD/OrbHP/Sprite2D
@onready var orb_mp_sprite: Sprite2D = $HUD/OrbMP/Sprite2D
# ---------- HUD / INVENTORY ----------
@onready var hud_root: Control = $HUD
@onready var inventory_panel: Control = hud_root.get_node("InventoryPanel") as Control
@onready var tabs_container: TabContainer = inventory_panel.get_node("InfoTabs") as TabContainer
@onready var inventory_grid: GridContainer = hud_root.get_node("InventoryPanel/InfoTabs/Снаряжение/CenterContainer/InventoryGrid") as GridContainer
@onready var inventory_ui: Inventory = $Inventory
@onready var blessings_list: ItemList = hud_root.get_node("InventoryPanel/InfoTabs/Характеристики/BlessingsList") as ItemList
# ---------- QUESTS UI ----------
#   «Задания гильдии» → ScrollContainer → VBoxContainer
@onready var quests_container: VBoxContainer = hud_root.get_node(
	"InventoryPanel/InfoTabs/Задания гильдии/QuestsList/VBoxContainer") as VBoxContainer
# ---------- OTHER ----------
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")


# ==================================================
#  ORB INITIALISATION
# ==================================================
func _init_orbs() -> void:
	# --- HP ORB ---
	var hp_mat: ShaderMaterial = orb_hp_sprite.material.duplicate()
	orb_hp_sprite.material = hp_mat
	hp_orb = OrbUIController.new()
	hp_orb.SetOwner(self)
	hp_orb.SetShader(hp_mat)
	hp_orb.ball_color = Color.WHITE
	hp_orb.alert_ball_color = Color(1, 0.3, 0.1)
	hp_orb.Reset()
	hp_mat.set_shader_parameter("water_color", Color(1, 0.3, 0.3))
	hp_mat.set_shader_parameter("transparent_empty", true)

	# --- MP ORB ---
	var mp_mat: ShaderMaterial = orb_mp_sprite.material.duplicate()
	orb_mp_sprite.material = mp_mat
	mp_orb = OrbUIController.new()
	mp_orb.SetOwner(self)
	mp_orb.SetShader(mp_mat)
	mp_orb.ball_color = Color.WHITE
	mp_orb.alert_ball_color = Color(0.2, 0.2, 1)
	mp_orb.Reset()
	mp_orb.SetDeathStateEnabled(false)
	mp_mat.set_shader_parameter("water_color", Color(0.2, 0.5, 1))
	mp_mat.set_shader_parameter("transparent_empty", true)


# ==================================================
#  READY
# ==================================================
func _ready() -> void:
	_init_orbs()
	_connect_player_signals()
	_connect_inventory_signals()
	_connect_quest_signals()

	inventory_panel.visible = false # скрываем стартовую панель

	BlessingManager.blessing_changed.connect(_update_blessings_list)
	_update_blessings_list()


# ==================================================
#  PROCESS
# ==================================================
func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_inventory"):
		inventory_panel.visible = !inventory_panel.visible
		if inventory_panel.visible:
			tabs_container.current_tab = 1 # «Снаряжение» по умолчанию
			inventory_ui.refresh()
			_update_blessings_list()
			_refresh_quests() # нарисовать список квестов


# ==================================================
#  SIGNAL SUBSCRIPTIONS
# ==================================================
func _connect_player_signals() -> void:
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("mana_changed"):
			player.mana_changed.connect(_on_player_mana_changed)
		_on_player_health_changed(player.health, player.max_health)
		_on_player_mana_changed(player.mana, player.max_mana)


func _connect_inventory_signals() -> void:
	inventory_ui.inventory_changed.connect(_on_inventory_changed)


func _connect_quest_signals() -> void:
	QuestMgr.quest_added.connect(_on_quest_event) # (id)
	QuestMgr.quest_state_changed.connect(_on_quest_event) # (id, new_state)
	QuestMgr.quest_completed.connect(_on_quest_event) # (id)


# ==================================================
#  BLESSINGS TAB
# ==================================================
func _update_blessings_list(selected_god: String = "", selected_blessing: String = "") -> void:
	blessings_list.clear()
	for god_key in BlessingManager.blessings.keys():
		var bless = BlessingManager.blessings[god_key]
		var text = "%s: %s" % [god_key, bless]
		if god_key == selected_god and bless == selected_blessing:
			text += " (выбрано)"
		blessings_list.add_item(text)


# ==================================================
#  ORBS CALLBACKS
# ==================================================
func _on_player_health_changed(value: int, max_value: int) -> void:
	var previous_hp := hp_orb.H * max_value
	if value < previous_hp:
		hp_orb.GetHit(value, previous_hp, max_value)
	else:
		hp_orb.SetSmooth(value, max_value)


func _on_player_mana_changed(value: int, max_value: int) -> void:
	var previous_mp := mp_orb.H * max_value
	if value < previous_mp:
		mp_orb.GetHit(value, previous_mp, max_value)
	else:
		mp_orb.SetSmooth(value, max_value)


# ==================================================
#  INVENTORY CALLBACK
# ==================================================
func _on_inventory_changed() -> void:
	if inventory_panel.visible:
		inventory_ui.refresh()
		_refresh_quests() # нужно, чтобы проценты прогресса квестов обновились


# ==================================================
#  QUESTS TAB
# ==================================================
func _on_quest_event(_id: String, _state := 0) -> void:
	# любое событие квеста → перерисовываем список,
	# но только если вкладка открыта (лишний раз не клепаем ноды)
	if inventory_panel.visible and tabs_container.get_tab_title(tabs_container.current_tab) == "Задания гильдии":
		_refresh_quests()


func _refresh_quests() -> void:
	# удаляем старые записи
	for child in quests_container.get_children():
		child.queue_free()

	# создаём новые
	for quest_id in QuestMgr.quests.keys():
		if !QuestMgr.has_quest(quest_id):
			continue
		var entry: Control = QuestEntryScene.instantiate()
		quests_container.add_child(entry)
		entry.init_entry(quest_id, QuestMgr.quests[quest_id])
