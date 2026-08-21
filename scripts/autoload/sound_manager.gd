extends Node
class_name SoundManagerClass

enum Bus {MASTER, BGM, SFX}

@onready var bgm_play: AudioStreamPlayer = $BGMPlay
@onready var sfx_all: Node = $SFXAll
@onready var crazy_dave_player: AudioStreamPlayer = $SFXAll/CrazyDavePlayer
@onready var rain_player: AudioStreamPlayer = $SFXAll/RainPlayer

## 当前帧播放的音效(每隔25物理帧清除一次)
## 音效每25物理帧内不可以重复播放
var curr_frame_sfx:Array[AudioStream] = []
var frame_num:=0

#func _ready() -> void:
	#Global.config_service.load_and_apply_config()
	#Global.save_config()

@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	frame_num = wrapi(frame_num + 1, 0, 25)
	if frame_num == 0:
		curr_frame_sfx.clear()

#region 播放音乐和音效
func play_bgm(stream: AudioStream, volume_db: float = 0.0):
	bgm_play.volume_db = volume_db
	if bgm_play.playing and bgm_play.stream != null \
			and bgm_play.stream.resource_path == stream.resource_path:
		return
	bgm_play.stream = stream
	bgm_play.play()

#region 植物和僵尸有关音效(植物、僵尸、子弹、受击)
"""
 音效分为 僵尸受击 子弹音效 角色(植物僵尸) 戴夫 和其他音效
"""

## 僵尸受击音效种类
enum TypeBeAttackSFX{
	Null,		## 无声音
	Plastic,	## 塑料
	Shield		## 铁器
}

## 僵尸受击音效资源字典
const SFXBeAttackMap := {
	TypeBeAttackSFX.Null: null,
	TypeBeAttackSFX.Plastic: [
		"res://assets/audio/SFX/bullet/plastichit.ogg",
		"res://assets/audio/SFX/bullet/plastichit2.ogg"
	],
	TypeBeAttackSFX.Shield: [
		"res://assets/audio/SFX/bullet/shieldhit1.ogg",
		"res://assets/audio/SFX/bullet/shieldhit2.ogg"
	],
}

## 子弹音效种类
enum TypeBulletSFX{
	Null,		## 无声音
	Pea,		## 豌豆
	PeaFire,	## 火焰豌豆
	Corn,		## 玉米粒
	Butter,		## 黄油
	Melon,		## 西瓜
	Bowling = 1001,		## 保龄球
}

## 子弹音效资源字典
const SFXBulletMap := {
	TypeBulletSFX.Null: null,
	TypeBulletSFX.Pea: [
		"res://assets/audio/SFX/bullet/splat1.ogg",
		"res://assets/audio/SFX/bullet/splat2.ogg",
		"res://assets/audio/SFX/bullet/splat3.ogg"
	],
	TypeBulletSFX.PeaFire: [
		"res://assets/audio/SFX/bullet/firepea.ogg",
	],
	TypeBulletSFX.Corn:[
		"res://assets/audio/SFX/bullet/kernelpult2.ogg",
		"res://assets/audio/SFX/bullet/kernelpult.ogg"
	],
	TypeBulletSFX.Butter:[
		"res://assets/audio/SFX/bullet/butter.ogg"
	],
	TypeBulletSFX.Melon:[
		"res://assets/audio/SFX/bullet/melonimpact.ogg",
		"res://assets/audio/SFX/bullet/melonimpact2.ogg"
	],

	TypeBulletSFX.Bowling: [
		"res://assets/audio/SFX/bullet/bowlingimpact.ogg",
		"res://assets/audio/SFX/bullet/bowlingimpact2.ogg",
	],

}

