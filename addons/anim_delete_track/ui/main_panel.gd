@tool
extends PanelContainer
class_name ADTPanelMainContainer


const MAX_HISTORY = 5
const CONFIG_PATH = "user://ADT_Path.cfg"

@onready var anim_path_option = %anim_path_option
@onready var anim_select_button = %anim_select_button
@onready var run_button = %run_button

@onready var cb_visible = %cb_visible
@onready var cb_texture = %cb_texture
@onready var cb_self_modulate = %cb_self_modulate

@onready var status_label = %StatusLabel

var plugin_interface: EditorPlugin

func _ready():
	_load_history_list("anim_path", anim_path_option)

	anim_select_button.pressed.connect(_on_select_anim_folder)
	run_button.pressed.connect(_on_run_exe)


func _on_select_anim_folder():
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_RESOURCES
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	dialog.dir_selected.connect(func(path):
		var fixed_path = path
		if not fixed_path.ends_with("/"):
			fixed_path += "/"
		_add_to_history("anim_path", fixed_path, anim_path_option)
	)
	add_child(dialog)
	dialog.popup_centered()


func _add_to_history(key: String, path: String, option: OptionButton):
	var cfg = ConfigFile.new()
	cfg.load(CONFIG_PATH)
	var history := cfg.get_value("paths", key + "_history", [])

	# 移除重复项
	if path in history:
		history.erase(path)
	# 添加新路径到最前
	history.insert(0, path)
	# 保留最多 MAX_HISTORY 条
	history = history.slice(0, MAX_HISTORY)

	# 保存该 key 的更新数据
	cfg.set_value("paths", key + "_history", history)
	cfg.save(CONFIG_PATH)

	# 刷新 UI 下拉列表
	option.clear()
	for item in history:
		option.add_item(item)

	option.tooltip_text = history[0]
	option.select(0)

func _load_history_list(key: String, option: OptionButton):
	var cfg = ConfigFile.new()
	var err = cfg.load(CONFIG_PATH)
	if err != OK:
		return

	var history := cfg.get_value("paths", key + "_history", [])

	# 只保留最多 MAX_HISTORY 条
	history = history.slice(0, MAX_HISTORY)

	option.clear()
	for item in history:
		option.add_item(item)
	if history.size() > 0:
		option.select(0)
		option.tooltip_text = history[0]

func _on_run_exe():
	var anim_arg = anim_path_option.get_item_text(anim_path_option.get_selected_id()).strip_edges()

	if anim_arg == "":
		push_error("请填写完整的参数路径")
		return
	_on_dir_selected(anim_arg)


	## 更新全局文件
	if plugin_interface:
		plugin_interface.refresh_resources()


func _on_dir_selected(dir_path: String):
	status_label.text = "处理中: " + dir_path
	_process_directory(dir_path)
	status_label.text = Time.get_datetime_string_from_system(true) +  " ✅ 完成" + dir_path

func _process_directory(path: String):
	var dir = DirAccess.open(path)
	if not dir:
		status_label.text = "❌ 无法打开目录: " + path
		return

	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if dir.current_is_dir():
			if file_name != "." and file_name != "..":
				_process_directory(path + "/" + file_name)
		else:
			if file_name.ends_with(".tres") or file_name.ends_with(".res"):
				var full_path = path + "/" + file_name
				_process_animation_file(full_path)
		file_name = dir.get_next()
	dir.list_dir_end()

func _process_animation_file(file_path: String):
	var anim_res := ResourceLoader.load(file_path)
	if anim_res is Animation:
		var modified := false
		var to_remove := []

		# 收集需要移除的属性
		var targets := []
		if cb_visible.button_pressed:
			targets.append("visible")
		if cb_texture.button_pressed:
			targets.append("texture")
		if cb_self_modulate.button_pressed:
			targets.append("self_modulate")

		for i in range(anim_res.get_track_count() - 1, -1, -1):
			if anim_res.track_get_type(i) == Animation.TYPE_VALUE:
				var track_path: NodePath = anim_res.track_get_path(i)
				if track_path.get_subname_count() > 0:
					var last_prop: String = str(track_path.get_subname(track_path.get_subname_count() - 1))
					if last_prop in targets:
						anim_res.remove_track(i)
						modified = true
		if modified:
			ResourceSaver.save(anim_res, file_path)
