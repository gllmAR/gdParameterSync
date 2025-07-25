class_name ParameterStore
extends RefCounted

signal parameter_changed(set_id: String, path: String, value: Variant, source: String)
signal set_registered(set_id: String)
signal set_unregistered(set_id: String)

var _parameter_sets: Dictionary = {}  # set_id -> ParameterSet
var _current_values: Dictionary = {}  # set_id -> {path -> value}

func register_set(param_set) -> void:
	"""Register a parameter set and initialize its values"""
	if not param_set or param_set.id == "":
		push_error("Cannot register invalid parameter set")
		return
	
	var errors = param_set.validate()
	if errors.size() > 0:
		push_error("Parameter set validation failed: %s" % str(errors))
		return
	
	_parameter_sets[param_set.id] = param_set
	_current_values[param_set.id] = {}
	
	# Initialize with factory values
	var all_params = param_set.get_all_parameters()
	for path in all_params:
		var param = all_params[path]
		_current_values[param_set.id][path] = param.value
	
	print("Registered parameter set: %s with %d parameters" % [param_set.id, all_params.size()])
	set_registered.emit(param_set.id)

func unregister_set(set_id: String) -> void:
	"""Unregister a parameter set"""
	if set_id in _parameter_sets:
		_parameter_sets.erase(set_id)
		_current_values.erase(set_id)
		set_unregistered.emit(set_id)

func get_parameter_sets() -> Dictionary:
	"""Get all registered parameter sets"""
	return _parameter_sets.duplicate()

func has_set(set_id: String) -> bool:
	"""Check if a parameter set is registered"""
	return set_id in _parameter_sets

func get_value(set_id: String, path: String) -> Variant:
	"""Get current value of a parameter"""
	if not has_set(set_id):
		push_warning("Parameter set not found: %s" % set_id)
		return null
	
	if path in _current_values[set_id]:
		return _current_values[set_id][path]
	
	push_warning("Parameter not found: %s/%s" % [set_id, path])
	return null

func get_value_safe(set_id: String, path: String) -> Variant:
	"""Get parameter value with type safety and automatic conversion"""
	if not has_set(set_id):
		push_warning("Parameter set not found: %s" % set_id)
		return null
	
	var param_set = _parameter_sets[set_id]
	var param = param_set.find_parameter(path)
	
	if not param:
		push_warning("Parameter not found: %s/%s" % [set_id, path])
		return null
	
	var current_value = _current_values[set_id].get(path)
	var expected_type = param.type
	var factory_value = param.factory_value
	
	# Return factory value if current value is null
	if current_value == null:
		return factory_value
	
	# Type validation and conversion
	if typeof(current_value) == expected_type:
		return current_value
	else:
		# Try to convert if possible
		var converted_value = _convert_value_to_type(current_value, expected_type, factory_value)
		if converted_value != null:
			# Update the stored value with the converted value
			_current_values[set_id][path] = converted_value
			return converted_value
		else:
			# Conversion failed, return factory value and warn
			push_warning("Type mismatch for parameter '%s/%s': got %s, expected %s. Using factory value." % [set_id, path, typeof(current_value), expected_type])
			_current_values[set_id][path] = factory_value
			return factory_value