## 植物\僵尸音效字典
const SFXCharacterMap := {
	## -------------------------------植物-------------------------------
	## 豌豆射手发射字典
	&"Throw":[
		"res://assets/audio/SFX/plant/throw1.ogg",
		"res://assets/audio/SFX/plant/throw2.ogg"
	],
	## 向日葵发射阳光
	&"Throw1":"res://assets/audio/SFX/plant/throw1.ogg",
	## 樱桃炸弹爆炸
	&"CherryBomb":"res://assets/audio/SFX/plant/cherrybomb.ogg",
	## 土豆雷爆炸
	&"PotatoMine": "res://assets/audio/SFX/plant/potato_mine.ogg",
	## 大嘴花
	&"BigChomp": "res://assets/audio/SFX/plant/bigchomp.ogg",
	## 小喷菇发射子弹
	&"Puff": "res://assets/audio/SFX/plant/puff.ogg",
	## 黑百合胆小菇暴击：原创合成的短促狙击爆头音，不复用原有 SFX。
	&"WidowmakerCriticalHeadshot": "res://assets/audio/SFX/plant/widowmaker_critical_headshot.wav",
	## 阳光菇长大
	&"PlantGrow": "res://assets/audio/SFX/plant/plantgrow.ogg",
	## 大喷菇发射子弹
	&"Fume": "res://assets/audio/SFX/plant/fume.ogg",
	## 墓碑吞噬者
	&"GraveBusterChomp":"res://assets/audio/SFX/plant/gravebusterchomp.ogg",
	## 魅惑菇
	&"MindControlled": "res://assets/audio/SFX/plant/mindcontrolled.ogg",
	## 寒冰菇
	&"Frozen": "res://assets/audio/SFX/plant/frozen.ogg",
	## 毁灭菇
	&"DoomShroom": "res://assets/audio/SFX/plant/doomshroom.ogg",
	## 倭瓜发现敌人
	&"SquashHmm":[
		"res://assets/audio/SFX/plant/squash_hmm2.ogg",
		"res://assets/audio/SFX/plant/squash_hmm.ogg"
	],
	## 火爆辣椒
	&"Jalapeno": "res://assets/audio/SFX/plant/jalapeno.ogg",
	## 三叶草
	&"blover": "res://assets/audio/SFX/plant/blover.ogg",
	## 磁力菇
	&"magnetshroom": "res://assets/audio/SFX/plant/magnetshroom.ogg",
	## 磁力菇
	&"coblaunch": "res://assets/audio/SFX/plant/coblaunch.ogg",




	## -------------------------------僵尸-------------------------------
	## 通用音效
	## 掉头
	&"limbs_pop": "res://assets/audio/SFX/zombie/limbs_pop.ogg",

	## 啃食
	&"Chomp":[
		"res://assets/audio/SFX/zombie/chomp.ogg",
		"res://assets/audio/SFX/zombie/chomp2.ogg",
		"res://assets/audio/SFX/zombie/chompsoft.ogg"
	],
	## 掉头
	&"Shoop":"res://assets/audio/SFX/zombie/shoop.ogg",
	## 啃食大蒜
	&"yuck":[
		"res://assets/audio/SFX/zombie/yuck2.ogg",
		"res://assets/audio/SFX/zombie/yuck.ogg"
	],
	## 撑杆跳
	&"Polevault":"res://assets/audio/SFX/zombie/polevault.ogg",
	## 读报僵尸愤怒
	&"Rarrgh":[
		"res://assets/audio/SFX/zombie/newspaper_rarrgh.ogg",
		"res://assets/audio/SFX/zombie/newspaper_rarrgh2.ogg"
	],
	## 读报僵尸报纸掉落
	&"Rip":	"res://assets/audio/SFX/zombie/newspaper_rip.ogg",
	## 舞王入场
	&"Dancer":"res://assets/audio/SFX/zombie/dancer.ogg",
	## 冰车僵尸入场
	&"zamboni":"res://assets/audio/SFX/zombie/zamboni.ogg",
	## 冰车僵尸爆炸\小丑僵尸爆炸
	&"explosion":"res://assets/audio/SFX/zombie/explosion.ogg",
	## 海豚僵尸入场
	&"dolphin_appears":"res://assets/audio/SFX/zombie/dolphin_appears.ogg",
	## 海豚僵尸跳跃
	&"dolphin_before_jumping":"res://assets/audio/SFX/zombie/dolphin_before_jumping.ogg",
	## 小丑僵尸入场
	&"jackinthebox":"res://assets/audio/SFX/zombie/jackinthebox.ogg",
	## 小丑僵尸爆炸惊讶
	&"jack_suprise":[
		"res://assets/audio/SFX/zombie/jack_surprise.ogg",
		"res://assets/audio/SFX/zombie/jack_surprise2.ogg",
	],
	## 小丑僵尸盒子打开
	&"boing":"res://assets/audio/SFX/zombie/boing.ogg",
	## 气球僵尸入场
	&"ballooninflate":"res://assets/audio/SFX/zombie/ballooninflate.ogg",
	## 气球爆炸
	&"balloon_pop":"res://assets/audio/SFX/zombie/balloon_pop.ogg",
	## 矿工僵尸绝地
	&"digger_zombie": "res://assets/audio/SFX/zombie/digger_zombie.ogg",
	## 跳跳僵尸跳跃
	&"pogo_zombie": "res://assets/audio/SFX/zombie/pogo_zombie.ogg",
	## 蹦极僵尸入场
	&"bungee_scream":[
		"res://assets/audio/SFX/zombie/bungee_scream.ogg",
		"res://assets/audio/SFX/zombie/bungee_scream2.ogg",
		"res://assets/audio/SFX/zombie/bungee_scream3.ogg"
	],
	## 扶梯僵尸放置梯子
	&"ladder_zombie": "res://assets/audio/SFX/zombie/ladder_zombie.ogg",
	## 篮球僵尸发射篮球子弹
	&"basketball": "res://assets/audio/SFX/zombie/basketball.ogg",

	## 巨人僵尸攻击\倭瓜
	&"gargantuar_thump": "res://assets/audio/SFX/zombie/gargantuar_thump.ogg",
	## 巨人僵尸死亡
	&"gargantudeath": "res://assets/audio/SFX/zombie/gargantudeath.ogg",
	## 小鬼被抛射
	&"imp":[
		"res://assets/audio/SFX/zombie/imp.ogg",
		"res://assets/audio/SFX/zombie/imp2.ogg"
	]
}

