extends Node

## 返回选关场景时一次性指定要展示的世界页；读取后由选关场景重置。
var choose_level_page_override := -1

const AdventurePresetsRuntime := preload("res://scripts/resources/level/adventure_level_presets.gd")
const CustomLevelRuntime := preload("res://scripts/resources/level/level_custom_runtime.gd")

## 约定：业务/UI 只通过本脚本暴露的引用访问（如 `Global.user_manager`、`Global.save_service`、`Global.config_service`），
## 不要直接 `get_node` / `%` 访问 Global 场景里的子节点，避免绕过门面、破坏初始化顺序假设。

## 全局注册表（Character/MainScene/Bullet/Item registry）
# 这里提供便捷的 registry 引用给全局使用者
@onready var character_registry: CharacterRegistry = %CharacterRegistry
@onready var main_scene_registry: MainSceneRegistry = %MainSceneRegistry
@onready var bullet_registry: BulletRegistry = %BulletRegistry
@onready var item_registry: ItemRegistry = %ItemRegistry
## 用户管理（已从 Global 拆分）
@onready var user_manager: UserManager = %UserManager
## 存档服务
@onready var save_service: SaveService = %SaveService
## 配置服务（用户音量、控制台）
@onready var config_service: ConfigService = %ConfigService
## 全局游戏状态（金币、花园数据、关卡数据、当前植物、当前僵尸）
@onready var global_game_state: GlobalGameState = %GlobalGameState
## 全局只读数据（图鉴数据、刷怪白名单、罐子白名单等）
@onready var global_read_data: GlobalReadData = %GlobalReadData



func _ready() -> void:
	## 确保游戏启动时鼠标可见（防止上次异常退出时鼠标被隐藏）
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	## 用户数据、冒险运行时缓存和场景缓存统一交给启动封面分帧/异步加载。
	## Autoload._ready 在首帧之前执行；这里做重活会导致启动页尚未显示就长时间黑屏。


var startup_preferences_initialized := false
var startup_has_user := false
var startup_session_initialized := false


func initialize_startup_preferences() -> void:
	if startup_preferences_initialized:
		return

	startup_has_user = user_manager.load_current_user()
	await get_tree().process_frame
	if startup_has_user and not user_manager.curr_user_name.is_empty():
		## 音频总线必须在启动页播放任何声音前应用，避免加载中途响度突变。
		config_service.load_and_apply_config()
	startup_preferences_initialized = true


func initialize_startup_session(progress_callback: Callable = Callable()) -> void:
	if startup_session_initialized:
		_report_startup_progress(progress_callback, 1.0)
		return

	_report_startup_progress(progress_callback, 0.04)
	await initialize_startup_preferences()

	if startup_has_user and not user_manager.curr_user_name.is_empty():
		save_service.load_global_game_data()
		_report_startup_progress(progress_callback, 0.12)
	else:
		_report_startup_progress(progress_callback, 0.12)
	await get_tree().process_frame

	await _warm_adventure_runtime_cache_async(progress_callback, 0.12, 0.96)
	save_service.start_autosave(60.0)
	startup_session_initialized = true
	_report_startup_progress(progress_callback, 1.0)


## 在 `user_manager.curr_user_name` 已更新后，加载该用户下的全局存档与配置（与启动时一致）。
func reload_session_for_current_user() -> void:
	if user_manager.curr_user_name.is_empty():
		return
	save_service.load_global_game_data()
	config_service.load_and_apply_config()
	## 冒险卡池包含按用户存档解锁的 Boss 奖励，切换用户后必须同步重建。
	refresh_adventure_runtime_cache()

var main_game:MainGameManager
var game_para:ResourceLevelData

## 从开发者工具返回主菜单时，主菜单应继续停留在开发者模式。
var return_to_developer_mode := false
## 标记当前关卡是否来自开发者入口；用于开发者选关和“返回工坊”等界面，不再限制全局数值调整。
var developer_level_adjustments_active := false
## 从开发者选关进入实战时保留关卡源数据，供右上角“编辑”直接交给关卡工坊。
var developer_workshop_level_source: Dictionary = {}
## 开发者模式礼盒入口正在浏览四个内置测试关卡。
var developer_gift_test_levels_active := false
## 关卡工坊从卡片右键进入数值编辑器时，保存目标角色和返回后的选卡界面状态。
var numerical_editor_context: Dictionary = {}
var level_workshop_return_state: Dictionary = {}
## 地图工坊当前只开放普通关卡编辑；保留字段供现有编辑器内部判断。
var level_workshop_edit_mode := "normal"
## 冒险预设选择状态；主菜单的“开始冒险吧”固定进入 normal。
var adventure_mainline_mode := "normal"
var adventure_runtime_cache: Dictionary = {}
var adventure_scene_cache: Dictionary[String, PackedScene] = {}


