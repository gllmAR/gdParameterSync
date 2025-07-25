extends Resource
# Parameter resource class for gdParameterSync

enum PresetPolicy {
	FACTORY_ONLY,
	USER_OVERRIDE, 
	USER_ONLY
}

@export var name: String
@export var type: int = TYPE_FLOAT  # Variant.Type
@export var value: Variant = 0.0  # factory value
@export var min_value: Variant = null
@export var max_value: Variant = null
@export var step: float = 0.0
@export var enum_values: Array = []  # -> OSCQuery RANGE.VALS
@export var ui_hints: Dictionary = {}  # extended_type, unit, clipmode, log, etc.
@export var read_only: bool = false
@export var address_override: String = ""  # overrides auto /gdps/<...> address
@export var backend_meta: Dictionary = {}  # midi_cc, osc paths, overloads, etc.
@export var description: String = ""
@export var group: String = "Other"  # UI grouping category
@export var factory_value: Variant = null  # Original factory value for reset

func _init(p_name: String = "", p_type: int = TYPE_FLOAT, p_value: Variant = 0.0):
	name = p_name
	type = p_type
	value = p_value
	factory_value = p_value  # Store original value for reset
	
	# Set reasonable defaults based on type
	match type:
		TYPE_BOOL:
			if value == null: value = false
		TYPE_INT:
			if value == null: value = 0
			if min_value == null: min_value = 0
			if max_value == null: max_value = 100
		TYPE_FLOAT:
			if value == null: value = 0.0
			if min_value == null: min_value = 0.0
			if max_value == null: max_value = 1.0
			if step == 0.0: step = 0.01
		TYPE_STRING:
			if value == null: value = ""
		TYPE_VECTOR2:
			if value == null: value = Vector2.ZERO
		TYPE_VECTOR3:
			if value == null: value = Vector3.ZERO
		TYPE_COLOR:
			if value == null: value = Color.WHITE

func get_osc_address(set_id: String, group_path: String = "") -> String:
	if address_override != "":
		return address_override
	
	var path = "/gdps/" + set_id
	if group_path != "":
		path += "/" + group_path
	path += "/" + name
	return path

func validate_value(val: Variant) -> Variant:
	"""Validate and clamp value according to parameter constraints"""
	if read_only:
		return value  # Don't allow changes to read-only parameters
	
	# Type checking
	if typeof(val) != type:
		# Try to convert
		match type:
			TYPE_BOOL:
				if val is String:
					val = val.to_lower() in ["true", "1", "on", "yes"]
				else:
					val = bool(val)
			TYPE_INT:
				val = int(val)
			TYPE_FLOAT:
				val = float(val)
			TYPE_STRING:
				val = str(val)
			TYPE_OBJECT:
				# Handle Object type specially - could be Color or other objects
				if factory_value is Color and val is Color:
					# Color values are fine even though typeof(Color) != TYPE_OBJECT
					# Don't convert, just use the Color as-is
					pass
				elif typeof(val) != type:
					push_warning("Parameter %s: Cannot convert %s to %s" % [name, typeof(val), type])
					return value
			_:
				# For other complex types, ensure type matches
				if typeof(val) != type:
					push_warning("Parameter %s: Cannot convert %s to %s" % [name, typeof(val), type])
					return value
	
	# Range clamping (only for numeric types)
	if type in [TYPE_INT, TYPE_FLOAT]:
		if min_value != null and val < min_value:
			val = min_value
		if max_value != null and val > max_value:
			val = max_value
	elif type == TYPE_VECTOR2 and val is Vector2 and min_value is Vector2 and max_value is Vector2:
		# Clamp Vector2 components
		val.x = clamp(val.x, min_value.x, max_value.x)
		val.y = clamp(val.y, min_value.y, max_value.y)
	elif type == TYPE_VECTOR3 and val is Vector3 and min_value is Vector3 and max_value is Vector3:
		# Clamp Vector3 components  
		val.x = clamp(val.x, min_value.x, max_value.x)
		val.y = clamp(val.y, min_value.y, max_value.y)
		val.z = clamp(val.z, min_value.z, max_value.z)
	
	# Enum validation
	if enum_values.size() > 0 and val not in enum_values:
		push_warning("Parameter %s: Value %s not in enum %s" % [name, val, enum_values])
		return value
	
	# Step quantization for numeric types
	if step > 0.0 and type in [TYPE_INT, TYPE_FLOAT]:
		if min_value != null:
			val = min_value + round((val - min_value) / step) * step
		else:
			val = round(val / step) * step
	
	return val

func get_oscquery_descriptor() -> Dictionary:
	"""Generate OSCQuery descriptor for this parameter"""
	var desc = {
		"TYPE": _variant_type_to_oscquery_type(type),
		"VALUE": [value] if not value is Array else value,
		"ACCESS": "rw" if not read_only else "r"
	}
	
	# Add range info
	if min_value != null or max_value != null:
		var range_dict = {}
		if min_value != null:
			range_dict["MIN"] = min_value
		if max_value != null:
			range_dict["MAX"] = max_value
		if enum_values.size() > 0:
			range_dict["VALS"] = enum_values
		desc["RANGE"] = range_dict
	
	# Add optional attributes from ui_hints and meta
	if description != "":
		desc["DESCRIPTION"] = description
	
	for key in ui_hints:
		match key:
			"unit":
				desc["UNIT"] = ui_hints[key]
			"tags":
				desc["TAGS"] = ui_hints[key]
	
	return desc

func _variant_type_to_oscquery_type(variant_type: int) -> String:
	match variant_type:
		TYPE_BOOL:
			return "T"  # True/False
		TYPE_INT:
			return "i"  # int32
		TYPE_FLOAT:
			return "f"  # float32
		TYPE_STRING:
			return "s"  # string
		TYPE_VECTOR2:
			return "ff"  # two floats
		TYPE_VECTOR3:
			return "fff"  # three floats
		TYPE_COLOR:
			return "ffff"  # RGBA
		_:
			return "s"  # fallback to string

func reset_to_factory():
	"""Reset parameter to its factory default value"""
	if factory_value != null:
		value = factory_value
	
func is_at_factory_value() -> bool:
	"""Check if parameter is at its factory default value"""
	return value == factory_value
