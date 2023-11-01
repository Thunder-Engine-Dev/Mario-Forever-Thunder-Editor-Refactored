class_name Process

## Static class provides methods related to process


## Returns the delta time according to the place where the code is typed [br]
## If in [method Node._process], then return _process()'s [br]
## And if in [method Node._physics_process], then return _physics_process()'s
static func get_delta(node: Node) -> float:
	return node.get_physics_process_delta_time() if Engine.is_in_physics_frame() else node.get_process_delta_time()


## Iterate nodes and find one including their multilevel children
static func iterate_get_child(from: Node, type: Object) -> Node:
	for i: Node in from.get_children():
		if is_instance_of(i, type):
			return i
		elif i.get_child_count():
			return iterate_get_child(i, type)
	return null