func _convert_value_to_type(value: Variant, target_type: int, fallback_value: Variant) -> Variant:
	"""Convert value to target type with intelligent conversion"""
	match target_type:
		TYPE_INT:
			if value is float:
				return int(value)
			elif value is String and value.is_valid_int():
				return value.to_int()
			elif value is bool:
				return 1 if value else 0
		TYPE_FLOAT:
			if value is int:
				return float(value)
			elif value is String and value.is_valid_float():
				return value.to_float()
			elif value is bool:
				return 1.0 if value else 0.0
		TYPE_BOOL:
			if value is int:
				return value != 0
			elif value is float:
				return value != 0.0
			elif value is String:
				return value.to_lower() in ["true", "1", "yes", "on"]
		TYPE_STRING:
			# Almost anything can be converted to string
			return str(value)
		TYPE_VECTOR2:
			if value is String and "(" in value:
				# Try to parse Vector2 from string representation
				var clean = value.replace("(", "").replace(")", "").replace(" ", "")
				var parts = clean.split(",")
				if parts.size() == 2:
					return Vector2(parts[0].to_float(), parts[1].to_float())
			elif value is Vector3:
				return Vector2(value.x, value.y)
		TYPE_VECTOR3:
			if value is String and "(" in value:
				# Try to parse Vector3 from string representation
				var clean = value.replace("(", "").replace(")", "").replace(" ", "")
				var parts = clean.split(",")
				if parts.size() == 3:
					return Vector3(parts[0].to_float(), parts[1].to_float(), parts[2].to_float())
			elif value is Vector2:
				return Vector3(value.x, value.y, 0.0)
		TYPE_OBJECT: # Could be Color or other objects
			if fallback_value is Color and value is Color:
				# Color values are fine even though typeof(Color) != TYPE_OBJECT
				# Return the Color value directly
				return value
			elif value is String:
				# Try to parse Color from string
				if value.begins_with("#"):
					return Color.html(value)
				elif value.begins_with("Color("):
					# Parse Color(r, g, b, a) format
					var clean = value.replace("Color(", "").replace(")", "").replace(" ", "")
					var parts = clean.split(",")
					if parts.size() >= 3:
						var r = parts[0].to_float()
						var g = parts[1].to_float()
						var b = parts[2].to_float()
						var a = 1.0 if parts.size() < 4 else parts[3].to_float()
						return Color(r, g, b, a)
	
	# No conversion possible
	return null

func set_value(set_id: String, path: String, value: Variant, source: String = "local") -> bool:
	"""Set parameter value with validation"""
	if not has_set(set_id):
		push_warning("Parameter set not found: %s" % set_id)
		return false
	
	var param_set = _parameter_sets[set_id]
	var param = param_set.find_parameter(path)
	
	if not param:
		push_warning("Parameter not found: %s/%s" % [set_id, path])
		return false
	
	# Validate the value
	var validated_value = param.validate_value(value)
	
	# Only update if the value actually changed
	var old_value = _current_values[set_id].get(path)
	if validated_value != old_value:
		_current_values[set_id][path] = validated_value
		parameter_changed.emit(set_id, path, validated_value, source)
		return true
	
	return false

func get_all_values(set_id: String) -> Dictionary:
	"""Get all current values for a parameter set"""
	if has_set(set_id):
		return _current_values[set_id].duplicate()
	return {}

func reset_to_factory(set_id: String) -> void:
	"""Reset all parameters in a set to their factory values"""
	if not has_set(set_id):
		return
	
	var param_set = _parameter_sets[set_id]
	var all_params = param_set.get_all_parameters()
	
	for path in all_params:
		var param = all_params[path]
		set_value(set_id, path, param.value, "factory_reset")

func get_parameter_info(set_id: String, path: String) -> Dictionary:
	"""Get parameter metadata for UI/OSCQuery generation"""
	if not has_set(set_id):
		return {}
	
	var param_set = _parameter_sets[set_id]
	var param = param_set.find_parameter(path)
	
	if not param:
		return {}
	
	return {
		"name": param.name,
		"type": param.type,
		"value": get_value(set_id, path),
		"min_value": param.min_value,
		"max_value": param.max_value,
		"step": param.step,
		"enum_values": param.enum_values,
		"read_only": param.read_only,
		"description": param.description,
		"ui_hints": param.ui_hints,
		"backend_meta": param.backend_meta
	}

func describe_set(set_id: String) -> Dictionary:
	"""Get full description of a parameter set for external consumers"""
	if not has_set(set_id):
		return {}
	
	var param_set = _parameter_sets[set_id]
	var description = {
		"id": param_set.id,
		"label": param_set.label,
		"preset_policy": param_set.preset_policy,
		"meta": param_set.meta,
		"parameters": {},
		"structure": param_set.get_structure_for_ui(),
		"osc_addresses": param_set.get_osc_address_map()
	}
	
	var all_params = param_set.get_all_parameters()
	for path in all_params:
		description.parameters[path] = get_parameter_info(set_id, path)
	
	return description

func describe_all() -> Dictionary:
	"""Get descriptions of all registered parameter sets"""
	var descriptions = {}
	for set_id in _parameter_sets:
		descriptions[set_id] = describe_set(set_id)
	return descriptions
