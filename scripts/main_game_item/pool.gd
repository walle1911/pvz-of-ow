extends Node2D
class_name Pool

@onready var pool_drop: ColorRect = $Pool/PoolDrop

@onready var pool_base: Sprite2D = $PoolBase
@onready var pool: Sprite2D = $Pool
@onready var zenyatta_relic: Sprite2D = $ZenyattaTranscendence
@onready var zenyatta_relic_material: ShaderMaterial = zenyatta_relic.material as ShaderMaterial
@onready var zenyatta_relic_glow: Control = $ZenyattaTranscendenceGlow
@onready var zenyatta_relic_glow_material: ShaderMaterial = zenyatta_relic_glow.material as ShaderMaterial
@onready var relic_glow_timer: Timer = $RelicGlowTimer

var _relic_glow_tween: Tween
const RELIC_GLOW_PEAK = 0.58
## 泳池白天图片
const POOL_BASE = preload("res://assets/image/background/pool_base.jpg")
const POOL = preload("res://assets/image/background/pool.jpg")

## 泳池黑夜图片
const POOL_BASE_NIGHT = preload("res://assets/image/background/pool_base_night.jpg")
const POOL_NIGHT = preload("res://assets/image/background/pool_night.jpg")


func _ready() -> void:
	_set_relic_glow(0.0)
	EventBus.subscribe("main_game_progress_update", _on_main_game_progress_update)


func init_pool(game_para:ResourceLevelData):
	match game_para.game_BG:
		ConstLevelData.GameBg.Pool:
			pool_base.texture = POOL_BASE
			pool.texture = POOL

		ConstLevelData.GameBg.Fog:
			pool_base.texture = POOL_BASE_NIGHT
			pool.texture = POOL_NIGHT

	if game_para.is_rain:
		pool_drop.visible = true
		var mat := pool_drop.material
		match game_para.game_BG:
			ConstLevelData.GameBg.Pool:
				mat.set("shader_parameter/drop_color", Color(0.0, 0.914, 0.941, 1.0))
			ConstLevelData.GameBg.Fog:
				mat.set("shader_parameter/drop_color", Color(0.0, 0.502, 0.773, 1.0))
	else:
		pool_drop.visible = false


func _on_main_game_progress_update(progress: MainGameManager.E_MainGameProgress) -> void:
	if progress == MainGameManager.E_MainGameProgress.MAIN_GAME:
		relic_glow_timer.start()
		return
	relic_glow_timer.stop()
	if is_instance_valid(_relic_glow_tween):
		_relic_glow_tween.kill()
	_set_relic_glow(0.0)


func _on_relic_glow_timer_timeout() -> void:
	if not is_instance_valid(zenyatta_relic_material):
		return
	if is_instance_valid(_relic_glow_tween):
		_relic_glow_tween.kill()
	_relic_glow_tween = create_tween()
	_relic_glow_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.0, 0.08, 0.91)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.08, 0.18, 0.26)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.18, RELIC_GLOW_PEAK, 1.17)
	_relic_glow_tween.tween_method(_set_relic_glow, RELIC_GLOW_PEAK, 0.46, 0.78)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.46, 0.54, 0.78)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.54, 0.08, 1.69)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.08, 0.04, 0.26)
	_relic_glow_tween.tween_method(_set_relic_glow, 0.04, 0.0, 0.8775)


func _set_relic_glow(strength: float) -> void:
	var glow := clampf(strength, 0.0, 1.0)
	zenyatta_relic_material.set_shader_parameter("glow_amount", glow)
	zenyatta_relic_material.set_shader_parameter("underwater_alpha", lerpf(0.025, 0.20, glow))
	zenyatta_relic_glow_material.set_shader_parameter("glow_amount", glow)
