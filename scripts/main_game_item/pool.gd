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
var _target_relic_x := 0.0
var _relic_position_initialized := false

const RELIC_GLOW_PEAK := 1.0
const RELIC_GLOW_INTERVAL := 30.0
const RELIC_GLOW_RISE_DURATION := 0.65
const RELIC_GLOW_PEAK_HOLD := 0.08
const RELIC_GLOW_FALL_DURATION := 1.35
const RELIC_POSITION_FOLLOW_SPEED := 24.0
## 泳池白天图片
const POOL_BASE = preload("res://assets/image/background/pool_base.jpg")
const POOL = preload("res://assets/image/background/pool.jpg")

## 泳池黑夜图片
const POOL_BASE_NIGHT = preload("res://assets/image/background/pool_base_night.jpg")
const POOL_NIGHT = preload("res://assets/image/background/pool_night.jpg")


func _ready() -> void:
	_set_relic_position_from_progress(0.0)
	_set_relic_glow(0.0)
	EventBus.subscribe("main_game_progress_update", _on_main_game_progress_update)
	EventBus.subscribe("main_game_progress_bar_value_updated", _on_progress_bar_value_updated)


func _process(delta: float) -> void:
	if not _relic_position_initialized:
		return
	var follow_weight := 1.0 - exp(-RELIC_POSITION_FOLLOW_SPEED * delta)
	var next_relic_x := lerpf(zenyatta_relic.position.x, _target_relic_x, follow_weight)
	if is_equal_approx(next_relic_x, _target_relic_x):
		next_relic_x = _target_relic_x
	_apply_relic_x(next_relic_x)


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
		relic_glow_timer.wait_time = RELIC_GLOW_INTERVAL
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
	_relic_glow_tween.tween_method(_set_relic_glow, 0.0, RELIC_GLOW_PEAK, RELIC_GLOW_RISE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_relic_glow_tween.tween_interval(RELIC_GLOW_PEAK_HOLD)
	_relic_glow_tween.tween_method(_set_relic_glow, RELIC_GLOW_PEAK, 0.0, RELIC_GLOW_FALL_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _on_progress_bar_value_updated(progress: float) -> void:
	_target_relic_x = _pool_x_from_progress(clampf(progress, 0.0, 100.0))


func _set_relic_position_from_progress(progress: float) -> void:
	var clamped_progress := clampf(progress, 0.0, 100.0)
	_target_relic_x = _pool_x_from_progress(clamped_progress)
	if not _relic_position_initialized:
		_relic_position_initialized = true
		_apply_relic_x(_target_relic_x)


func _apply_relic_x(relic_x: float) -> void:
	zenyatta_relic.position.x = relic_x
	zenyatta_relic_glow.position.x = relic_x - (zenyatta_relic_glow.size.x * 0.5)


func _pool_x_from_progress(progress: float) -> float:
	## 进度条 0% 在右侧、100% 在左侧；中心点向内收光珠半宽，避免光晕越出泳池。
	var pool_width := pool.texture.get_width() * absf(pool.scale.x)
	var pool_right := pool.position.x + pool_width * 0.5
	var pool_left := pool.position.x - pool_width * 0.5
	var glow_half_width := zenyatta_relic_glow.size.x * 0.5
	var rightmost_relic_x := pool_right - glow_half_width
	var leftmost_relic_x := pool_left + glow_half_width
	return lerpf(rightmost_relic_x, leftmost_relic_x, progress * 0.01)


func _set_relic_glow(strength: float) -> void:
	var glow := clampf(strength, 0.0, 1.0)
	zenyatta_relic_material.set_shader_parameter("glow_amount", glow)
	zenyatta_relic_material.set_shader_parameter("underwater_alpha", lerpf(0.0, 0.24, glow))
	zenyatta_relic_glow_material.set_shader_parameter("glow_amount", glow)
