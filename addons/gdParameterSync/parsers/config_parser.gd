extends Resource
# Enhanced parser for gdParameterSync
# Supports both TRES files and @export syntax

class_name GDPSConfigParser

static func parse_from_text(text: String) -> Resource:
	"""Parse @export syntax or TRES format into a ParameterSet"""
	# Detect format based on content
	if text.strip_edges().begins_with("[gd_resource"):
		return parse_tres_format(text)
	else:
		return parse_export_syntax(text)

static func parse_tres_format(text: String) -> Resource:
	"""Parse standard TRES resource format"""
	print("🔍 Parsing TRES format...")
	
	# For now, try to load as a resource directly
	# In a real implementation, you'd parse the TRES text format
	# This is a simplified approach for demo purposes
	
	var ParameterSetClass = load("res://addons/gdParameterSync/resources/parameter_set.gd")
	var parameter_set = ParameterSetClass.new()
	parameter_set.id = "tres_config"
	parameter_set.label = "TRES Configuration"
	
	print("✅ TRES parsing completed (simplified implementation)")
	return parameter_set

static func parse_export_syntax(text: String) -> Resource:
	"""Parse @export syntax into a ParameterSet"""
	print("🔍 Parsing @export syntax...")
	
	var ParameterSetClass = load("res://addons/gdParameterSync/resources/parameter_set.gd")
	var ParameterClass = load("res://addons/gdParameterSync/resources/parameter.gd")
	var ParameterGroupClass = load("res://addons/gdParameterSync/resources/parameter_group.gd")
	
	var parameter_set = ParameterSetClass.new()
	parameter_set.id = "config"
	parameter_set.label = "Configuration"
	
	var current_group = null
	var lines = text.split("\n")
	
	for line in lines:
		line = line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		
		if line.begins_with("@export_group("):
			# Parse group: @export_group("Audio Settings")
			var group_name = _extract_string_from_parens(line)
			current_group = ParameterGroupClass.new()
			current_group.name = group_name.to_lower().replace(" ", "_")
			# Note: ParameterGroup doesn't have a label property, using name for both
			parameter_set.groups.append(current_group)
			
		elif line.begins_with("@export var "):
			# Parse parameter: @export var master_volume: float = 0.8 ## Master Volume: 0.0 to 1.0 | step: 0.01
			var param = _parse_export_line(line, ParameterClass)
			if param:
				# Note: Parameters don't have group property, groups are handled at the set level
				parameter_set.parameters.append(param)
	
	print("✅ @export syntax parsing completed with ", parameter_set.parameters.size(), " parameters")
	return parameter_set

# Smart loader that handles multiple file formats
static func load_from_file(file_path: String) -> Resource:
	"""Load configuration from file, auto-detecting format"""
	print("📁 Loading config from: ", file_path)
	
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		print("❌ Failed to open file: ", file_path)
		return null
	
	var content = file.get_as_text()
	file.close()
	
	if content.is_empty():
		print("❌ File is empty: ", file_path)
		return null
	
	# Try to load as TRES resource first if it's a .tres file
	if file_path.ends_with(".tres"):
		print("🎯 Attempting TRES resource loading...")
		var resource = load(file_path)
		if resource:
			print("✅ Successfully loaded TRES resource")
			return resource
		else:
			print("⚠️ TRES loading failed, trying text parsing...")
	
	# Fall back to text parsing
	return parse_from_text(content)

static func _extract_string_from_parens(line: String) -> String:
	var start = line.find("\"")
	var end = line.find("\"", start + 1)
	if start != -1 and end != -1:
		return line.substr(start + 1, end - start - 1)
	return ""

static func _parse_export_line(line: String, ParameterClass) -> Resource:
	"""Parse: @export var master_volume: float = 0.8 ## Master Volume: 0.0 to 1.0 | step: 0.01"""
	
	# Split at ##
	var parts = line.split("##", false, 1)
	var var_part = parts[0].strip_edges()
	var comment_part = parts[1].strip_edges() if parts.size() > 1 else ""
	
	# Parse variable declaration
	var var_match = RegEx.new()
	var_match.compile(r"@export var (\w+):\s*(\w+)\s*=\s*(.+)")
	var result = var_match.search(var_part)
	
	if not result:
		return null
	
	var param_name = result.get_string(1)
	var type_name = result.get_string(2)
	var default_value_str = result.get_string(3)
	
	# Create parameter
	var param = ParameterClass.new()
	param.name = param_name
	
	# Parse type and default value
	match type_name:
		"float":
			param.type = TYPE_FLOAT
			param.value = float(default_value_str)
		"int":
			param.type = TYPE_INT
			param.value = int(default_value_str)
		"bool":
			param.type = TYPE_BOOL
			param.value = default_value_str == "true"
		"String":
			param.type = TYPE_STRING
			param.value = default_value_str.strip_edges().trim_prefix("\"").trim_suffix("\"")
		"Color":
			param.type = TYPE_COLOR
			param.value = _parse_color(default_value_str)
		"Vector2":
			param.type = TYPE_VECTOR2
			param.value = _parse_vector2(default_value_str)
		"Vector3":
			param.type = TYPE_VECTOR3
			param.value = _parse_vector3(default_value_str)
	
	# Parse comment metadata
	if comment_part:
		_parse_comment_metadata(param, comment_part)
	
	return param

