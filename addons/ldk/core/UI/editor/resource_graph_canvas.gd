@tool
extends GraphEdit
## Reusable GraphEdit surface. Consumers provide fields, typed slots and projected links.

signal resource_dropped(resource: Resource, graph_position: Vector2)
signal undo_requested
signal redo_requested

const NODE_WIDTH := 240.0

var nodes: Dictionary[StringName, GraphNode] = {}


func set_graph_node(id: StringName, title: String, position: Vector2,
		fields: Array[Control], slots: Dictionary[int, Dictionary]) -> void:
	var node: GraphNode = nodes.get(id)
	if node == null:
		node = GraphNode.new()
		node.name = id
		node.position_offset = position
		node.custom_minimum_size.x = NODE_WIDTH
		add_child(node)
		nodes[id] = node
	node.title = title
	node.clear_all_slots()
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
	for field in fields:
		node.add_child(field)
	for row in slots:
		var slot: Dictionary = slots[row]
		var left: int = slot.get("left", 0)
		var right: int = slot.get("right", 0)
		node.set_slot(row, left != 0, left, slot.get("left_color", Color.WHITE),
				right != 0, right, slot.get("right_color", Color.WHITE))
	node.reset_size()


func remove_graph_node(id: StringName) -> void:
	var node := nodes[id]
	nodes.erase(id)
	remove_child(node)
	node.queue_free()


func project_links(links: Array[Dictionary]) -> void:
	var desired: Array[Dictionary] = []
	for link in links:
		desired.append({
			"from_node": link["from_node"], "from_port": link["from_port"],
			"to_node": link["to_node"], "to_port": link["to_port"],
		})
	for link in get_connection_list():
		var endpoints := {
			"from_node": link["from_node"], "from_port": link["from_port"],
			"to_node": link["to_node"], "to_port": link["to_port"],
		}
		if not desired.has(endpoints):
			disconnect_node(endpoints.from_node, endpoints.from_port, endpoints.to_node, endpoints.to_port)
	for link in desired:
		if not is_node_connected(link.from_node, link.from_port, link.to_node, link.to_port):
			connect_node(link.from_node, link.from_port, link.to_node, link.to_port)


func selected_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in nodes:
		if nodes[id].selected:
			ids.append(id)
	return ids


func graph_position(at: Vector2) -> Vector2:
	return (at + scroll_offset) / zoom


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if data.get("type") == "resource":
		return data.get("resource") is Resource
	return _is_resource_file_drop(data)


func _drop_data(at: Vector2, data: Variant) -> void:
	if not _can_drop_data(at, data):
		return
	var resource: Resource = data.get("resource") if data.get("type") == "resource" else ResourceLoader.load(data.files[0])
	resource_dropped.emit(resource, graph_position(at))


func _is_resource_file_drop(data: Dictionary) -> bool:
	if data.get("type") != "files":
		return false
	var files: Variant = data.get("files")
	if not (files is PackedStringArray or files is Array) or files.size() != 1:
		return false
	var path: String = files[0]
	return path.get_extension().to_lower() in ["tres", "res"]


func _gui_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if not event.is_command_or_control_pressed():
		return
	if event.keycode == KEY_Z:
		if event.shift_pressed:
			redo_requested.emit()
		else:
			undo_requested.emit()
		accept_event()
	elif event.keycode == KEY_Y:
		redo_requested.emit()
		accept_event()
