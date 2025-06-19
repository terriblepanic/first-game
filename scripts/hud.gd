extends CanvasLayer

const OrbUIController = preload("res://scripts/OrbUIController.gd")

# Орбы
var hp_orb: OrbUIController
var mp_orb: OrbUIController

@onready var orb_hp_sprite: Sprite2D = $HUD/OrbHP/Sprite2D
@onready var orb_mp_sprite: Sprite2D = $HUD/OrbMP/Sprite2D

# Инвентарь
@onready var inventory_panel: Control = $HUD/InventoryPanel
@onready var inventory_grid: GridContainer = $HUD/InventoryPanel/InfoTabs/InventoryTab/InventoryGrid
@onready var blessings_list: ItemList = $HUD/InventoryPanel/InfoTabs/StatsTab/BlessingsList
@onready var inventory: Inventory = $Inventory

func _ready() -> void:
	var player = $"../Player/Player"

	# === Инициализация орбов до сигналов ===
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
	mp_orb.alert_ball_color = Color(0.2, 0.2, 1.0, 1)
	mp_orb.Reset()
	mp_orb.SetDeathStateEnabled(false)
	mp_material.set_shader_parameter("water_color", Color(0.2, 0.5, 1, 1))
	mp_material.set_shader_parameter("transparent_empty", true)

	# === Подключение сигналов после инициализации орбов ===
	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
		if player.has_signal("mana_changed"):
			player.mana_changed.connect(_on_player_mana_changed)

		_on_player_health_changed(player.health, player.max_health)
		_on_player_mana_changed(player.mana, player.max_mana)

	if inventory:
		inventory.inventory_changed.connect(_on_inventory_changed)

        inventory_panel.visible = false
        update_blessings_list()

func _process(_delta: float) -> void:
        if Input.is_action_just_pressed("open_inventory"):
                inventory_panel.visible = not inventory_panel.visible
                if inventory_panel.visible:
                        inventory.populate_grid(inventory_grid)
                        update_blessings_list()

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
                inventory.populate_grid(inventory_grid)

func update_blessings_list() -> void:
        blessings_list.clear()
        for god in BlessingManager.blessings.keys():
                var blessing = BlessingManager.blessings[god]
                blessings_list.add_item("%s: %s" % [god, blessing])

