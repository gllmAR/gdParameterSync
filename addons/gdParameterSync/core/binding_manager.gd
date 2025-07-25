class_name BindingManager
extends RefCounted

var _store

func _init(store):
	_store = store

func bind_parameter(set_id: String, param_path: String, node: NodePath, property: String, _opts: Dictionary) -> void:
	"""Bind parameter to node property"""
	print("Binding %s/%s to %s.%s" % [set_id, param_path, node, property])
	# TODO: Implement actual binding

func unbind_parameter(set_id: String, param_path: String, node: NodePath, property: String) -> void:
	"""Unbind parameter from node property"""
	print("Unbinding %s/%s from %s.%s" % [set_id, param_path, node, property])
	# TODO: Implement actual unbinding
