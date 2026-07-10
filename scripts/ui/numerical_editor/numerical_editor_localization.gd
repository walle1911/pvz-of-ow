extends RefCounted
class_name NumericalEditorLocalization

const CHARACTER_NAMES := {
	"PeaShooterSingle": "豌豆射手", "SunFlower": "向日葵", "CherryBomb": "樱桃炸弹",
	"WallNut": "坚果墙", "PotatoMine": "土豆雷", "SnowPea": "寒冰射手", "Chomper": "大嘴花",
	"PeaShooterDouble": "双发射手", "PuffShroom": "小喷菇", "SunShroom": "阳光菇",
	"FumeShroom": "大喷菇", "GraveBuster": "墓碑吞噬者", "HypnoShroom": "魅惑菇",
	"ScaredyShroom": "胆小菇", "IceShroom": "寒冰菇", "DoomShroom": "毁灭菇", "LilyPad": "睡莲",
	"Squash": "倭瓜", "ThreePeater": "三线射手", "TangleKelp": "缠绕水草", "Jalapeno": "火爆辣椒",
	"Caltrop": "地刺", "TorchWood": "火炬树桩", "TallNut": "高坚果", "SeaShroom": "海蘑菇",
	"Plantern": "路灯花", "Cactus": "仙人掌", "Blover": "三叶草", "SplitPea": "裂荚射手",
	"StarFruit": "杨桃", "Pumpkin": "南瓜头", "MagnetShroom": "磁力菇", "CabbagePult": "卷心菜投手",
	"FlowerPot": "花盆", "CornPult": "玉米投手", "CoffeeBean": "咖啡豆", "Garlic": "大蒜",
	"UmbrellaLeaf": "叶子保护伞", "MariGold": "金盏花", "MelonPult": "西瓜投手",
	"GatlingPea": "机枪射手", "TwinSunFlower": "双子向日葵", "GloomShroom": "忧郁菇",
	"Cattail": "香蒲", "WinterMelon": "冰瓜投手", "GoldMagnet": "吸金磁", "SpikeRock": "地刺王",
	"CobCannon": "玉米加农炮", "Imitater": "模仿者", "Sprout": "萌芽",
	"WallNutBowling": "坚果保龄球", "WallNutBowlingBomb": "爆炸坚果保龄球", "WallNutBowlingBig": "巨型坚果保龄球",
	"PeaShooterDoubleReverse": "反向双发射手", "PeaShooterSoldier76": "豌豆射手（士兵76）",
	"Sunflower_Mercy": "向日葵（天使）", "CherryBomb_Junkrat": "樱桃炸弹（狂鼠）",
	"Squash_Doomfist": "倭瓜（末日铁拳）", "SnowPea_Mei": "寒冰射手（美）",
	"GatlingPea_Bastion": "机枪射手（堡垒）", "TwinSunFlower_Illari": "双子向日葵（伊拉锐）",
	"TallNut_Sigma": "高坚果（西格玛）", "Cattail_JetpackCat": "香蒲（喷气背包猫）",
	"Jalapeno_Vendetta": "火爆辣椒（复仇）", "MelonPult_Ashe": "西瓜投手（艾什）",
	"Imitater_Echo": "模仿者（回声）", "DoomShroom_DVA": "毁灭菇（宋哈娜）",
	"GloomShroom_Moira": "忧郁菇（莫伊拉）", "SeaShroom_Wuyang": "海蘑菇（无漾）",
	"FumeShroom_Roadhog": "大喷菇（路霸）", "MagnetShroom_Sombra": "磁力菇（黑影）",
	"CoffeeBean_Ana": "咖啡豆（安娜）", "ScaredyShroom_Widowmaker": "胆小菇（黑百合）",
	"HypnoShroom_Juno": "魅惑菇（朱诺）", "BonkChoy_Ramattra": "菜问（拉玛刹）",
	"Garlic_Mauga": "大蒜（毛加）", "Caltrop_Hazard": "地刺（骇灾）",
	"Tanglekelp_Mizuki": "缠绕水草（水月）", "Threepeater_Daotian": "三线射手（稻田）",
	"Torchwood_Baptiste": "火炬树桩（巴蒂斯特）", "Cactus_Cassidy": "仙人掌（卡西迪）",
	"Pumpkin_Zarya": "南瓜头（查莉娅）", "UmbrellaLeaf_Lifeweaver": "叶子保护伞（生命之梭）",
	"CobCannon_Emre": "玉米加农炮（埃姆雷）", "Cattail_Sierra": "香蒲（希尔拉）",
	"ZombieNorm": "普通僵尸", "ZombieFlag": "摇旗僵尸", "ZombieCone": "路障僵尸",
	"ZombiePoleVaulter": "撑杆僵尸", "ZombieBucket": "铁桶僵尸", "ZombiePaper": "读报僵尸",
	"ZombieScreenDoor": "铁栅门僵尸", "ZombieFootball": "橄榄球僵尸", "ZombieJackson": "舞王僵尸",
	"ZombieDancer": "伴舞僵尸", "ZombieDuckytube": "鸭子救生圈僵尸", "ZombieSnorkle": "潜水僵尸",
	"ZombieZamboni": "雪橇车僵尸", "ZombieBobsled": "雪橇僵尸小队", "ZombieDolphinrider": "海豚骑士僵尸",
	"ZombieJackbox": "玩偶匣僵尸", "ZombieBallon": "气球僵尸", "ZombieDigger": "矿工僵尸",
	"ZombiePogo": "跳跳僵尸", "ZombieYeti": "僵尸雪人", "ZombieBungi": "蹦极僵尸",
	"ZombieLadder": "梯子僵尸", "ZombieCatapult": "投石车僵尸", "ZombieGargantuar": "伽刚特尔",
	"ZombieImp": "小鬼僵尸", "ZombieBobsledSingle": "单个雪橇僵尸",
	"Gargantuar_Reinhardt": "伽刚特尔（莱因哈特）", "ZombieYeti_Winston": "僵尸雪人（温斯顿）",
	"DiggerZombie_Venture": "矿工僵尸（探奇）", "Jackbox_Reaper": "玩偶匣僵尸（死神）",
	"DancingZombie_Lucio": "舞王僵尸（卢西奥）", "BackupDancer_Lucio": "伴舞僵尸（卢西奥）",
	"Zomboni_Shion": "雪橇车僵尸（紫苑）", "Gargantuar_Ashe": "伽刚特尔（艾什）",
	"PeashooterZombie": "豌豆射手僵尸",
}

