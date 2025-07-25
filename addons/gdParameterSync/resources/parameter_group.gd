class_name ParameterGroup
extends Resource

@export var name: String
@export var groups: Array[ParameterGroup] = []
@export var parameters: Array = []  # Array[Parameter] - will be typed when Parameter is available
@export var folded_by_default: bool = true

func _init(p_name: String = ""):
	name = p_name

func get_all_parameters(prefix: String = "") -> Dictionary:
	"""Get all parameters in this group and subgroups with their full paths"""
	var result = {}
	var current_prefix = prefix
	if current_prefix != "" and name != "":
		current_prefix += "/"
	if name != "":
		current_prefix += name
	
	# Add direct parameters
	for param in parameters:
		var path = param.name
		if current_prefix != "":
			path = current_prefix + "/" + param.name
		result[path] = param
	
	# Add parameters from subgroups
	for group in groups:
		var subgroup_params = group.get_all_parameters(current_prefix)
		for path in subgroup_params:
			result[path] = subgroup_params[path]
	
	return result

func find_parameter(path: String):
	"""Find a parameter by path within this group"""
	var parts = path.split("/")
	if parts.size() == 0:
		return null
	
	var param_name = parts[-1]
	
	# If it's a direct parameter
	if parts.size() == 1:
		for param in parameters:
			if param.name == param_name:
				return param
		return null
	
	# If it's in a subgroup
	var group_path = parts.slice(0, parts.size() - 1)
	var target_group = _find_group_by_path(group_path)
	if target_group:
		for param in target_group.parameters:
			if param.name == param_name:
				return param
	
	return null

func _find_group_by_path(path_parts: Array) -> ParameterGroup:
	"""Find a group by path parts"""
	if path_parts.size() == 0:
		return self
	
	var next_group_name = path_parts[0]
	for group in groups:
		if group.name == next_group_name:
			if path_parts.size() == 1:
				return group
			else:
				return group._find_group_by_path(path_parts.slice(1))
	
	return null

func get_group_structure() -> Dictionary:
	"""Get the hierarchical structure for UI generation"""
	var structure = {
		"name": name,
		"folded_by_default": folded_by_default,
		"parameters": [],
		"groups": []
	}
	
	for param in parameters:
		structure.parameters.append({
			"name": param.name,
			"type": param.type,
			"value": param.value,
			"read_only": param.read_only
		})
	
	for group in groups:
		structure.groups.append(group.get_group_structure())
	
	return structure
