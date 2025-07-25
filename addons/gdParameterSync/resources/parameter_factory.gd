extends RefCounted
# Factory methods for creating common parameter types

static func create_float(name: String, default_value: float = 0.0, min_val: float = 0.0, max_val: float = 1.0, step_val: float = 0.01):
	"""Create a float parameter with common settings"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_FLOAT
	param.value = default_value
	param.min_value = min_val
	param.max_value = max_val
	param.step = step_val
	return param

static func create_int(name: String, default_value: int = 0, min_val: int = 0, max_val: int = 100):
	"""Create an integer parameter with common settings"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_INT
	param.value = default_value
	param.min_value = min_val
	param.max_value = max_val
	return param

static func create_bool(name: String, default_value: bool = false):
	"""Create a boolean parameter"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_BOOL
	param.value = default_value
	return param

static func create_string(name: String, default_value: String = ""):
	"""Create a string parameter"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_STRING
	param.value = default_value
	return param

static func create_enum(name: String, values: Array, default_index: int = 0):
	"""Create an enum parameter"""
	var default_value = values[default_index] if default_index < values.size() else values[0]
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = typeof(default_value)
	param.value = default_value
	param.enum_values = values
	return param

static func create_color(name: String, default_value: Color = Color.WHITE):
	"""Create a color parameter"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_COLOR
	param.value = default_value
	return param

static func create_vector2(name: String, default_value: Vector2 = Vector2.ZERO):
	"""Create a Vector2 parameter"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_VECTOR2
	param.value = default_value
	return param

static func create_vector3(name: String, default_value: Vector3 = Vector3.ZERO):
	"""Create a Vector3 parameter"""
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var param = ParameterClass.new()
	param.name = name
	param.type = TYPE_VECTOR3
	param.value = default_value
	return param
