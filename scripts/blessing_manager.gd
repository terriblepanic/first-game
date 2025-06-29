## BlessingManager.gd (Singleton / Autoload)
extends Node

signal blessing_changed(god: String, blessing: String)

var _chosen: Dictionary = {}   # {god_name: blessing_name}

const _BONUS := {
	"Благословение прилива": {magic_mult = 2.00},
	"Глубинный покой":       {mana_regen_mult = 2.00},
	"Пылающий клинок":       {phys_mult = 1.50},
	"Фениксовое пламя":      {hp_mult = 1.50},
}

func set_blessing(god: String, blessing: String) -> void:
	_chosen[god] = blessing
	emit_signal("blessing_changed", god, blessing)

func get_blessing(god: String) -> String:
	return _chosen.get(god, "")

func get_modifiers() -> Dictionary:
	# базовые единичные коэффициенты
	var m := {hp_mult = 1.0, mana_regen_mult = 1.0, phys_mult = 1.0, magic_mult = 1.0}
	for b in _chosen.values():
		if _BONUS.has(b):
			for k in _BONUS[b]:
				m[k] *= _BONUS[b][k]
	return m

func get_all_blessings() -> Dictionary:
	# clone(), чтобы снаружи не могли случайно править наш _chosen
	return _chosen.duplicate()
