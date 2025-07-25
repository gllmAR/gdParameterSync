class_name ParameterBinding
extends Resource

@export var parameter_path: String  # inside the set
@export var node: NodePath
@export var property: String
@export var transform_to_node: Callable
@export var transform_from_node: Callable

func _init(p_path: String = "", p_node: NodePath = NodePath(), p_property: String = ""):
	parameter_path = p_path
	node = p_node
	property = p_property

func is_valid() -> bool:
	"""Check if the binding configuration is valid"""
	return parameter_path != "" and not node.is_empty() and property != ""

func apply_to_node(node_ref: Node, value: Variant) -> void:
	"""Apply parameter value to the bound node property"""
	if not is_valid() or not node_ref:
		return
	
	var final_value = value
	
	# Apply transformation if provided
	if transform_to_node.is_valid():
		final_value = transform_to_node.call(value)
	
	# Set the property
	if node_ref.has_method("set_" + property):
		node_ref.call("set_" + property, final_value)
	elif property in node_ref:
		node_ref.set(property, final_value)
	else:
		push_warning("Property '%s' not found on node %s" % [property, node_ref])

func get_value_from_node(node_ref: Node) -> Variant:
	"""Get current value from the bound node property"""
	if not is_valid() or not node_ref:
		return null
	
	var value = null
	
	# Get the property value
	if node_ref.has_method("get_" + property):
		value = node_ref.call("get_" + property)
	elif property in node_ref:
		value = node_ref.get(property)
	else:
		push_warning("Property '%s' not found on node %s" % [property, node_ref])
		return null
	
	# Apply reverse transformation if provided
	if transform_from_node.is_valid():
		value = transform_from_node.call(value)
	
	return value
