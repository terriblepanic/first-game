extends CanvasLayer

const OrbUIController = preload("res://scripts/OrbUIController.gd")
const Inventory = preload("res://scripts/inventory.gd")

# Орбы
var hp_orb: OrbUIController
var mp_orb: OrbUIController

@onready var orb_hp_sprite: Sprite2D = $HUD/OrbHP/Sprite2D
@onready var orb_mp_sprite: Sprite2D = $HUD/OrbMP/Sprite2D
# Инвентарь
@onready var hud_root         : Node          = $HUD                         # нижний контейнер
@onready var inventory_panel  : Control       = hud_root.get_node("InventoryPanel") as Control
@onready var info_tabs        : TabContainer  = inventory_panel.get_node("InfoTabs") as TabContainer
@onready var inventory_grid   : GridContainer = hud_root.get_node("InventoryPanel/InfoTabs/Снаряжение/CenterContainer/InventoryGrid") as GridContainer
@onready var inventory_ui     : Inventory     = $Inventory                   # соседний узел
@onready var blessings_list   : ItemList      = hud_root.get_node("InventoryPanel/InfoTabs/Характеристики/BlessingsList") as ItemList
@onready var quests_list      : ItemList      = hud_root.get_node("InventoryPanel/InfoTabs/Задания гильдии/QuestsList")      as ItemList
@onready var player: CharacterBody2D = get_tree().get_first_node_in_group("player")


func _ready() -> void:
	# === Инициализация орбов (unchanged) ===
	var hp_material: ShaderMaterial = orb_hp_sprite.material.duplicate()
	orb_hp_sprite.material = hp_material
	hp_orb = OrbUIController.new()
	hp_orb.SetOwner(self)
	hp_orb.SetShader(hp_material)
	hp_orb.ball_color = Color(1, 1, 1, 1)
	hp_orb.alert_ball_color = Color(1, 0.3, 0.1, 1)
	hp_orb.Reset()
	hp_material.set_shader_parameter("water_color", Color(1, 0.3, 0.3, 1))
	hp_material.set_shader_parameter("transparent_empty", true)

	var mp_material: ShaderMaterial = orb_mp_sprite.material.duplicate()
	orb_mp_sprite.material = mp_material
	mp_orb = OrbUIController.new()
	mp_orb.SetOwner(self)
	mp_orb.SetShader(mp_material)
	mp_orb.ball_color = Color(1, 1, 1, 1)
	mp_orb.alert_ball_color = Color(0.2, 0.2, 1, 1)
	mp_orb.Reset()
	mp_orb.SetDeathStateEnabled(false)
	mp_material.set_shader_parameter("water_color", Color(0.2, 0.5, 1, 1))
	mp_material.set_shader_parameter("transparent_empty", true)

	# === Сигналы игрока (unchanged) ===
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("mana_changed"):
			player.mana_changed.connect(_on_player_mana_changed)
		_on_player_health_changed(player.health, player.max_health)
		_on_player_mana_changed(player.mana, player.max_mana)

	# подписываемся на изменение данных инвентаря
	inventory_ui.inventory_changed.connect(_on_inventory_changed)

	inventory_panel.visible = false   # скрываем панель при старте

	BlessingManager.blessing_changed.connect(update_blessings_list)
	update_blessings_list()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("open_inventory"):
		inventory_panel.visible = !inventory_panel.visible
		if inventory_panel.visible:
			info_tabs.current_tab = 1            # «Снаряжение»
			inventory_ui.refresh()               # перерисовать грид
			update_blessings_list()



# Сигнатура с двумя опциональными параметрами.
# Когда Main.spawn_altars() делает:
#    altar.blessing_selected.connect(hud.update_blessings_list)
#     ↑ 2 аргумента из сигнала уйдут в selected_god и selected_blessing
# А когда вы вызываете просто update_blessings_list() — оба будут пустые строки.
func update_blessings_list(selected_god: String = "", selected_blessing: String = "") -> void:
	blessings_list.clear()
	for god_key in BlessingManager.blessings.keys():
		var bless = BlessingManager.blessings[god_key]
		var txt = "%s: %s" % [god_key, bless]
		if god_key == selected_god and bless == selected_blessing:
			txt += " (выбрано)"
		blessings_list.add_item(txt)


func _on_player_health_changed(value: int, max_value: int) -> void:
	if hp_orb:
		var was := hp_orb.H * max_value
		if value < was:
			hp_orb.GetHit(value, was, max_value)
		else:
			hp_orb.SetSmooth(value, max_value)


func _on_player_mana_changed(value: int, max_value: int) -> void:
	if mp_orb:
		var was := mp_orb.H * max_value
		if value < was:
			mp_orb.GetHit(value, was, max_value)
		else:
			mp_orb.SetSmooth(value, max_value)


func _on_inventory_changed() -> void:
	if inventory_panel.visible:
		inventory_ui.refresh()
