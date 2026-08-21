extends Node
class_name BulletRegistry


enum BulletType{
	Null = 0,

	Bullet001Pea = 1,			## 豌豆
	Bullet002PeaSnow,		## 寒冰豌豆
	Bullet003Puff,			## 小喷孢子
	Bullet004Fume,			## 大喷孢子
	Bullet005PuffLongTime,	## 胆小菇孢子（和小喷孢子一样，不过修改存在持续距离）
	Bullet006PeaFire,		## 火焰豌豆
	Bullet007Cactus,		## 仙人掌尖刺
	Bullet008Star,			## 星星子弹

	Bullet009Cabbage,		## 卷心菜
	Bullet010Corn,			## 玉米
	Bullet011Butter,		## 黄油
	Bullet012Melon,			## 西瓜

	Bullet013Basketball,	## 篮球

	Bullet014CattailBullet,	## 香蒲子弹
	Bullet015WinterMelon,	## 冰瓜子弹

	Bullet016CobCannon,		## 玉米加农炮子弹
	Bullet017SnowFume,		## 小美近距离寒冰喷雾
	Bullet018GiantPea,		## 堡垒版机枪射手巨型豌豆
	Bullet019WidowmakerTracer,	## 黑百合胆小菇即时命中弹道
	Bullet020SojournTracer,	## 索杰恩豌豆射手僵尸蓝色穿透弹道
	Bullet021SeaShroomWuyang,	## 海蘑菇无恙鼠标制导孢子
	Bullet022AnranFireWave,	## 安燃近距离穿透火焰环流


	Bullet1001Bowling = 1001,		## 保龄球
	Bullet1002BowlingBomb,	## 爆炸保龄球
	Bullet1003BowlingBig,	## 大保龄球

}


## 伤害种类
## 普通，穿透，真实
enum AttackMode {
	Norm, 			## 正常 按顺序对二类防具、一类防具、本体造成伤害
	Penetration, 	## 穿透 对二类防具造成伤害同时对一类防具造成伤害
	Real,			## 真实 不对二类防具造成伤害，直接对一类防具造成伤害
	BowlingFront,		## 保龄球正面
	BowlingSide,		## 保龄球侧面
	Hammer,			## 锤子

	}

## Autoload 初始化时只保存路径，避免在启动封面出现前同步加载全部子弹场景。
const BulletTypePathMap: Dictionary[BulletType, String] = {
	BulletType.Bullet001Pea: "res://scenes/bullet/bullet_001_pea.tscn",
	BulletType.Bullet002PeaSnow: "res://scenes/bullet/bullet_002_pea_snow.tscn",
	BulletType.Bullet003Puff: "res://scenes/bullet/bullet_003_puff.tscn",
	BulletType.Bullet004Fume: "res://scenes/bullet/bullet_004_fume.tscn",
	BulletType.Bullet005PuffLongTime: "res://scenes/bullet/bullet_005_puff_long_time.tscn",
	BulletType.Bullet006PeaFire: "res://scenes/bullet/bullet_006_pea_fire.tscn",
	BulletType.Bullet007Cactus: "res://scenes/bullet/bullet_007_cactus.tscn",
	BulletType.Bullet008Star: "res://scenes/bullet/bullet_008_star.tscn",
	BulletType.Bullet009Cabbage: "res://scenes/bullet/bullet_009_cabbage.tscn",
	BulletType.Bullet010Corn: "res://scenes/bullet/bullet_010_corn.tscn",
	BulletType.Bullet011Butter: "res://scenes/bullet/bullet_011_butter.tscn",
	BulletType.Bullet012Melon: "res://scenes/bullet/bullet_012_melon.tscn",
	BulletType.Bullet013Basketball: "res://scenes/bullet/bullet_013_basketball.tscn",
	BulletType.Bullet014CattailBullet: "res://scenes/bullet/bullet_014_cattail_bullet.tscn",
	BulletType.Bullet015WinterMelon: "res://scenes/bullet/bullet_015_winter_melon.tscn",
	BulletType.Bullet016CobCannon: "res://scenes/bullet/bullet_016_cob_cannon.tscn",
	BulletType.Bullet017SnowFume: "res://scenes/bullet/bullet_017_snow_fume.tscn",
	BulletType.Bullet018GiantPea: "res://scenes/bullet/bullet_018_giant_pea.tscn",
	BulletType.Bullet019WidowmakerTracer: "res://scenes/bullet/bullet_019_widowmaker_tracer.tscn",
	BulletType.Bullet020SojournTracer: "res://scenes/bullet/bullet_020_sojourn_tracer.tscn",
	BulletType.Bullet021SeaShroomWuyang: "res://scenes/bullet/bullet_021_sea_shroom_wuyang.tscn",
	BulletType.Bullet022AnranFireWave: "res://scenes/bullet/bullet_022_anran_fire_wave.tscn",
}

var BulletTypeMap: Dictionary[BulletType, PackedScene] = {}


func bullet_scene_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	for scene_path in BulletTypePathMap.values():
		paths.append(String(scene_path))
	return paths


func cache_preloaded_bullet_scene(scene_path: String, packed_scene: PackedScene) -> bool:
	if packed_scene == null:
		return false
	for bullet_type in BulletTypePathMap:
		if BulletTypePathMap[bullet_type] == scene_path:
			BulletTypeMap[bullet_type] = packed_scene
			return true
	return false


## 获取子弹场景方法
func get_bullet_scenes(bullet_type:BulletType) -> PackedScene:
	if BulletTypeMap.has(bullet_type):
		return BulletTypeMap[bullet_type]
	var scene_path: String = BulletTypePathMap.get(bullet_type, "")
	if scene_path.is_empty():
		return null
	var packed_scene := ResourceLoader.load(scene_path, "PackedScene") as PackedScene
	if packed_scene != null:
		BulletTypeMap[bullet_type] = packed_scene
	else:
		push_error("无法加载子弹场景：%s" % scene_path)
	return packed_scene
