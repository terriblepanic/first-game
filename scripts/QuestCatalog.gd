extends Node
## --------------------------------------------------
##  СПРАВОЧНИК КВЕСТОВ
## --------------------------------------------------

# ---------- РЕСУРСЫ ----------
const ITEM_COPPER_ORE : String = "res://items/copper_ore.tres"
const ITEM_IRON_ORE   : String = "res://items/iron_ore.tres"
const ITEM_GOLD_ORE   : String = "res://items/gold_ore.tres"
const ITEM_STONE      : String = "res://items/stone.tres"
const ITEM_GOLD_COIN  : String = "res://items/gold_coin.tres"
# …добавляй новые константы выше…

# ---------- ШАБЛОН ----------
const _TEMPLATE := {
	"title"  : "",
	"need"   : {},
	"reward" : {}
}

# ---------- БАЗА КВЕСТОВ ----------
var QUESTS: Dictionary = {
	"guild_copper": {
		"title"  : "Добыть 3 медных руды",
		"need"   : { ITEM_COPPER_ORE : 2 },
		"reward" : { ITEM_GOLD_COIN  : 1 }
	},
	"guild_stone": {
		"title"  : "Добыть 5 камня",
		"need"   : { ITEM_STONE : 5 },
		"reward" : { ITEM_GOLD_COIN  : 1 }
	},
	"guild_iron": {
		"title"  : "Добыть 1 железную руду",
		"need"   : { ITEM_IRON_ORE : 1 },
		"reward" : { ITEM_GOLD_COIN  : 1 }
	}
	# добавляй новые ниже…
}

# ---------- ПУБЛИЧНЫЙ API ----------
func has(id: String) -> bool:
	return QUESTS.has(id)

func get_quest(id: String) -> Dictionary:
	# копия, чтобы не менять оригинал
	return QUESTS.get(id, _TEMPLATE).duplicate(true)

func add(id: String, title: String, need: Dictionary, reward: Dictionary) -> void:
	QUESTS[id] = { "title": title, "need": need, "reward": reward }

func remove(id: String) -> void:
	QUESTS.erase(id)
