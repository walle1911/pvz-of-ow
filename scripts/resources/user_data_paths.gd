extends RefCounted
class_name UserDataPaths

## 导出程序在游戏旁只暴露两个玩家数据分类；编辑器在 Godot user:// 下使用相同结构。
const SAVE_DIR_NAME := "存档"
const DEVELOPER_PACKAGE_DIR_NAME := "开发者包"
const LEGACY_PORTABLE_DIR_NAME := "user_data"

const DEVELOPER_PATH_PREFIXES := [
	"adventure_levels",
	"formal_adventure_levels",
	"level_drafts",
	"recording_5757_snapshots",
]
const DEVELOPER_FILES := [
	"developer_package_backup.json",
	"numerical_adjustments.json",
	"recording_5757_director_layout.json",
]


static func root_path() -> String:
	if OS.has_feature("editor"):
		return "user://"
	var executable_dir := OS.get_executable_path().get_base_dir()
	## macOS 可执行文件位于 .app/Contents/MacOS，存档应放在 .app 同级而不是包体内部。
	if OS.has_feature("macos") and executable_dir.ends_with(".app/Contents/MacOS"):
		executable_dir = executable_dir.get_base_dir().get_base_dir().get_base_dir()
	var save_root := executable_dir.path_join(SAVE_DIR_NAME)
	var developer_root := executable_dir.path_join(DEVELOPER_PACKAGE_DIR_NAME)
	var save_error := DirAccess.make_dir_recursive_absolute(save_root)
	var developer_error := DirAccess.make_dir_recursive_absolute(developer_root)
	if save_error == OK and developer_error == OK:
		return executable_dir
	push_warning("游戏目录不可写，玩家数据回退到系统 user://，错误码 %s/%s" % [str(save_error), str(developer_error)])
	return "user://"


static func path(relative_path: String = "") -> String:
	var clean := relative_path.replace("\\", "/").trim_prefix("/")
	var category_root := developer_package_root_path() if _is_developer_path(clean) else save_root_path()
	return category_root if clean.is_empty() else category_root.path_join(clean)


static func save_root_path() -> String:
	return root_path().path_join(SAVE_DIR_NAME)


static func developer_package_root_path() -> String:
	return root_path().path_join(DEVELOPER_PACKAGE_DIR_NAME)


static func legacy_path(relative_path: String = "") -> String:
	var clean := relative_path.replace("\\", "/").trim_prefix("/")
	return "user://" if clean.is_empty() else "user://" + clean


static func _legacy_portable_path(relative_path: String = "") -> String:
	if OS.has_feature("editor"):
		return ""
	var executable_dir := OS.get_executable_path().get_base_dir()
	if OS.has_feature("macos") and executable_dir.ends_with(".app/Contents/MacOS"):
		executable_dir = executable_dir.get_base_dir().get_base_dir().get_base_dir()
	var legacy_root := executable_dir.path_join(LEGACY_PORTABLE_DIR_NAME)
	var clean := relative_path.replace("\\", "/").trim_prefix("/")
	return legacy_root if clean.is_empty() else legacy_root.path_join(clean)


## 便携文件不存在时读取旧版 user://，保存则始终调用 path() 写入新位置。
static func read_path(relative_path: String) -> String:
	var preferred := path(relative_path)
	if FileAccess.file_exists(preferred):
		return preferred
	var legacy_portable := _legacy_portable_path(relative_path)
	if not legacy_portable.is_empty() and FileAccess.file_exists(legacy_portable):
		return legacy_portable
	var legacy := legacy_path(relative_path)
	return legacy if preferred != legacy and FileAccess.file_exists(legacy) else preferred


static func read_directory_path(relative_path: String) -> String:
	var preferred := path(relative_path)
	if DirAccess.dir_exists_absolute(preferred):
		return preferred
	var legacy_portable := _legacy_portable_path(relative_path)
	if not legacy_portable.is_empty() and DirAccess.dir_exists_absolute(legacy_portable):
		return legacy_portable
	var legacy := legacy_path(relative_path)
	return legacy if preferred != legacy and DirAccess.dir_exists_absolute(legacy) else preferred


static func ensure_directory(relative_path: String = "") -> Error:
	return DirAccess.make_dir_recursive_absolute(path(relative_path))


static func ensure_player_data_roots() -> Error:
	var save_error := DirAccess.make_dir_recursive_absolute(save_root_path())
	if save_error != OK:
		return save_error
	return DirAccess.make_dir_recursive_absolute(developer_package_root_path())


## 首次运行便携版时复制旧版 user:// 数据；只补缺失文件，不覆盖也不删除旧存档。
static func migrate_legacy_player_data(user_names: Array[String]) -> void:
	for relative_file in [
		"current_user.ini",
		"numerical_adjustments.json",
		"developer_package_backup.json",
		"recording_5757_director_layout.json",
	]:
		_copy_legacy_file(relative_file)
	for relative_directory in [
		"level_drafts",
		"adventure_levels",
		"formal_adventure_levels",
	]:
		_copy_legacy_directory(relative_directory)
	for user_name in user_names:
		_copy_legacy_directory(str(user_name))


static func _copy_legacy_file(relative_path: String) -> void:
	var target := path(relative_path)
	if FileAccess.file_exists(target):
		return
	for source in _legacy_candidates(relative_path):
		if source == target or not FileAccess.file_exists(source):
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var copy_error := DirAccess.copy_absolute(ProjectSettings.globalize_path(source), target)
		if copy_error != OK:
			push_warning("迁移旧存档失败：%s，错误码 %s" % [relative_path, str(copy_error)])
		return


static func _copy_legacy_directory(relative_path: String) -> void:
	for source in _legacy_candidates(relative_path):
		if source != path(relative_path) and DirAccess.dir_exists_absolute(source):
			_copy_directory_contents(source, path(relative_path))


static func _copy_directory_contents(source: String, target: String) -> void:
	var source_dir := DirAccess.open(source)
	if source_dir == null:
		return
	DirAccess.make_dir_recursive_absolute(target)
	for file_name in source_dir.get_files():
		var target_file := target.path_join(file_name)
		if FileAccess.file_exists(target_file):
			continue
		var copy_error := DirAccess.copy_absolute(
			ProjectSettings.globalize_path(source.path_join(file_name)),
			target_file
		)
		if copy_error != OK:
			push_warning("迁移旧存档文件失败：%s，错误码 %s" % [file_name, str(copy_error)])
	for directory_name in source_dir.get_directories():
		_copy_directory_contents(source.path_join(directory_name), target.path_join(directory_name))


static func _legacy_candidates(relative_path: String) -> Array[String]:
	var result: Array[String] = []
	var legacy_portable := _legacy_portable_path(relative_path)
	if not legacy_portable.is_empty():
		result.append(legacy_portable)
	result.append(legacy_path(relative_path))
	return result


static func _is_developer_path(relative_path: String) -> bool:
	if DEVELOPER_FILES.has(relative_path):
		return true
	for prefix in DEVELOPER_PATH_PREFIXES:
		if relative_path == prefix or relative_path.begins_with(prefix + "/"):
			return true
	return false
