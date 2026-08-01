extends Node2D
class_name MainGameManager

#region 游戏测试
@export_group("测试相关")
## 游戏时测试方便修改阳光数
@export var test_change_sun_value := 9999:
	set(value):
		test_change_sun_value = value
		EventBus.push_event("test_change_sun_value", [value])

## 所有僵尸死亡
@export var test_death_all_zombie:=false:
	set(value):
		print("设置值")
		EventBus.push_event("test_death_all_zombie")

## 游戏速度
## INFO: 游戏速度超过8会代码执行顺序会有问题，可能会导致一些莫名其妙的bug
@export var test_time_scale:=1:
	set(value):
		test_time_scale = value
		Engine.time_scale = test_time_scale

@export_subgroup("调试预设卡片")
## 直接运行测试场景时覆盖关卡资源中的预选植物卡，留空则使用关卡资源原配置
@export var test_pre_choosed_card_list_plant: Array[CharacterRegistry.PlantType] = []
## 直接运行测试场景时覆盖关卡资源中的预选僵尸卡，留空则使用关卡资源原配置
@export var test_pre_choosed_card_list_zombie: Array[CharacterRegistry.ZombieType] = []
## 直接运行测试场景时覆盖最大卡槽数量，固定8个，超过上限自动增加
@export_range(1, 15) var test_max_choosed_card_num: int = 8
## 直接运行测试场景时显示植物和僵尸血量，便于观察调参结果
@export var test_show_hp_label := true

@export_group("5757导演设置")
## F4 导演卡和导演台按钮放置的僵尸等比缩放比例；1.0 为原尺寸。
@export_range(0.1, 2.0, 0.05) var director_placed_zombie_scale := 0.8
## 启用后，D.Va 毁灭菇的幼体不再随机弹射，只尝试落在指定的斜前方格。
@export var dva_baby_use_fixed_diagonal_cell := false
## x 为行偏移，y 为列偏移；(-1, 1) 表示行 -1、列 +1 的斜前一格。
@export var dva_baby_fixed_diagonal_offset := Vector2i(-1, 1)

#endregion
#region 游戏管理器
@onready var manager: Node = %Manager
@onready var card_manager: CardManager = %CardManager
@onready var hand_manager: HandManager = %HandManager
@onready var zombie_manager: ZombieManager = %ZombieManager
@onready var game_item_manager: GameItemManager = %GameItemManager
@onready var plant_cell_manager: PlantCellManager = %PlantCellManager
@onready var background_manager: BackgroundManager = %BackgroundManager
@onready var day_suns_manager: DaySunsManagner = %DaySunsManager
@onready var drop_item_manager: DropItemManager = %DropItemManager

#endregion

#region UI元素、相机
@onready var camera_2d: MainGameCamera = %Camera2D
@onready var ui_remind_word: UIRemindWord = %UIRemindWord
@onready var level_info: LevelInfo = $CanvasLayerUI/LevelInfo

#endregion

#region 游戏主元素
@onready var canvas_layer_temp: CanvasLayer = %CanvasLayerTemp
@onready var canvas_layer_ui: CanvasLayer = %CanvasLayerUI

## 阳光收集位置,出战卡槽时更新
var marker_2d_sun_target: Marker2D
@onready var marker_2d_sun_target_default: Marker2D = %Marker2DSunTargetDefault

## 将子弹\爆炸\阳光
@onready var bullets: Node2D = %Bullets
@onready var bombs: Node2D = %Bombs
@onready var suns: Node2D = %Suns

@onready var main_game_menu_button: BaseButton = %MainGameMenuButton
var workshop_return_button: BaseButton
## 卡槽
@onready var card_slot_root: CardSlotRoot = %CardSlotRoot
## 僵尸进家panel
@onready var panel_zombie_go_home: Panel = %PanelZombieGoHome
@onready var marker_2d_zombie_go_home: Marker2D = %Marker2DZombieGoHome

