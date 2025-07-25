extends Control

"""
Optimized Polygon Demo - Leverages gdParameterSync addon fully
Now much simpler and focuses on demonstrating the addon capabilities
"""

var param_sync
var ui_generator
var polygon_drawer
var set_id = "polygon_config"

func _ready():
	print("🎨 Optimized Polygon Demo - Showcasing gdParameterSync")
	setup_parameter_sync()
	setup_automatic_ui()
	setup_polygon_drawer()

func setup_parameter_sync():
	"""Get the parameter sync system"""
	param_sync = get_node_or_null("/root/ParameterSync")
	if not param_sync:
		print("⚠️ ParameterSync not found - enable gdParameterSync addon")
	else:
		print("🔄 Forcing reset to factory values to ensure clean state")
		# Force a reset to factory values to clear any cached String values
		param_sync.reset_to_factory(set_id)

func setup_automatic_ui():
	"""Generate automatic UI with groups and reset functionality"""
	var UIGenerator = load("res://addons/gdParameterSync/ui/parameter_ui_generator.gd")
	ui_generator = UIGenerator.new()
	add_child(ui_generator)
	
	# One-line UI generation from TRES
	var success = ui_generator.generate_ui_from_tres(
		"res://polygon_config.tres",
		Vector2(10, 10), 
		Vector2(350, 500)
	)
	
	if success:
		print("✅ Automatic UI generated with groups and reset functionality")
		ui_generator.parameter_changed.connect(_on_parameter_changed)
	else:
		print("❌ Failed to generate UI")

func setup_polygon_drawer():
	"""Create drawing area"""
	polygon_drawer = Control.new()
	polygon_drawer.position = Vector2(380, 20)
	polygon_drawer.size = Vector2(400, 400)
	# Set up custom _draw method
	polygon_drawer.set_script(preload("res://polygon_drawer.gd"))
	polygon_drawer.demo = self
	add_child(polygon_drawer)

func _on_parameter_changed(_set_id: String, _param_name: String, _value, _source: String):
	"""Redraw on any parameter change"""
	print("🔄 Parameter changed: ", _param_name, " = ", _value, " (source: ", _source, ")")
	polygon_drawer.queue_redraw()

func _generate_polygon_points(sides: int, radius: float, poly_rotation: float, center: Vector2) -> PackedVector2Array:
	"""Generate polygon points"""
	var points = PackedVector2Array()
	for i in range(sides):
		var angle = (float(i) / sides) * 2.0 * PI + deg_to_rad(poly_rotation)
		var point = Vector2(cos(angle), sin(angle)) * radius + center
		points.append(point)
	return points
