extends SceneTree

const UserPaths := preload("res://scripts/resources/user_data_paths.gd")


func _init() -> void:
	var failures: Array[String] = []
	_expect_suffix(UserPaths.path("current_user.ini"), "存档/current_user.ini", failures)
	_expect_suffix(UserPaths.path("player_a/GlobalSaveGame.json"), "存档/player_a/GlobalSaveGame.json", failures)
	_expect_suffix(UserPaths.path("level_drafts/test.json"), "开发者包/level_drafts/test.json", failures)
	_expect_suffix(UserPaths.path("adventure_levels/adventure_1_1.json"), "开发者包/adventure_levels/adventure_1_1.json", failures)
	_expect_suffix(UserPaths.path("numerical_adjustments.json"), "开发者包/numerical_adjustments.json", failures)
	_expect_suffix(UserPaths.developer_package_root_path(), "开发者包", failures)
	if failures.is_empty():
		print("User data path classification test: passed")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect_suffix(actual: String, expected: String, failures: Array[String]) -> void:
	if not actual.replace("\\", "/").ends_with(expected):
		failures.append("路径分类错误：%s，预期结尾：%s" % [actual, expected])