## 全局检测组件,用于检测敌人
##TODO:可能会用于检测敌人离开场景后删除
@onready var detect_component_global: DetectComponent = %DetectComponentGlobal

#endregion

#region 锤子进入节点鼠标显示
## 鼠标是否一致显示,当有锤子时
var is_mouse_visibel_on_hammer:bool = false
@onready var node_mouse_appear_have_hammer:Array[Control] = [
	## 卡槽
	%CardSlotRoot,
	## 菜单
	%MainGameMenuButton, %MainGameMenuOptionDialog, %Dialog
]

#endregion

#region bgm
@export_group("bgm")
## 选卡bgm
var bgm_choose_card: AudioStream = preload("res://assets/audio/BGM/choose_card.mp3")
## 主游戏bgm
var bgm_main_game: AudioStream
#endregion


#region 主游戏运行阶段
enum E_MainGameProgress{
	NONE,			## 无
	CHOOSE_CARD,	## 选卡界面
	PREPARE,		## 准备阶段(红字)
	MAIN_GAME,		## 游戏阶段
	GAME_OVER,		## 游戏结束阶段
	RE_CHOOSE_CARD,	## 多轮游戏重新选卡阶段
}

## 重新选卡是否暂停
var is_pause_on_re_choose_card:=false
var main_game_progress := E_MainGameProgress.NONE:
	set(value):
		main_game_progress = value
		EventBus.push_event("main_game_progress_update", [value])

#endregion

#region 游戏数据
@export_group("地图特殊地形")
## 斜面(屋顶)
@export var main_game_slope:MainGameSlope
## 雪人僵尸逃跑概率(默认不使用该概率,赌狗小游戏使用)
var p_yeti_run :float= -1
#endregion

#region 游戏参数
@export_group("本局游戏参数")
## 正常进入游戏会自动更新对应关卡数据,直接进入该场景会使用该关卡数据,并设置is_test=true
@export var game_para : ResourceLevelData
## 若为true,选卡无冷却
var is_test := false
## 当前轮次
var curr_game_round = 1:
	set(value):
		curr_game_round = value
		level_info.set_round(curr_game_round)

## 初始化时是否存档
var is_save_game_data_on_init:=false

#endregion

#endregion
func _enter_tree() -> void:
	set_game_para()

## 进入树时更新游戏参数，子管理器赋值对应的游戏参数
func set_game_para() -> void:
	Global.main_game = self
	## 先获取当前关卡参数
	if Global.game_para != null:
		game_para = Global.game_para
	else:
		is_test = true
	if game_para == null:
		push_error(
			"主游戏缺少关卡数据 ResourceLevelData：请从选关流程进入，或在编辑器中为该主游戏场景根节点指定「本局游戏参数 / game_para」。"
		)
		queue_free()
		return
	apply_test_card_overrides()

func apply_test_card_overrides() -> void:
	if not is_test:
		return
	if test_pre_choosed_card_list_plant.is_empty() \
	and test_pre_choosed_card_list_zombie.is_empty() \
	and test_max_choosed_card_num <= 0:
		return
	game_para = game_para.duplicate(true)
	if not test_pre_choosed_card_list_plant.is_empty():
		game_para.pre_choosed_card_list_plant = test_pre_choosed_card_list_plant.duplicate()
	if not test_pre_choosed_card_list_zombie.is_empty():
		game_para.pre_choosed_card_list_zombie = test_pre_choosed_card_list_zombie.duplicate()
	if test_max_choosed_card_num > 0:
		game_para.max_choosed_card_num = test_max_choosed_card_num

func apply_test_display_overrides() -> void:
	if not is_test or not test_show_hp_label:
		return
	Global.config_service.display_plant_HP_label = true
	Global.config_service.display_zombie_HP_label = true