func _warm_adventure_runtime_cache() -> void:
	## 把正式关卡字典转运行时资源的重活放到启动阶段，选关页和关卡点击只复制缓存。
	for mainline_mode in ["normal", "chessboard"]:
		var mode_cache: Dictionary = {}
		for preset in AdventurePresetsRuntime.list_formal_presets(mainline_mode):
			var preset_id := str((preset as Dictionary).get("id", ""))
			if preset_id.is_empty():
				continue
			var source := AdventurePresetsRuntime.build_formal_level(preset_id)
			var built := CustomLevelRuntime.build_game_para(source)
			if built["ok"]:
				mode_cache[preset_id] = {
					"source": source,
					"game_para": built["game_para"],
				}
		adventure_runtime_cache[mainline_mode] = mode_cache


func _warm_adventure_runtime_cache_async(
		progress_callback: Callable,
		progress_start: float,
		progress_end: float) -> void:
	var presets_by_mode: Dictionary = {}
	var total_presets := 0
	for mainline_mode in ["normal", "chessboard"]:
		var presets := AdventurePresetsRuntime.list_formal_presets(mainline_mode)
		presets_by_mode[mainline_mode] = presets
		total_presets += presets.size()

	var completed_presets := 0
	for mainline_mode in ["normal", "chessboard"]:
		var mode_cache: Dictionary = {}
		for preset in presets_by_mode[mainline_mode]:
			var preset_id := str((preset as Dictionary).get("id", ""))
			if not preset_id.is_empty():
				var source := AdventurePresetsRuntime.build_formal_level(preset_id)
				var built := CustomLevelRuntime.build_game_para(source)
				if built["ok"]:
					mode_cache[preset_id] = {
						"source": source,
						"game_para": built["game_para"],
					}
			completed_presets += 1
			var ratio := float(completed_presets) / maxf(float(total_presets), 1.0)
			_report_startup_progress(
				progress_callback,
				lerpf(progress_start, progress_end, ratio)
			)
			await get_tree().process_frame
		adventure_runtime_cache[mainline_mode] = mode_cache


func _report_startup_progress(progress_callback: Callable, progress: float) -> void:
	if progress_callback.is_valid():
		progress_callback.call(clampf(progress, 0.0, 1.0))


func refresh_adventure_runtime_cache() -> void:
	adventure_runtime_cache.clear()
	_warm_adventure_runtime_cache()


func cached_adventure_level(mainline_mode: String, preset_id: String) -> Dictionary:
	var mode_cache := adventure_runtime_cache.get(mainline_mode, {}) as Dictionary
	var cached := mode_cache.get(preset_id, {}) as Dictionary
	if cached.is_empty():
		return {"ok": false, "source": {}, "game_para": null}
	var cached_para := cached.get("game_para") as ResourceLevelData
	return {
		"ok": cached_para != null,
		"source": cached.get("source", {}),
		"game_para": cached_para.duplicate_runtime() if cached_para != null else null,
	}


func _warm_adventure_scene_cache() -> void:
	## 把“开始冒险”和关卡按钮会切换到的场景文件也在启动阶段解析并持有。
	for scene_path in adventure_scene_cache_paths():
		var packed_scene := load(scene_path) as PackedScene
		if packed_scene != null:
			adventure_scene_cache[scene_path] = packed_scene


func adventure_scene_cache_paths() -> PackedStringArray:
	## 启动封面使用同一份清单做线程加载；其他场景仍可通过 change_scene_to_cached 回退同步加载。
	var paths := PackedStringArray()
	for scene_id in [
		MainSceneRegistry.MainScenes.StartMenu,
		MainSceneRegistry.MainScenes.ChooseLevelAdventure,
		MainSceneRegistry.MainScenes.MainGameFront,
		MainSceneRegistry.MainScenes.MainGameBack,
		MainSceneRegistry.MainScenes.MainGameRoof,
		MainSceneRegistry.MainScenes.MainGameChessboardFront,
		MainSceneRegistry.MainScenes.MainGameChessboardPool,
	]:
		paths.append(str(main_scene_registry.MainScenesMap[scene_id]))
	paths.append("res://scenes/card_slot/card_slot_norm.tscn")
	return paths


func cache_adventure_scene(scene_path: String, packed_scene: PackedScene) -> void:
	if packed_scene != null:
		adventure_scene_cache[scene_path] = packed_scene


func change_scene_to_cached(scene_path: String) -> Error:
	var packed_scene := adventure_scene_cache.get(scene_path) as PackedScene
	if packed_scene != null:
		return get_tree().change_scene_to_packed(packed_scene)
	return get_tree().change_scene_to_file(scene_path)

## 游戏倍速
var time_scale := 1.0
