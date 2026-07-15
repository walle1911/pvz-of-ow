extends Node


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		get_tree().quit(2)
		return
	_run(args[0])


func _run(resource_path: String) -> void:
	await get_tree().process_frame
	var game_para: ResourceLevelData = load(resource_path)
	Global.game_para = game_para
	var scene_path: String = Global.main_scene_registry.MainScenesMap[game_para.game_sences]
	get_tree().change_scene_to_file(scene_path)