func _exit_tree() -> void:
	## 确保退出主游戏场景时鼠标恢复可见（防止锤子等工具残留隐藏状态）
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	## 避免切场景后主游戏节点已释放，Global 仍持有野指针
	if Global.main_game == self:
		Global.main_game = null

func _ready() -> void:
	apply_test_display_overrides()
	game_para.init_para()
	_setup_workshop_return_button()
	## 多轮游戏并且有存档
	is_save_game_data_on_init = game_para.game_round != 1 and game_para.save_game_data_main_game != null

	## 订阅总线事件
	event_bus_subscribe()
	## 默认禁用全局敌人检测组件(追踪子弹调用, 放置追踪植物时启用,追踪植物死亡时,检测是否关闭)
	detect_component_global.disable_component(ComponentNormBase.E_IsEnableFactor.Global)
	## 主游戏进程
	main_game_progress = E_MainGameProgress.CHOOSE_CARD
	## 播放选卡bgm
	SoundManager.play_bgm(bgm_choose_card)
	## 连接子节点信号
	signal_connect()
	## 初始化子管理器
	init_manager()
	## 初始化游戏背景音乐
	_init_game_BGM()

	## 若有存档
	if is_save_game_data_on_init:
		load_game_main_game()
		start_next_round_game()
	else:

		## 如果有戴夫对话
		if game_para.crazy_dave_dialog:
			var crazy_dave:CrazyDave = SceneRegistry.CRAZY_DAVE.instantiate()
			crazy_dave.init_dave(game_para.crazy_dave_dialog)
			canvas_layer_ui.add_child(crazy_dave)
			await crazy_dave.signal_dave_leave_end
			crazy_dave.queue_free()

		## 如果看展示僵尸
		if game_para.look_show_zombie:
			## 创建展示僵尸，等待一秒移动相机
			zombie_manager.create_prepare_show_zombies()
			await get_tree().create_timer(1.0).timeout
			await camera_2d.move_look_zombie()
			## 如果可以选卡
			if game_para.can_choosed_card:
				card_manager.card_slot_appear_choose()
			else:
				await get_tree().create_timer(1.0).timeout
				no_choosed_card_start_game()
		else:
			main_game_start()

## 主游戏管理器事件总线订阅
func event_bus_subscribe():
	## 手持锤子时，修改鼠标离开ui是否显示鼠标
	EventBus.subscribe("change_is_mouse_visibel_on_hammer", change_is_mouse_visibel_on_hammer)
	## 僵尸进家
	EventBus.subscribe("zombie_go_home", on_zombie_go_home)
	## 创建奖杯
	EventBus.subscribe("create_trophy", create_trophy)
	## 游戏胜利
	EventBus.subscribe("win_main_game", win_main_game)
	## 正常选卡结束后开始游戏
	EventBus.subscribe("card_slot_norm_start_game", choosed_card_start_game)
	## 多轮游戏触发下一轮游戏
	EventBus.subscribe("start_next_round_game", start_next_round_game)
	## 更新阳光收集位置
	EventBus.subscribe("update_marker_2d_sun_target", update_marker_2d_sun_target)


## 更新阳光收集位置
func update_marker_2d_sun_target(new_marker_2d_sun_target:Marker2D):
	marker_2d_sun_target = new_marker_2d_sun_target

#region 游戏关卡初始化
## 初始化管理器
func init_manager():
	card_manager.init_manager()
	plant_cell_manager.init_manager()
	game_item_manager.init_manager()
	hand_manager.init_manager()
	zombie_manager.init_manager()
	background_manager.init_manager()
	drop_item_manager.init_manager()
	day_suns_manager.init_manager()
	print("info:管理器初始化完成")

## 信号连接
func signal_connect():
	if game_para.is_hammer:
		for ui_node:Control in node_mouse_appear_have_hammer:
			ui_node.mouse_entered.connect(mouse_appear_have_hammer)
			ui_node.mouse_exited.connect(mouse_disappear_have_hammer)


