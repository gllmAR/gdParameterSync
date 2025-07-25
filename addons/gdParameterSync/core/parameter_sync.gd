extends Node

# Main facade for gdParameterSync system
# This is the only public API that users should interact with

signal set_registered(set_id: String)
signal set_unregistered(set_id: String)
signal parameter_changed(set_id: String, path: String, value: Variant, source: String)
signal preset_saved(set_id: String, name: String)
signal preset_loaded(set_id: String, name: String)
signal server_discovered(info: Dictionary)
signal server_lost(info: Dictionary)

# Core services
var _store  # ParameterStore
var _router  # MessagingRouter
var _preset_manager  # PresetManager
var _binding_manager  # BindingManager

func _ready():
	print("gdParameterSync v1.0 initializing...")
	
	# Initialize core services
	_store = load("res://addons/gdParameterSync/core/parameter_store.gd").new()
	_router = load("res://addons/gdParameterSync/core/messaging_router.gd").new(_store)
	_preset_manager = load("res://addons/gdParameterSync/core/preset_manager.gd").new(_store)
	_binding_manager = load("res://addons/gdParameterSync/core/binding_manager.gd").new(_store)
	
	# Connect signals
	_store.set_registered.connect(_on_set_registered)
	_store.set_unregistered.connect(_on_set_unregistered)
	_store.parameter_changed.connect(_on_parameter_changed)
	
	print("gdParameterSync initialized successfully")

func _init():
	# Ensure we can be called directly without _ready
	if not _store:
		_store = load("res://addons/gdParameterSync/core/parameter_store.gd").new()
		_router = load("res://addons/gdParameterSync/core/messaging_router.gd").new(_store)
		_preset_manager = load("res://addons/gdParameterSync/core/preset_manager.gd").new(_store)
		_binding_manager = load("res://addons/gdParameterSync/core/binding_manager.gd").new(_store)
		
		# Connect signals
		_store.set_registered.connect(_on_set_registered)
		_store.set_unregistered.connect(_on_set_unregistered)
		_store.parameter_changed.connect(_on_parameter_changed)

# TRES Management
func register_set(param_set) -> void:
	"""Register a ParameterSet resource"""
	_store.register_set(param_set)

func unregister_set(set_id: String) -> void:
	"""Unregister a parameter set"""
	_store.unregister_set(set_id)

# Values
func get_value(set_id: String, param_path: String) -> Variant:
	"""Get current value of a parameter with type safety"""
	return _store.get_value_safe(set_id, param_path)

func get_value_unsafe(set_id: String, param_path: String) -> Variant:
	"""Get current value of a parameter without type safety (legacy)"""
	return _store.get_value(set_id, param_path)

func set_value(set_id: String, param_path: String, value: Variant, source := "local") -> void:
	"""Set parameter value"""
	_router.route_message(set_id, param_path, value, source)

# Presets
func save_user_preset(set_id: String, preset_name := "latest.json") -> void:
	"""Save current values as a user preset"""
	if _preset_manager.save_preset(set_id, preset_name):
		preset_saved.emit(set_id, preset_name)

func load_user_preset(set_id: String, preset_name := "latest.json") -> void:
	"""Load a user preset"""
	if _preset_manager.load_preset(set_id, preset_name):
		preset_loaded.emit(set_id, preset_name)

func reset_to_factory(set_id: String) -> void:
	"""Reset all parameters to factory values"""
	_store.reset_to_factory(set_id)

# Describe (feeds UI, OSCQuery, WS clients)
func describe_set(set_id: String) -> Dictionary:
	"""Get full description of a parameter set"""
	return _store.describe_set(set_id)

func describe_all() -> Dictionary:
	"""Get descriptions of all parameter sets"""
	return _store.describe_all()

func describe_path_oscquery(path: String, attributes := PackedStringArray()) -> Dictionary:
	"""Get OSCQuery descriptor for a specific path"""
	# Parse the path to find the parameter
	var parsed = _parse_osc_path(path)
	if parsed.is_empty():
		return {}
	
	var param_info = _store.get_parameter_info(parsed.set_id, parsed.param_path)
	if param_info.is_empty():
		return {}
	
	# Create OSCQuery descriptor
	var descriptor = {
		"TYPE": _variant_type_to_oscquery_type(param_info.type),
		"VALUE": [param_info.value],
		"ACCESS": "rw" if not param_info.read_only else "r"
	}
	
	# Add requested attributes
	if attributes.is_empty() or "RANGE" in attributes:
		if param_info.min_value != null or param_info.max_value != null:
			var range_dict = {}
			if param_info.min_value != null:
				range_dict["MIN"] = param_info.min_value
			if param_info.max_value != null:
				range_dict["MAX"] = param_info.max_value
			if param_info.enum_values.size() > 0:
				range_dict["VALS"] = param_info.enum_values
			descriptor["RANGE"] = range_dict
	
	if attributes.is_empty() or "DESCRIPTION" in attributes:
		if param_info.description != "":
			descriptor["DESCRIPTION"] = param_info.description
	
	return descriptor

