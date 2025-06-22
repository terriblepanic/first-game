extends Node

var items: Array = []            # Array[Item]

func add_item(item: Resource, count: int = 1) -> void:
	# пытаемся долить в существующий стек
	for existing in items:
		if existing.resource_path == item.resource_path:
			existing.count += count
			return
	
	# создаём новый стек
	var new_item := item.duplicate()
	if item.resource_path != "":                     # путь есть → переносим его
		new_item.take_over_path(item.resource_path)  # ← вместо присваивания, без ошибки
	new_item.count = count
	items.append(new_item)