func _setup_workshop_return_button() -> void:
	var is_workshop_playtest: bool = game_para.game_mode == MainSceneRegistry.MainScenes.LevelWorkshop
	var is_developer_editable_level: bool = (
		Global.developer_level_adjustments_active
		and not Global.developer_workshop_level_source.is_empty()
	)
	if not is_workshop_playtest and not is_developer_editable_level:
		return
	## 复制菜单键的完整样式、脚本和按压动画，但不复制它原有的“打开菜单”信号。
	## Node.DUPLICATE_SIGNALS = 1，因此使用 14 保留组、脚本和实例化信息。
	workshop_return_button = main_game_menu_button.duplicate(14) as BaseButton
	workshop_return_button.name = "WorkshopReturnButton"
	workshop_return_button.unique_name_in_owner = false
	main_game_menu_button.get_parent().add_child(workshop_return_button)
	workshop_return_button.position.x -= 108.0
	workshop_return_button.tooltip_text = "返回关卡工坊编辑"
	var label := workshop_return_button.get_node_or_null("Label") as Label
	if label != null:
		label.text = "编辑"
	workshop_return_button.pressed.connect(_return_to_level_workshop)
	node_mouse_appear_have_hammer.append(workshop_return_button)


func _return_to_level_workshop() -> void:
	EventBus.push_event("change_is_mouse_visibel_on_hammer", true)
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale
	Global.developer_level_adjustments_active = false
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.LevelWorkshop])

## 初始化游戏bgm
func _init_game_BGM():
	#print(game_para.game_BGM)
	var path_bgm_game = ConstLevelData.GameBGMMap[game_para.game_BGM]
	bgm_main_game = load(path_bgm_game) as AudioStream


## 不用选择卡片进行的流程
func no_choosed_card_start_game():
	await get_tree().create_timer(2.0).timeout
	## 相机移动回游戏场景
	await camera_2d.move_back_ori()
	main_game_start()
#endregion

#region 多轮游戏下一轮
func start_next_round_game():
	## 多轮游戏僵尸管理器计时器触发时，判断是否为最后一轮
	if curr_game_round == game_para.game_round:
		return
	print("-----------------开始下一轮游戏---------------")
	print("下一轮次：", curr_game_round + 1)
	## 先存档
	save_game_main_game()
	## 等待3秒后进行下一轮
	await get_tree().create_timer(3).timeout
	## 播放选卡bgm
	if game_para.look_show_zombie:
		## 重新选卡阶段暂停游戏
		start_pause_on_re_choose_card_progress()
		print("----------------播放选卡bgm", bgm_choose_card)
		SoundManager.play_bgm(bgm_choose_card)
	curr_game_round += 1
	main_game_progress = E_MainGameProgress.RE_CHOOSE_CARD
	## 暂停天降阳光
	if game_para.is_day_sun:
		day_suns_manager.pause_day_sun()
	## 更新卡槽数据
	card_manager.start_next_game_card_manager_update()
	## 更新背景,浓雾回退
	background_manager.start_next_game_background_manager_update()
	## 更新僵尸管理器
	zombie_manager.start_next_game_zombie_mananger_update()
	## 更新植物格子数据，（创建罐子） 清除植物数据需要等待两帧
	await plant_cell_manager.start_next_game_plant_cell_manager_update()
	game_item_manager.start_next_game_game_item_manager_update()

	## 如果看展示僵尸
	if game_para.look_show_zombie:
		## 创建展示僵尸，等待一秒移动相机
		zombie_manager.create_prepare_show_zombies()
		await get_tree().create_timer(1.0).timeout
		await camera_2d.move_look_zombie()
		## 如果可以选卡
		if game_para.can_choosed_card:
			card_manager.card_slot_appear_choose()
		else:
			await get_tree().create_timer(1.0).timeout
			no_choosed_card_start_game()
	else:
		main_game_start()