func host_info() -> Dictionary:
	"""Get server host information for OSCQuery"""
	var info = {
		"NAME": "gdParameterSync",
		"OSC_PORT": 8000,  # Default, will be overridden by backend config
		"OSC_TRANSPORT": "UDP",
		"WS_PORT": 8001,
		"EXTENSIONS": {
			"ACCESS": true,
			"VALUE": true,
			"RANGE": true,
			"TYPE": true,
			"DESCRIPTION": true,
			"TAGS": false,
			"EXTENDED_TYPE": false,
			"UNIT": false,
			"CRITICAL": false,
			"CLIPMODE": false,
			"HTML": false
		}
	}
	
	# Get actual ports from enabled backends
	var status = _router.get_status()
	for backend_name in status:
		if backend_name == "osc" and status[backend_name].enabled:
			# TODO: Get actual port from OSC backend
			pass
		elif backend_name == "oscquery" and status[backend_name].enabled:
			# TODO: Get actual ports from OSCQuery backend
			pass
	
	return info

# Backends
func enable_backend(backend_name: String, cfg := {}) -> void:
	"""Enable and configure a backend"""
	# Load and register backend if not already done
	_ensure_backend_loaded(backend_name)
	_router.enable_backend(backend_name, cfg)

func disable_backend(backend_name: String) -> void:
	"""Disable a backend"""
	_router.disable_backend(backend_name)

func is_backend_enabled(backend_name: String) -> bool:
	"""Check if a backend is enabled"""
	return _router.is_backend_enabled(backend_name)

# Zeroconf (TODO: Implement when ZeroconfBackend is ready)
func zeroconf_start(_service_name := "gdParameterSync", _domain := "local") -> void:
	"""Start mDNS service announcement"""
	push_warning("Zeroconf not yet implemented")

func zeroconf_stop() -> void:
	"""Stop mDNS service announcement"""
	push_warning("Zeroconf not yet implemented")

func zeroconf_scan(_timeout_sec := 2.0) -> Array[Dictionary]:
	"""Scan for other gdParameterSync services"""
	push_warning("Zeroconf not yet implemented")
	return []

# Bindings
func bind_parameter(set_id: String, param_path: String, node: NodePath, property: String, opts := {}) -> void:
	"""Bind parameter to node property"""
	_binding_manager.bind_parameter(set_id, param_path, node, property, opts)

func unbind_parameter(set_id: String, param_path: String, node: NodePath, property: String) -> void:
	"""Unbind parameter from node property"""
	_binding_manager.unbind_parameter(set_id, param_path, node, property)

# Private methods
func _ensure_backend_loaded(backend_name: String) -> void:
	"""Load and register a backend if not already loaded"""
	# For now, just create simple debug backends
	# TODO: Load actual backend implementations
	if not _router._backends.has(backend_name):
		var backend = _create_debug_backend(backend_name)
		_router.register_backend(backend_name, backend)

func _create_debug_backend(_backend_name: String) -> RefCounted:
	"""Create a simple debug backend for testing"""
	var backend = RefCounted.new()
	
	# Add required methods
	backend.set_script(load("res://addons/gdParameterSync/backends/debug_backend.gd"))
	
	return backend

func _parse_osc_path(path: String) -> Dictionary:
	"""Parse an OSC path to extract set_id and parameter path"""
	if not path.begins_with("/gdps/"):
		return {}
	
	var parts = path.substr(6).split("/", false, 1)
	if parts.size() < 2:
		return {}
	
	return {
		"set_id": parts[0],
		"param_path": parts[1]
	}

func _variant_type_to_oscquery_type(variant_type: int) -> String:
	"""Convert Godot Variant type to OSCQuery type string"""
	match variant_type:
		TYPE_BOOL:
			return "T"
		TYPE_INT:
			return "i"
		TYPE_FLOAT:
			return "f"
		TYPE_STRING:
			return "s"
		TYPE_VECTOR2:
			return "ff"
		TYPE_VECTOR3:
			return "fff"
		TYPE_COLOR:
			return "ffff"
		_:
			return "s"

# Signal handlers
func _on_set_registered(set_id: String) -> void:
	set_registered.emit(set_id)

func _on_set_unregistered(set_id: String) -> void:
	set_unregistered.emit(set_id)

func _on_parameter_changed(set_id: String, path: String, value: Variant, source: String) -> void:
	parameter_changed.emit(set_id, path, value, source)