const PROPERTY_LABELS := {
	"MaxNumBullet": "最大子弹数量", "MinXThrowGargantuar": "投掷巨人最小横坐标", "XThrow": "投掷横坐标",
	"attack_cd": "攻击间隔（秒）", "attack_value": "攻击伤害", "attack_value_bullet": "子弹伤害",
	"balloon_pop_glo_pos_x_in_zombie_mode": "僵尸模式气球破裂横坐标", "beam_curve_height": "光束弯曲高度",
	"beam_glow_width": "光束发光宽度", "beam_z_index": "光束显示层级", "blink_time": "眨眼间隔",
	"blover_time": "三叶草生效时间", "bomb_lane": "爆炸影响行数", "bomb_value": "爆炸伤害",
	"bounce_damping": "弹跳衰减", "boundary_value_hp": "本体血量阶段阈值", "boundary_value_hp_armor1": "一类防具阶段阈值",
	"bullet_attack_intervals": "三路线额外间隔（上、中、下）", "bullet_attack_values": "三路线伤害（上、中、下）",
	"bullet_damage_multiplier": "子弹伤害倍率", "bullet_speeds": "三路线子弹速度（上、中、下）",
	"charge_cd": "蓄力间隔", "correct_y": "纵向修正", "covered_front_child_alpha_percent": "前方遮挡透明度",
	"damage_boost_multiplier": "蓝线增伤倍率", "damage_boost_target_cell_max_range": "蓝线最远连接格数",
	"damage_boost_target_check_interval": "蓝线目标检查间隔", "damage_boost_target_plant_types": "蓝线可增伤植物编号",
	"death_status": "死亡状态编号", "death_status_max": "死亡状态最大编号", "detect_refresh_time": "检测刷新间隔",
	"digger_target_pos_x": "矿工目标横坐标", "drop_coin_rate": "硬币掉落概率", "drop_coin_silver_glod_diamond_rate": "银币、金币、钻石掉落权重",
	"drop_garden_plant_rate": "花园植物掉落概率", "eat_CD": "啃食间隔", "eat_attack": "啃食伤害",
	"eat_brain_glo_pos_x_in_zombie_mode": "僵尸模式吃脑横坐标", "escape_hp_threshold": "触发逃生血量", "escape_move_time": "逃生位移耗时",
	"exist_time": "持续时间", "frame_scale": "帧缩放倍率", "frame_time": "帧持续时间", "global_pos_x_can_attack": "可攻击横坐标",
	"glow_flow_speed": "发光流动速度", "glow_overlay_flow_speed": "发光叠层流动速度", "glow_overlay_pulse_amount": "发光叠层脉冲幅度",
	"glow_overlay_pulse_speed": "发光叠层脉冲速度", "glow_pulse_amount": "发光脉冲幅度", "glow_pulse_speed": "发光脉冲速度",
	"ground_y": "地面纵坐标", "heal_amount_per_second": "每秒回血量", "heal_delay_after_attack": "受伤后回血等待",
	"heal_duration": "回血持续时间", "idle_frame_blend_enabled": "启用待机帧混合", "idle_frame_blend_strength": "待机帧混合强度",
	"idle_status": "待机状态编号", "idle_status_max": "待机状态最大编号", "imitater_gray_strength": "模仿者灰度强度",
	"imitater_whiteness": "模仿者泛白强度", "imitater_zombie_brightness": "模仿僵尸亮度", "imitater_zombie_contrast": "模仿僵尸对比度",
	"imitater_zombie_gray_strength": "模仿僵尸灰度强度", "imitater_zombie_whiteness": "模仿僵尸泛白强度",
	"init_attack_value_per_min": "啃食伤害", "is_activate_umbrella": "启用叶子保护伞", "is_auto_bomb_in_death": "死亡时自动爆炸",
	"is_bite": "处于咬合状态", "is_bullet": "启用子弹攻击", "is_caltrop": "作为地刺", "is_can_ladder": "允许搭梯",
	"is_charge": "启用蓄力", "is_cherry_bomb": "作为樱桃炸弹", "is_chewing": "处于咀嚼状态", "is_dectection": "启用检测",
	"is_detect_attack": "启用攻击检测", "is_dig": "处于挖掘状态", "is_drop_end": "掉落结束", "is_drop_ladder": "允许掉落梯子",
	"is_enable_default": "默认启用", "is_fail_ladder": "搭梯失败", "is_gasp": "处于喘息状态", "is_grab": "处于抓取状态",
	"is_grow": "处于成长状态", "is_ignore_ladder": "忽略梯子", "is_jump_compensate_plant": "跳跃补偿植物位置",
	"is_jumping": "处于跳跃状态", "is_lane": "按行攻击", "is_norm_end": "普通阶段结束", "is_place_ladder": "处于搭梯状态",
	"is_plant_food": "启用能量豆效果", "is_pogo": "启用跳跳行为", "is_pop": "处于破裂状态", "is_prepare_end": "准备阶段结束",
	"is_right": "朝向右侧", "is_rise": "处于升起状态", "is_scared": "处于害怕状态", "is_sleep_in_day": "白天睡觉",
	"is_throw": "处于投掷状态", "is_thrown": "已被投掷", "is_trigger_squash_pos_judge": "触发倭瓜位置判断",
	"is_trigger_tall_nut_stop_jump": "允许高坚果阻止跳跃", "is_umbrella_raise": "保护伞已抬起", "is_up_end": "出土阶段结束",
	"jump_compensate_distance": "跳跃补偿距离", "jump_x": "跳跃横向距离", "max_hp": "本体血量", "max_hp_armor1": "一类防具血量",
	"max_hp_armor2": "二类防具血量", "middle_triple_shot_enabled": "启用中路三连发", "middle_triple_shot_interval": "中路三连发间隔",
	"mini_sun_value": "小阳光数值", "norm_sun_value": "普通阳光数值", "normal_attacks_before_uppercut": "触发上勾拳前普通攻击次数",
	"num_create_sun": "每次生产阳光数量", "num_moon_walk": "太空步次数", "ori_speed": "移动速度", "p_butter": "黄油触发概率",
	"plant_food_attack_value": "能量豆攻击伤害", "pogo_y_defalut": "跳跳默认高度", "prepare_time": "准备时间",
	"probability_early_bomb": "提前爆炸概率", "probability_run": "奔跑概率", "remaining_sun_on_zombie_mode": "僵尸模式剩余阳光",
	"rotation_speed": "旋转速度", "sun_value": "阳光数值", "time_decelerate": "减速持续时间", "time_grow": "成长时间",
	"time_ice": "冰冻持续时间", "time_pogo_once_default": "单次跳跃默认时间", "uppercut_attack_multiplier": "上勾拳伤害倍率",
	"walk_status": "行走状态编号", "walk_status_max": "行走状态最大编号", "x_correct_on_attack": "攻击时横向修正",
	"x_v": "横向速度", "yellow_fume_alpha_scale": "黄色烟雾透明度倍率", "yellow_fume_chance": "黄色烟雾出现概率",
	"yellow_fume_heal_value": "黄色烟雾治疗量",
}