## 下轮选卡时暂停游戏
func start_pause_on_re_choose_card_progress():
	is_pause_on_re_choose_card = true
	## 设置相机可以移动
	camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	card_slot_root.process_mode = Node.PROCESS_MODE_ALWAYS
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)

## 下轮选卡结束时取消暂停游戏
func end_pause_on_re_choose_card_progress():
	is_pause_on_re_choose_card = false
	## 设置相机可以移动
	camera_2d.process_mode = Node.PROCESS_MODE_INHERIT
	card_slot_root.process_mode = Node.PROCESS_MODE_INHERIT
	TreePauseManager.end_tree_pause(TreePauseManager.E_PauseFactor.ReChooseCard)

#endregion

## 选择卡片完成
func choosed_card_start_game():
	print("选卡完成")
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.PREPARE
	## 隐藏待选卡槽
	await card_manager.card_slot_disappear_choose()
	## 相机移动回游戏场景
	await camera_2d.move_back_ori()
	main_game_start()

## 选卡结束，开始游戏
func main_game_start():
	if is_pause_on_re_choose_card:
		end_pause_on_re_choose_card_progress()
	print("主游戏开始")
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.PREPARE
	if game_para.is_fog:
		background_manager.fog.come_back_game(5.0)

	## 删除展示僵尸
	if game_para.look_show_zombie:
		zombie_manager.delete_prepare_show_zombies()

	## 首次白天教学关先播放原版滚动铺草皮，再进入 Ready/Set/Plant。
	await background_manager.play_sod_rollout_if_needed()

	## 开始天降阳光
	if game_para.is_day_sun:
		day_suns_manager.start_day_sun()
	print("生成墓碑", game_para.init_tombstone_num)
	## 生成墓碑
	if game_para.init_tombstone_num > 0:
		plant_cell_manager.create_tombstone(game_para.init_tombstone_num)

	## 等待1秒红字出现
	await get_tree().create_timer(1.0).timeout
	await ui_remind_word.ready_set_plant()
	## 主游戏进程阶段
	main_game_progress = E_MainGameProgress.MAIN_GAME
	card_manager.card_slot_update_main_game()

	## 红字结束后一秒修改bgm
	await get_tree().create_timer(1.0).timeout
	SoundManager.play_bgm(bgm_main_game)

	zombie_manager.start_game()


#region 游戏结束
## 修改僵尸位置
func change_zombie_position(zombie:Zombie000Base):
	## 要删除碰撞器，不然会闪退(这里好像是因为暂停的时候会重复循环执行一些代码，不清楚为什么)
	zombie.hurt_box_component.free()
	zombie.get_parent().remove_child(zombie)
	panel_zombie_go_home.add_child(zombie)
	zombie.position = marker_2d_zombie_go_home.position
	if game_para.game_BG == ConstLevelData.GameBg.Roof:
		roof_zombie_go_home(zombie)


func roof_zombie_go_home(zombie:Zombie000Base):
	print("禁用僵尸移动组件")
	zombie.move_component.disable_component(ComponentNormBase.E_IsEnableFactor.GameMode)
	await get_tree().create_timer(3).timeout
	var tween = zombie.create_tween()
	tween.tween_property(zombie, "position:y", 300, 10.0).as_relative()



## 僵尸进房
func on_zombie_go_home(zombie:Zombie000Base):
	re_main_game()

	main_game_progress = E_MainGameProgress.GAME_OVER
	card_slot_root.visible = false

	## 设置相机可以移动
	camera_2d.process_mode = Node.PROCESS_MODE_ALWAYS
	## 游戏暂停
	TreePauseManager.start_tree_pause(TreePauseManager.E_PauseFactor.GameOver)
	call_deferred("change_zombie_position", zombie)
	## 如果有锤子
	if game_para.is_hammer:
		game_item_manager.gim_other.hammer.set_is_used(false)
	await get_tree().create_timer(1).timeout

	camera_2d.move_to(Vector2(-200, 0), 2)
	SoundManager.play_other_SFX("losemusic")
	await get_tree().create_timer(3).timeout
	SoundManager.play_other_SFX("scream")
	ui_remind_word.zombie_won_word_appear()