## 戴夫音效字典
const SFXCarzyDaveMap := {
	## 一秒左右
	&"crazydaveshort" : [
		"res://assets/audio/SFX/carzy/crazydaveshort1.ogg",
		"res://assets/audio/SFX/carzy/crazydaveshort2.ogg",
		"res://assets/audio/SFX/carzy/crazydaveshort3.ogg"
	],
	## 两秒左右
	&"crazydavelong" : [
		"res://assets/audio/SFX/carzy/crazydavelong1.ogg",
		"res://assets/audio/SFX/carzy/crazydavelong2.ogg",
		"res://assets/audio/SFX/carzy/crazydavelong3.ogg"
	],
	## 三秒左右
	&"crazydaveextralong" : [
		"res://assets/audio/SFX/carzy/crazydaveextralong1.ogg",
		"res://assets/audio/SFX/carzy/crazydaveextralong2.ogg",
		"res://assets/audio/SFX/carzy/crazydaveextralong3.ogg"
	],
	&"crazydavecrazy" : [
		"res://assets/audio/SFX/carzy/crazydavecrazy.ogg"
	],
	&"crazydavescream" : [
		"res://assets/audio/SFX/carzy/crazydavescream2.ogg",
		"res://assets/audio/SFX/carzy/crazydavescream.ogg"
	],
}

## 音效对象池实现
var sfx_bullet_pool = []
var _sfx_stream_cache: Dictionary[String, AudioStream] = {}


func _resolve_sfx_stream(source: Variant) -> AudioStream:
	if source is AudioStream:
		return source
	if not (source is String or source is StringName):
		return null
	var source_path := String(source)
	if _sfx_stream_cache.has(source_path):
		return _sfx_stream_cache[source_path]
	var stream := ResourceLoader.load(source_path, "AudioStream") as AudioStream
	if stream == null:
		push_error("无法加载音效：%s" % source_path)
		return null
	_sfx_stream_cache[source_path] = stream
	return stream

func play_sfx_with_pool(sfx_resource: AudioStream, volume_db:float = 0.0) -> AudioStreamPlayer:
	if sfx_resource == null:
		return null
	if sfx_resource in curr_frame_sfx:
		return
	curr_frame_sfx.append(sfx_resource)

	var player: AudioStreamPlayer
	# 从池中获取可用播放器
	for p in sfx_bullet_pool:
		if not p.playing:
			player = p
			break

	# 如果没有可用播放器，创建新的
	if not player:
		player = AudioStreamPlayer.new()
		player.bus = AudioServer.get_bus_name(Bus.SFX)
		player.finished.connect(_on_sfx_finished.bind(player))
		sfx_all.add_child(player)
		sfx_bullet_pool.append(player)

	## 配置播放器
	player.stream = sfx_resource
	player.volume_db = volume_db
	player.play()
	return player