const COMPONENT_NAMES := {
	"AttackComponent": "攻击组件", "AttackComponent2": "第二攻击组件", "AttackComponentBullet": "子弹攻击组件",
	"BombComponent": "爆炸组件", "BombComponentJackbox": "玩偶匣爆炸组件", "BlinkComponent": "眨眼组件",
	"Body": "身体组件", "CreateCoinComponent": "硬币生产组件", "CreateSunComponent": "阳光生产组件",
	"DetectComponent": "检测组件", "DetectComponentBullet": "子弹检测组件", "DetectComponentPogo": "跳跳检测组件",
	"DropItemComponent": "物品掉落组件", "FogClearerComponent": "迷雾清除组件", "GardenComponent": "花园组件",
	"HpComponent": "血量组件", "HpStageChangeComponent": "血量阶段组件", "HurtBoxComponent": "受击组件",
	"IceRoad": "冰道组件", "JumpComponent": "跳跃组件", "MagnetComponent": "磁力组件", "MoveComponent": "移动组件",
	"ScaredyComponent": "胆小状态组件", "SleepComponent": "睡眠组件",
}


static func character_name(registry_name: String) -> String:
	return str(CHARACTER_NAMES.get(registry_name, "未命名角色"))


static func property_name(raw_name: String) -> String:
	return str(PROPERTY_LABELS.get(raw_name, "其他玩法参数"))


static func component_name(raw_name: String) -> String:
	if COMPONENT_NAMES.has(raw_name):
		return COMPONENT_NAMES[raw_name]
	if raw_name.begins_with("Body"):
		return "身体组件"
	if raw_name.contains("Drop"):
		return "掉落部件"
	return "角色专属组件"
