class_name ParameterSet
extends Resource

enum PresetPolicy {
	FACTORY_ONLY,
	USER_OVERRIDE,
	USER_ONLY
}

@export var id: String  # unique, used in paths & discovery
@export var label: String
@export var groups: Array = []  # Array[ParameterGroup]
@export var parameters: Array = []  # Array[Parameter] - top-level params
@export var preset_policy: PresetPolicy = PresetPolicy.USER_OVERRIDE
@export var bindings: Array = []  # Array[ParameterBinding]
@export var meta: Dictionary = {}  # tags, units, etc. (feeds OSCQuery optional attrs)

func _init(p_id: String = "", p_label: String = ""):
	id = p_id
	label = p_label if p_label != "" else p_id

func get_all_parameters() -> Dictionary:
	"""Get all parameters from this set with their full paths"""
	var result = {}
	
	# Add top-level parameters
	for param in parameters:
		result[param.name] = param
	
	# Add parameters from groups
	for group in groups:
		var group_params = group.get_all_parameters()
		for path in group_params:
			result[path] = group_params[path]
	
	return result

func find_parameter(path: String):
	"""Find a parameter by path"""
	# Check top-level parameters first
	for param in parameters:
		if param.name == path:
			return param
	
	# Check in groups
	var path_parts = path.split("/")
	if path_parts.size() > 1:
		# Find the group
		var group_name = path_parts[0]
		for group in groups:
			if group.name == group_name:
				var remaining_path = "/".join(path_parts.slice(1))
				return group.find_parameter(remaining_path)
	
	return null

func get_parameter_paths() -> Array:
	"""Get all parameter paths in this set"""
	var paths = []
	var all_params = get_all_parameters()
	for path in all_params:
		paths.append(path)
	return paths

func get_osc_address_map() -> Dictionary:
	"""Get mapping of OSC addresses to parameter paths"""
	var address_map = {}
	var all_params = get_all_parameters()
	
	for path in all_params:
		var param = all_params[path]
		var group_path = ""
		var path_parts = path.split("/")
		if path_parts.size() > 1:
			group_path = "/".join(path_parts.slice(0, path_parts.size() - 1))
		
		var osc_address = param.get_osc_address(id, group_path)
		address_map[osc_address] = path
	
	return address_map

func get_structure_for_ui() -> Dictionary:
	"""Get hierarchical structure for UI generation"""
	var structure = {
		"id": id,
		"label": label,
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

func validate() -> Array:
	"""Validate the parameter set and return any errors"""
	var errors = []
	
	if id == "":
		errors.append("ParameterSet must have an id")
	
	# Check for duplicate parameter names at each level
	var param_names = {}
	for param in parameters:
		if param.name in param_names:
			errors.append("Duplicate parameter name: %s" % param.name)
		param_names[param.name] = true
	
	# Validate groups
	var group_names = {}
	for group in groups:
		if group.name in group_names:
			errors.append("Duplicate group name: %s" % group.name)
		group_names[group.name] = true
	
	return errors
