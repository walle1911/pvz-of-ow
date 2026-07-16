extends Node

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

	## 读取当前用户名
	var is_have_user := user_manager.load_current_user()
	if is_have_user and not user_manager.curr_user_name.is_empty():
		reload_session_for_current_user()
	## 创建全局数据自动存档计时器（由 SaveService 负责）
	save_service.start_autosave(60.0)


## 在 `user_manager.curr_user_name` 已更新后，加载该用户下的全局存档与配置（与启动时一致）。
func reload_session_for_current_user() -> void:
	if user_manager.curr_user_name.is_empty():
		return
	save_service.load_global_game_data()
	config_service.load_and_apply_config()

var main_game:MainGameManager
var game_para:ResourceLevelData

## 从开发者工具返回主菜单时，主菜单应继续停留在开发者模式。
var return_to_developer_mode := false
## 只有从开发者模式进入的自定义关卡或地图工坊试玩才允许应用数值调整。
var developer_level_adjustments_active := false
## 从开发者选关进入实战时保留关卡源数据，供右上角“编辑”直接交给关卡工坊。
var developer_workshop_level_source: Dictionary = {}
## 地图工坊当前只开放普通关卡编辑；保留字段供现有编辑器内部判断。
var level_workshop_edit_mode := "normal"
## 冒险预设选择状态；主菜单的“开始冒险吧”固定进入 normal。
var adventure_mainline_mode := "normal"

## 游戏倍速
var time_scale := 1.0