#TODO: 好像没什么用,后续会删掉
@warning_ignore("unused_parameter")
func _on_sfx_finished(player: AudioStreamPlayer):
	# 播放完成后自动停止，保留在池中
	#player.stop()
	pass

## 播放僵尸受击音效
func play_be_attack_SFX(type_bullet_zombie_sfx:TypeBeAttackSFX):
	var sfx_array: Variant = SFXBeAttackMap.get(type_bullet_zombie_sfx)
	if not sfx_array is Array or sfx_array.is_empty():
		return
	play_sfx_with_pool(_resolve_sfx_stream(sfx_array.pick_random()))

## 播放子弹攻击音效
func play_bullet_attack_SFX(type_bullet_sfx:TypeBulletSFX):
	var sfx_array: Variant = SFXBulletMap.get(type_bullet_sfx)
	if not sfx_array is Array or sfx_array.is_empty():
		return
	play_sfx_with_pool(_resolve_sfx_stream(sfx_array.pick_random()))

## 播放植物\僵尸相关音效
func play_character_SFX(option:StringName, volume_db:float = 0.0):
	var source: Variant = SFXCharacterMap.get(option)
	if source is Array:
		if source.is_empty():
			return null
		source = source.pick_random()
	var sfx_resource := _resolve_sfx_stream(source)
	var player: AudioStreamPlayer = play_sfx_with_pool(sfx_resource, volume_db)
	return player


## 播放戴夫音效
func play_crazy_dave_SFX(option:StringName):
	var sfx_array: Variant = SFXCarzyDaveMap.get(option)
	if not sfx_array is Array or sfx_array.is_empty():
		return
	crazy_dave_player.stream = _resolve_sfx_stream(sfx_array.pick_random())
	if crazy_dave_player.stream == null:
		return
	crazy_dave_player.play()

func play_rain_SFX():
	var RAIN = load("uid://dmjld1k8ieh1g")
	rain_player.stream = RAIN
	rain_player.play()

func stop_rain_SFX():
	rain_player.stop()
#endregion

