extends Node

signal inventory_changed            # уведомление подписчиков (UI, квесты и т.д.)

var items: Array = []               # Array[Resource]; каждый Resource обязан иметь поле .count (int)

# --------------------------------------------------
#  ADD
# --------------------------------------------------
func add_item(item: Resource, count: int = 1) -> void:
	if item == null or count <= 0:
		return

	# 1) пытаемся «долить» в уже существующий стек того же ресурса
	for stack in items:
		if stack.resource_path == item.resource_path:
			stack.count += count
			emit_signal("inventory_changed")
			return

	# 2) иначе создаём новый стек
	var new_stack: Resource = item.duplicate()
	if item.resource_path != "":
		new_stack.take_over_path(item.resource_path)
	new_stack.count = count
	items.append(new_stack)

	emit_signal("inventory_changed")


# --------------------------------------------------
#  REMOVE
# --------------------------------------------------
func remove_item(res_path: String, count: int = 1) -> void:
	if count <= 0:
		return

	var left: int = count
	for stack in items.duplicate():
		if stack.resource_path != res_path:
			continue

		var take: int = min(stack.count, left)
		stack.count -= take
		left -= take

		if stack.count <= 0:
			items.erase(stack)
		if left <= 0:
			break

	if left > 0:
		push_warning("Wanted to remove %d×%s but inventory had less" % [count, res_path])

	emit_signal("inventory_changed")


# --------------------------------------------------
#  QUERY
# --------------------------------------------------
func get_count(res_path: String) -> int:
	var total: int = 0
	for stack in items:
		if stack.resource_path == res_path:
			total += stack.count
	return total
