@tool
extends EditorPlugin

const PANEL := preload("res://addons/pvz_level_editor/level_editor_panel.gd")
var panel: Control

func _enter_tree() -> void:
	panel = PANEL.new()
	add_control_to_bottom_panel(panel, "PVZ 关卡编辑器")

func _exit_tree() -> void:
	if panel != null:
		remove_control_from_bottom_panel(panel)
		panel.queue_free()