#region 其余音效
const SFXOtherMap := {
	##-------------------------- 按钮相关 --------------------------
	## 开始菜单点击
	&"gravebutton": "res://assets/audio/SFX/button/gravebutton.ogg",
	## 鼠标进入开始菜单
	&"bleep":"res://assets/audio/SFX/button/bleep.ogg",
	##
	&"tap":"res://assets/audio/SFX/button/tap.ogg",
	## 选项按钮
	&"buttonclick":"res://assets/audio/SFX/button/buttonclick.ogg",
	## 暂停
	&"pause": "res://assets/audio/SFX/button/pause.ogg",
	## 点击阳光
	&"points": "res://assets/audio/SFX/button/points.ogg",
	## 点击金币
	&"coin":"res://assets/audio/SFX/item/coin.ogg",
	## 掉落花园植物
	&"chime":"res://assets/audio/SFX/item/chime.ogg",
	##-------------------------- 卡片相关 --------------------------
	&"buzzer":"res://assets/audio/SFX/card_and_shovel/buzzer.ogg",
	&"seedlift":"res://assets/audio/SFX/card_and_shovel/seedlift.ogg",
	&"shovel":"res://assets/audio/SFX/card_and_shovel/shovel.ogg",
	&"tap2":"res://assets/audio/SFX/card_and_shovel/tap2.ogg",

	##-------------------------- 进度相关 --------------------------
	## 汽笛音效
	&"siren": "res://assets/audio/SFX/progress/siren.ogg",
	## TODO :这个也是汽笛音效？
	&"awooga":"res://assets/audio/SFX/progress/awooga.ogg",
	## 最后一波
	&"finalwave":"res://assets/audio/SFX/progress/finalwave.ogg",
	## 大波僵尸
	&"hugewave":"res://assets/audio/SFX/progress/hugewave.ogg",
	## 失败
	&"losemusic":"res://assets/audio/SFX/progress/losemusic.ogg",
	## 准备安放植物
	&"readysetplant":"res://assets/audio/SFX/progress/readysetplant.ogg",
	## 戴夫尖叫
	&"scream":"res://assets/audio/SFX/progress/scream.ogg",
	## 获胜音效
	&"winmusic":"res://assets/audio/SFX/progress/winmusic.ogg",


	##-------------------------- 主游戏场景物品相关 --------------------------
	## 墓碑生成
	&"gravestone_rumble":"res://assets/audio/SFX/zombie/gravestone_rumble.ogg",
	## 植物种植音效
	&"plant1": "res://assets/audio/SFX/plant_create/plant.ogg",
	## 植物铲除音效
	&"plant2":"res://assets/audio/SFX/plant_create/plant2.ogg",
	## 植物种植在水上
	&"plant_water": "res://assets/audio/SFX/plant_create/plant_water.ogg",
	## 僵尸入水音效、水花音效
	&"zombie_entering_water": "res://assets/audio/SFX/zombie/zombie_entering_water.ogg",
	## -------- 小推车 --------
	&"lawnmower": "res://assets/audio/SFX/item/lawnmower.ogg",
	&"pool_cleaner": "res://assets/audio/SFX/item/pool_cleaner.ogg",
	## -------- 锤子 --------
	&"swing": "res://assets/audio/SFX/item/swing.ogg",
	&"bonk": "res://assets/audio/SFX/item/bonk.ogg",
	## -------- 花园 -----------
	&"prize": "res://assets/audio/SFX/garden/prize.ogg",
	## -------- 僵尸出土 ------------
	&"dirt_rise": "res://assets/audio/SFX/zombie/dirt_rise.ogg",
	## --------- 花瓶破碎     -------------
	&"vase_breaking": "res://assets/audio/SFX/item/vase_breaking.ogg",


	##-------------------------- 花园相关 --------------------------
	&"watering":"res://assets/audio/SFX/garden/watering.ogg",
	&"fertilizer":"res://assets/audio/SFX/garden/fertilizer.ogg",
	&"bugspray":"res://assets/audio/SFX/garden/bugspray.ogg",
	&"phonograph":"res://assets/audio/SFX/garden/phonograph.ogg",
	&"wakeup": "res://assets/audio/SFX/garden/wakeup.ogg",

}
## 播放其它相关音效
func play_other_SFX(option:StringName):
	var source: Variant = SFXOtherMap.get(option)
	if source is Array:
		if source.is_empty():
			return
		source = source.pick_random()
	var sfx_resource := _resolve_sfx_stream(source)
	play_sfx_with_pool(sfx_resource)


#endregion

#endregion

#region 按钮信号连接辅助函数
## 更新开始菜单的UI音效
func setup_ui_start_menu_sound(node:Node, is_menu_button:=false):
	if node is BaseButton:
		var button := node
		button.mouse_entered.connect(play_other_SFX.bind("bleep"))

		if is_menu_button:
			button.button_down.connect(play_other_SFX.bind("gravebutton"))
		else:
			if not button.button_down.is_connected(play_other_SFX):
				button.button_down.connect(play_other_SFX.bind("tap"))


	for child in node.get_children():
		## 如果是Menu或者其上面的节点为Menu
		if child.name == "Menu" or is_menu_button:
			setup_ui_start_menu_sound(child, true)
		else:
			setup_ui_start_menu_sound(child, false)


## 更新主游戏按钮的UI音效
func setup_ui_main_game_sound(node:Node):
	if node is BaseButton:
		if node is CheckButton:
			node.pressed.connect(play_other_SFX.bind("buttonclick"))
		else:
			node.button_down.connect(play_other_SFX.bind("gravebutton"))

			if node.name == "Return":
				node.pressed.connect(play_other_SFX.bind("buttonclick"))


	for child in node.get_children():
		setup_ui_main_game_sound(child)
#endregion

#region 音量大小调整
func get_volum(bus_index:int):
	var db := AudioServer.get_bus_volume_db(bus_index)
	return db_to_linear(db)

func set_volume(bus_index:int, v:float) ->void:
	var db := linear_to_db(v)
	AudioServer.set_bus_volume_db(bus_index, db)
#endregion