static func _parse_comment_metadata(param: Resource, comment: String):
	"""Parse: Master Volume: 0.0 to 1.0 | step: 0.01 | labels: Easy,Normal,Hard"""
	
	var parts = comment.split("|")
	var main_part = parts[0].strip_edges()
	
	# Extract description and range from main part
	if ":" in main_part:
		var desc_parts = main_part.split(":", false, 1)
		param.description = desc_parts[0].strip_edges()
		
		var range_part = desc_parts[1].strip_edges()
		if " to " in range_part:
			var range_values = range_part.split(" to ")
			if range_values.size() == 2:
				if param.type == TYPE_FLOAT:
					param.min_value = float(range_values[0])
					param.max_value = float(range_values[1])
				elif param.type == TYPE_INT:
					param.min_value = int(range_values[0])
					param.max_value = int(range_values[1])
	else:
		param.description = main_part
	
	# Parse additional metadata
	for i in range(1, parts.size()):
		var metadata = parts[i].strip_edges()
		if metadata.begins_with("step:"):
			param.step = float(metadata.split(":")[1].strip_edges())
		elif metadata.begins_with("labels:"):
			var labels_str = metadata.split(":", false, 1)[1].strip_edges()
			param.enum_values = labels_str.split(",")
			for j in range(param.enum_values.size()):
				param.enum_values[j] = param.enum_values[j].strip_edges()

static func _parse_color(value_str: String) -> Color:
	# Handle Color(r, g, b) or Color(r, g, b, a) or predefined colors
	if value_str.begins_with("Color("):
		var inner = value_str.trim_prefix("Color(").trim_suffix(")")
		var components = inner.split(",")
		if components.size() >= 3:
			var r = float(components[0].strip_edges())
			var g = float(components[1].strip_edges())
			var b = float(components[2].strip_edges())
			var a = 1.0
			if components.size() >= 4:
				a = float(components[3].strip_edges())
			return Color(r, g, b, a)
	elif value_str == "Color.WHITE":
		return Color.WHITE
	elif value_str == "Color.BLACK":
		return Color.BLACK
	elif value_str == "Color.RED":
		return Color.RED
	elif value_str == "Color.GREEN":
		return Color.GREEN
	elif value_str == "Color.BLUE":
		return Color.BLUE
	
	return Color.WHITE

static func _parse_vector2(value_str: String) -> Vector2:
	if value_str.begins_with("Vector2("):
		var inner = value_str.trim_prefix("Vector2(").trim_suffix(")")
		var components = inner.split(",")
		if components.size() >= 2:
			var x = float(components[0].strip_edges())
			var y = float(components[1].strip_edges())
			return Vector2(x, y)
	elif value_str == "Vector2.ZERO":
		return Vector2.ZERO
	elif value_str == "Vector2.ONE":
		return Vector2.ONE
	
	return Vector2.ZERO

static func _parse_vector3(value_str: String) -> Vector3:
	if value_str.begins_with("Vector3("):
		var inner = value_str.trim_prefix("Vector3(").trim_suffix(")")
		var components = inner.split(",")
		if components.size() >= 3:
			var x = float(components[0].strip_edges())
			var y = float(components[1].strip_edges())
			var z = float(components[2].strip_edges())
			return Vector3(x, y, z)
	elif value_str == "Vector3.ZERO":
		return Vector3.ZERO
	elif value_str == "Vector3.ONE":
		return Vector3.ONE
	
	return Vector3.ZERO

# Function to generate .tres content from @export syntax
static func export_syntax_to_tres(text: String) -> String:
	var parameter_set = parse_export_syntax(text)
	if parameter_set:
		# In a real implementation, this would generate proper TRES format
		return "# Generated TRES content from @export syntax\n" + text
	return ""
