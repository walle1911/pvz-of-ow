@tool
extends EditorPlugin

const WhitelistPanel := preload("res://addons/numerical_whitelist_editor/whitelist_panel.gd")

var panel: Control


func _enter_tree() -> void:
	panel = WhitelistPanel.new()
	panel.name = "植物数值白名单"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)


func _exit_tree() -> void:
	if panel != null:
		remove_control_from_docks(panel)
		panel.queue_free()
