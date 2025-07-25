class_name MessagingRouter
extends RefCounted

signal message_routed(set_id: String, path: String, value: Variant, source: String)

var _parameter_store  # ParameterStore
var _backends: Dictionary = {}  # name -> backend instance
var _enabled_backends: Dictionary = {}  # name -> bool

func _init(store):  # store: ParameterStore
	_parameter_store = store
	# Connect to store changes to route to backends
	_parameter_store.parameter_changed.connect(_on_parameter_changed)

func register_backend(name: String, backend) -> void:
	"""Register a backend for message routing"""
	if name in _backends:
		push_warning("Backend %s already registered" % name)
		return
	
	_backends[name] = backend
	_enabled_backends[name] = false
	
	# Connect backend signals
	if backend.has_signal("message_in"):
		backend.message_in.connect(_on_backend_message.bind(name))
	
	print("Registered backend: %s" % name)

func enable_backend(name: String, config: Dictionary = {}) -> bool:
	"""Enable and configure a backend"""
	if name not in _backends:
		push_error("Backend not found: %s" % name)
		return false
	
	var backend = _backends[name]
	
	if backend.has_method("configure"):
		backend.configure(config)
	
	if backend.has_method("start"):
		backend.start()
	
	_enabled_backends[name] = true
	print("Enabled backend: %s" % name)
	return true

func disable_backend(name: String) -> void:
	"""Disable a backend"""
	if name not in _backends:
		return
	
	var backend = _backends[name]
	
	if backend.has_method("stop"):
		backend.stop()
	
	_enabled_backends[name] = false
	print("Disabled backend: %s" % name)

func is_backend_enabled(name: String) -> bool:
	"""Check if a backend is enabled"""
	return _enabled_backends.get(name, false)

func get_enabled_backends() -> Array:
	"""Get list of enabled backend names"""
	var enabled = []
	for name in _enabled_backends:
		if _enabled_backends[name]:
			enabled.append(name)
	return enabled

func send_to_backend(backend_name: String, path: String, value: Variant) -> void:
	"""Send a message to a specific backend"""
	if not is_backend_enabled(backend_name):
		return
	
	var backend = _backends[backend_name]
	if backend.has_method("send"):
		backend.send(path, value)

func broadcast_to_backends(path: String, value: Variant, exclude_source: String = "") -> void:
	"""Broadcast a message to all enabled backends except the source"""
	for name in _enabled_backends:
		if _enabled_backends[name] and name != exclude_source:
			send_to_backend(name, path, value)

func route_message(set_id: String, path: String, value: Variant, source: String = "local") -> bool:
	"""Route a message through the parameter store and to backends"""
	# Update the parameter store
	var success = _parameter_store.set_value(set_id, path, value, source)
	
	if success:
		message_routed.emit(set_id, path, value, source)
		
		# Route to other backends (avoid echo loops)
		var full_path = "/gdps/" + set_id + "/" + path
		broadcast_to_backends(full_path, value, source)
	
	return success

func _on_parameter_changed(_set_id: String, _path: String, _value: Variant, _source: String) -> void:
	"""Handle parameter changes from the store"""
	# This gets called when the store value changes
	# We don't need to route back to backends here as route_message already handles that
	pass

func _on_backend_message(backend_name: String, path: String, value: Variant, _meta: Dictionary = {}) -> void:
	"""Handle incoming messages from backends"""
	print("Received from %s: %s = %s" % [backend_name, path, value])
	
	# Parse the path to extract set_id and parameter path
	var parsed = _parse_osc_path(path)
	if parsed.is_empty():
		push_warning("Invalid path format: %s" % path)
		return
	
	# Route through the system
	route_message(parsed.set_id, parsed.param_path, value, backend_name)

func _parse_osc_path(path: String) -> Dictionary:
	"""Parse an OSC path to extract set_id and parameter path"""
	# Expected format: /gdps/<set_id>/<param_path>
	if not path.begins_with("/gdps/"):
		return {}
	
	var parts = path.substr(6).split("/", false, 1)  # Remove "/gdps/" and split once
	if parts.size() < 2:
		return {}
	
	return {
		"set_id": parts[0],
		"param_path": parts[1]
	}

func get_status() -> Dictionary:
	"""Get status of all backends"""
	var status = {}
	for name in _backends:
		var backend = _backends[name]
		status[name] = {
			"enabled": _enabled_backends[name],
			"running": backend.has_method("is_running") and backend.is_running(),
			"connected": backend.has_signal("connected") and backend.connected if backend.has_method("connected") else false
		}
	return status
