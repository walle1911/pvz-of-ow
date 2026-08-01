@tool
extends EditorPlugin

const WhitelistPanel := preload("res://addons/numerical_whitelist_editor/whitelist_panel.gd")
const BAKE_MENU_ITEM := "开发者数值：烘焙到角色 .tscn"

var panel: Control


func _enter_tree() -> void:
	panel = WhitelistPanel.new()
	panel.name = "数值白名单与烘焙"
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, panel)
	add_tool_menu_item(BAKE_MENU_ITEM, _bake_all_numerical_adjustments)


func _exit_tree() -> void:
	remove_tool_menu_item(BAKE_MENU_ITEM)
	if panel != null:
		remove_control_from_docks(panel)
		panel.queue_free()


func _bake_all_numerical_adjustments() -> void:
	if panel != null and panel.has_method("bake_all_numerical_adjustments"):
		panel.call("bake_all_numerical_adjustments")
