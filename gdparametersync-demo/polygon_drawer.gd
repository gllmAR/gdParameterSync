extends Control

var demo  # Reference to the main demo
var animation_time: float = 0.0  # Track animation time separately

func _ready():
	"""Enable processing for animation"""
	set_process(true)

func _process(delta):
	"""Handle animation updates"""
	if not demo or not demo.param_sync:
		return
	
	var set_id = demo.set_id
	var auto_rotate = demo.param_sync.get_value(set_id, "auto_rotate")
	var pulse_enabled = demo.param_sync.get_value(set_id, "pulse_enabled")
	
	# Only update animation time if we have active animations
	if auto_rotate or pulse_enabled:
		animation_time += delta
		queue_redraw()  # Trigger redraw for animation

func _draw():
	"""Override _draw to actually render the polygon"""
	if not demo or not demo.param_sync:
		return
	
	var set_id = demo.set_id
	
	# Get parameters directly from sync system - addon handles type safety!
	var sides = demo.param_sync.get_value(set_id, "sides")
	var radius = demo.param_sync.get_value(set_id, "radius") 
	var poly_rotation = demo.param_sync.get_value(set_id, "rotation")
	var auto_rotate = demo.param_sync.get_value(set_id, "auto_rotate")
	var rotate_speed = demo.param_sync.get_value(set_id, "rotate_speed")
	var fill_color = demo.param_sync.get_value(set_id, "fill_color")
	var line_color = demo.param_sync.get_value(set_id, "line_color")
	var line_width = demo.param_sync.get_value(set_id, "line_width")
	var poly_position = demo.param_sync.get_value(set_id, "position")
	var scale_factor = demo.param_sync.get_value(set_id, "scale_factor")
	var pulse_enabled = demo.param_sync.get_value(set_id, "pulse_enabled")
	var pulse_strength = demo.param_sync.get_value(set_id, "pulse_strength")
	
	# Calculate final rotation with auto rotate
	var final_rotation = poly_rotation
	if auto_rotate:
		final_rotation += animation_time * rotate_speed
	
	# Calculate final radius with pulse effects
	var final_radius = radius * scale_factor
	if pulse_enabled:
		final_radius *= 1.0 + sin(animation_time * 3.0) * pulse_strength
	
	# Generate polygon points with final rotation
	var points = PackedVector2Array()
	for i in range(sides):
		var angle = (float(i) / sides) * 2.0 * PI + deg_to_rad(final_rotation)
		var point = Vector2(cos(angle), sin(angle)) * final_radius + poly_position
		points.append(point)
	
	# Draw filled polygon
	if fill_color.a > 0:
		draw_colored_polygon(points, fill_color)
	
	# Draw outline
	if line_width > 0 and line_color.a > 0:
		for i in range(points.size()):
			var start = points[i]
			var end = points[(i + 1) % points.size()]
			draw_line(start, end, line_color, line_width)