#region 奖杯
## 创建奖杯
func create_trophy(glo_pos:Vector2):
	print("胜利条件达成，创建奖杯")
	## 如果不是最后一轮游戏，触发下一轮
	if curr_game_round != game_para.game_round:
		start_next_round_game()
		return


	print("=======================游戏结束，您获胜了=======================")
	var trophy = SceneRegistry.TROPHY.instantiate()
	Global.main_game.canvas_layer_temp.add_child(trophy)
	trophy.global_position = glo_pos
	if trophy.global_position.x >= 750:
		var x_diff = trophy.global_position.x - 700
		throw_to(trophy, trophy.position - Vector2(x_diff + randf_range(-50,50), 0))
	elif trophy.global_position.x <= 50:
		var x_diff = trophy.global_position.x - 100
		throw_to(trophy, trophy.position - Vector2(x_diff + randf_range(-50,50), 0))

	else:
		throw_to(trophy, trophy.position - Vector2(randf_range(-50,50), 0))

## 奖杯抛出
func throw_to(node:Node2D, target_pos: Vector2, duration: float = 1.0):
	main_game_progress = E_MainGameProgress.GAME_OVER
	var start_pos = node.position
	var peak_pos = start_pos.lerp(target_pos, 0.5)
	peak_pos.y -= 50  # 向上抛

	var tween = create_tween()
	tween.tween_property(node, "position:x", target_pos.x, duration).set_trans(Tween.TRANS_LINEAR)

	tween.parallel().tween_property(node, "position:y", peak_pos.y, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(node, "position:y", target_pos.y, duration / 2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN).set_delay(duration / 2)

#endregion


## 当前关卡完成
func win_main_game():

	## 游戏暂停因素、游戏速度
	TreePauseManager.end_tree_pause_clear_all_pause_factors()
	Global.time_scale = 1.0
	Engine.time_scale = Global.time_scale

	update_level_state_data_success()
	## 多轮游戏，重置主游戏数据
	if game_para.game_round != 1:
		re_main_game()
	get_tree().change_scene_to_file(Global.main_scene_registry.MainScenesMap.get(game_para.game_mode, Global.main_scene_registry.MainScenesMap[MainSceneRegistry.MainScenes.StartMenu]))

#endregion


#region 锤子鼠标交互
## 锤子鼠标进入后，显示鼠标
func mouse_appear_have_hammer():
	if main_game_progress == E_MainGameProgress.MAIN_GAME:
		## 如果有锤子
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## 有锤子时连接该信号
func mouse_disappear_have_hammer():
	## 如果有锤子不显示鼠标（非重新开始、离开游戏）
	if not is_mouse_visibel_on_hammer and main_game_progress == E_MainGameProgress.MAIN_GAME:
		## 如果有锤子
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## 点击重新开始或主菜单时，修改值，可以一直显示鼠标
func change_is_mouse_visibel_on_hammer(value:bool):
	if game_para.is_hammer:
		is_mouse_visibel_on_hammer = value

#endregion

#region 存档
## 读档系统只能从空白场景读档

## 存档
func save_game_main_game():
	var save_game_data_main_game:ResourceSaveGameMainGame = ResourceSaveGameMainGame.new()
	save_game_data_main_game.curr_game_round = curr_game_round
	## 植物数据
	save_game_data_main_game.plant_cell_manager_data = plant_cell_manager.get_save_game_data_plant_cell_manager()
	## 僵尸, gema_para 自动更新该值
	save_game_data_main_game.curr_max_wave = zombie_manager.zombie_wave_manager.max_wave
	save_game_data_main_game.curr_wave = zombie_manager.zombie_wave_manager.curr_wave
	## 天降阳光
	save_game_data_main_game.day_sun_curr_sun_sum_value = day_suns_manager.curr_sun_sum_value
	## 植物卡槽数据
	save_game_data_main_game.card_manager_data = card_manager.get_save_game_data_card_manager()
	## 小推车数据
	save_game_data_main_game.lawn_mover_manager_data = game_item_manager.gim_lawn_mover.get_save_game_data_lawn_mover_manager()
	if game_para.is_ranked_mode:
		var ranked_controller:Node = get_node_or_null("ChessboardMode")
		if is_instance_valid(ranked_controller) and ranked_controller.has_method("get_ranked_save_data"):
			save_game_data_main_game.ranked_mode_data = ranked_controller.get_ranked_save_data()

	var path = game_para.get_save_game_path()
	var err = ResourceSaver.save(save_game_data_main_game, path)
	if err != OK:
		push_error("关卡数据存档失败:%s, 错误代码 %d" % [path, err])
	else:
		print("关卡数据存档成功：", path)
		update_level_state_data_multi_round_data(true)


## 重置当前主游戏 多轮关卡存档,多轮关卡数据
func re_main_game():
	## 删除存档(若有存档会删除,没有就跳过)
	game_para.delete_game_data()
	## 更新当前关卡数据
	update_level_state_data_multi_round_data(false)


## 读档
func load_game_main_game():
	if game_para.save_game_data_main_game != null:
		curr_game_round = game_para.save_game_data_main_game.curr_game_round
		var save_game_data_main_game:ResourceSaveGameMainGame = game_para.save_game_data_main_game
		## 罐子模式
		if game_para.is_pot_mode:
			if game_para.is_save_plant_on_pot_mode:
				plant_cell_manager.load_game_data_plant_cell_manager(save_game_data_main_game.plant_cell_manager_data)
		else:
			plant_cell_manager.load_game_data_plant_cell_manager(save_game_data_main_game.plant_cell_manager_data)
		## 天降阳光
		day_suns_manager.curr_sun_sum_value = save_game_data_main_game.day_sun_curr_sun_sum_value
		## 植物卡槽数据
		card_manager.load_game_data_card_manager(save_game_data_main_game.card_manager_data)

#endregion
#region 更新全局关卡数据
## 更新当前关卡数据 (完成)
func update_level_state_data_success():
	## 更新全局关卡数据
	var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(game_para.save_game_name, {})
	curr_level_state_data["IsSuccess"] = true
	var reward_plants: Array[CharacterRegistry.PlantType] = game_para.reward_plant_types.duplicate()
	if reward_plants.is_empty() and int(game_para.reward_plant_type) >= 0:
		reward_plants.append(int(game_para.reward_plant_type) as CharacterRegistry.PlantType)
	if not reward_plants.is_empty():
		curr_level_state_data["RewardPlants"] = reward_plants
		curr_level_state_data["RewardPlant"] = int(reward_plants[0])
	for reward_plant in reward_plants:
		if not Global.global_game_state.curr_plant.has(reward_plant):
			Global.global_game_state.curr_plant.append(reward_plant)
	Global.global_game_state.curr_all_level_state_data[game_para.save_game_name] = curr_level_state_data
	Global.save_service.save_now()

## 更新当前关卡数据 (多轮游戏)
func update_level_state_data_multi_round_data(is_have_multi_round_data:=true):
	## 更新全局关卡数据
	var curr_level_state_data:Dictionary = Global.global_game_state.curr_all_level_state_data.get(game_para.save_game_name, {})
	curr_level_state_data["IsHaveMultiRoundSaveGameData"] = is_have_multi_round_data
	curr_level_state_data["CurrGameRound"] = curr_game_round
	Global.global_game_state.curr_all_level_state_data[game_para.save_game_name] = curr_level_state_data
	Global.save_service.save_now()
#endregion
