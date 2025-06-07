extends CanvasLayer

@onready var inventory_panel: Control = $HUD/InventoryPanel
@onready var inventory_grid: GridContainer = $HUD/InventoryPanel/InventoryGrid
@onready var inventory: Inventory = $Inventory
@onready var health_bar: ProgressBar = $HUD/HealthBar
@onready var mana_bar: ProgressBar = $HUD/ManaBar

func _ready() -> void:
        var player = get_parent().get_node("Player")
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

func _process(_delta: float) -> void:
        if Input.is_action_just_pressed("open_inventory"):
                inventory_panel.visible = not inventory_panel.visible
                if inventory_panel.visible:
                        inventory.populate_grid(inventory_grid)

func _on_player_health_changed(value: int, max_value: int) -> void:
        health_bar.max_value = max_value
        health_bar.value = value

func _on_player_mana_changed(value: int, max_value: int) -> void:
        mana_bar.max_value = max_value
        mana_bar.value = value

func _on_inventory_changed() -> void:
        if inventory_panel.visible:
                inventory.populate_grid(inventory_grid)
