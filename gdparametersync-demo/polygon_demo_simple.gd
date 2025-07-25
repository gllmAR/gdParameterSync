extends Control

"""
Simplified Polygon Demo - Leverages gdParameterSync addon fully
Features:
- One-line UI generation from TRES
- Automatic parameter grouping
- Built-in reset functionality  
- Minimal demo code, maximum addon leverage
"""

var param_sync
var ui_generator
var polygon_drawer

func _ready():
	print("🎨 Simple Polygon Demo - Leveraging gdParameterSync addon")
	
	# Get the parameter sync system
	param_sync = get_node_or_null("/root/ParameterSync")
	if not param_sync:
		print("⚠️ ParameterSync not found - enable gdParameterSync addon")
		return
	
	# Create automatic UI from TRES file - ONE LINE!
	setup_ui()
	
	# Create simple drawing area
	setup_drawing_area()

func setup_ui():
	"""Generate complete UI automatically from TRES file"""
	var UIGenerator = load("res://addons/gdParameterSync/ui/parameter_ui_generator.gd")
	ui_generator = UIGenerator.new()
	add_child(ui_generator)
	
	# Generate complete grouped UI with reset functionality
	var success = ui_generator.generate_ui_from_tres(
		"res://polygon_config.tres"
	)
	
	if success:
		print("✅ Complete UI generated with groups and reset functionality")
		# Connect to changes for redrawing
		ui_generator.parameter_changed.connect(_on_parameter_changed)
	else:
		print("❌ UI generation failed")

func setup_drawing_area():
	"""Create minimal drawing area"""
	polygon_drawer = Control.new()
	polygon_drawer.position = Vector2(380, 20)
	polygon_drawer.size = Vector2(400, 400)
	polygon_drawer.draw.connect(_draw_polygon)
	add_child(polygon_drawer)

func _on_parameter_changed(_set_id: String, _param_name: String, _value, _source: String):
	"""Redraw when any parameter changes"""
	polygon_drawer.queue_redraw()

func _draw_polygon():
	"""Simple polygon drawing using parameters from TRES"""
	if not param_sync:
		return
	
	var set_id = "polygon_config"
	
	# Get all parameters - addon now handles type safety automatically!
	var sides = param_sync.get_value(set_id, "sides") 
	var radius = param_sync.get_value(set_id, "radius")
	var poly_rotation = param_sync.get_value(set_id, "rotation")
	var fill_color = param_sync.get_value(set_id, "fill_color")
	var line_color = param_sync.get_value(set_id, "line_color")
	var line_width = param_sync.get_value(set_id, "line_width")
	var poly_position = param_sync.get_value(set_id, "position")
	var scale_factor = param_sync.get_value(set_id, "scale_factor")
	var pulse_enabled = param_sync.get_value(set_id, "pulse_enabled")
	var pulse_strength = param_sync.get_value(set_id, "pulse_strength")
	
	# Apply pulse effect
	var final_radius = radius * scale_factor
	if pulse_enabled:
		var pulse_factor = 1.0 + sin(Time.get_unix_time_from_system() * 3.0) * pulse_strength
		final_radius *= pulse_factor
	
	# Generate polygon points
	var points = PackedVector2Array()
	for i in range(sides):
		var angle = (float(i) / sides) * 2.0 * PI + deg_to_rad(poly_rotation)
		var point = Vector2(cos(angle), sin(angle)) * final_radius + poly_position
		points.append(point)
	
	# Draw filled polygon
	if fill_color.a > 0:
		polygon_drawer.draw_colored_polygon(points, fill_color)
	
	# Draw outline
	if line_width > 0 and line_color.a > 0:
		for i in range(points.size()):
			var start = points[i]
			var end = points[(i + 1) % points.size()]
			polygon_drawer.draw_line(start, end, line_color, line_width)
