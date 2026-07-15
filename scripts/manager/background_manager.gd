extends MainGameSubManager
class_name BackgroundManager
## 背景管理器,管理背景和前景

@onready var background: Sprite2D = %Background
@onready var frontground: Node2D = %Frontground

@onready var home: MainGameHome = %Home
## 泳池
var pool:Pool
## 浓雾
var fog:Fog

## 雨
var rain:MainGameRain

## 雾
const FOG = preload("uid://bs55ei6xiuugg")
const RAIN = preload("uid://cv3iw5srgpusv")
const FRONT_DAY := preload("res://assets/image/background/background1.jpg")
const FRONT_DAY_UNSODDED := preload("res://assets/image/background/background1unsodded.jpg")
const SOD_ONE_ROW := preload("res://assets/image/background/sod1row.jpg")
const SOD_THREE_ROWS := preload("res://assets/image/background/sod3row.jpg")
const SOD_ROLL_BODY := preload("res://assets/reanim/SodRoll.png")
const SOD_ROLL_CAP := preload("res://assets/reanim/SodRollCap.png")
const SOD_REANIM_PATH := "res://assets/reanim/SodRoll.reanim"
const SOD_ALPHA_SHADER := preload("res://shaders/sod_black_to_alpha.gdshader")

var sod_reveal_sprite: Sprite2D
var sod_reveal_source_x := 0.0
var sod_reveal_width := 0.0
var sod_reveal_height := 0.0
var sod_roll_origin_x := 0.0
var sod_roll_instances: Array[Dictionary] = []
var sod_roll_frames: Dictionary = {}


func init_manager() -> void:
	init_background()
	init_frontground()

## 初始化背景
func init_background():
	var curr_bg_texture: Texture2D = ConstLevelData.GameBgTextureMap[game_para.game_BG]
	background.texture = curr_bg_texture
	if game_para.game_BG == ConstLevelData.GameBg.FrontDay:
		_init_sod_layout()
	home.init_home(game_para.game_BG)
	if not game_para.is_zombie_can_home:
		print("僵尸无法进房")
		home.disable_home()
	match game_para.game_BG:
		ConstLevelData.GameBg.Pool, ConstLevelData.GameBg.Fog:
			pool = background.get_node(^"Pool")
			pool.init_pool(game_para)


func _init_sod_layout() -> void:
	match game_para.sod_layout_rows:
		1:
			background.texture = FRONT_DAY_UNSODDED
			_create_sod_reveal(SOD_ONE_ROW, Vector2(239, 265), 0.0, 771.0, 127.0, game_para.sod_rollout_rows != 1)
		3:
			background.texture = FRONT_DAY_UNSODDED
			_create_static_sod(SOD_ONE_ROW, Vector2(239, 265))
			_create_sod_reveal(SOD_THREE_ROWS, Vector2(235, 149), 0.0, 771.0, 355.0, game_para.sod_rollout_rows != 3)
		5:
			if game_para.sod_rollout_rows == 5:
				background.texture = FRONT_DAY_UNSODDED
				_create_sod_reveal(FRONT_DAY, Vector2(232, 0), 232.0, 773.0, 600.0, false)


func _create_static_sod(texture: Texture2D, local_position: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	_apply_sod_alpha_material(sprite, texture)
	sprite.position = local_position
	sprite.centered = false
	sprite.z_index = 1
	background.add_child(sprite)


func _create_sod_reveal(texture: Texture2D, local_position: Vector2, source_x: float, width: float, height: float, revealed: bool) -> void:
	sod_reveal_sprite = Sprite2D.new()
	sod_reveal_sprite.texture = texture
	_apply_sod_alpha_material(sod_reveal_sprite, texture)
	sod_reveal_sprite.position = local_position
	sod_reveal_sprite.centered = false
	sod_reveal_sprite.region_enabled = true
	sod_reveal_sprite.region_filter_clip_enabled = true
	sod_reveal_sprite.z_index = 2
	sod_reveal_source_x = source_x
	sod_reveal_width = width
	sod_reveal_height = height
	sod_roll_origin_x = local_position.x
	background.add_child(sod_reveal_sprite)
	_set_sod_reveal_width(width if revealed else 0.0)


## 使用项目内原版 24 FPS SodRoll.reanim 的逐帧位置、缩放和旋转数据播放 2 秒铺草皮。
func play_sod_rollout_if_needed() -> void:
	if game_para.sod_rollout_rows <= 0 or not is_instance_valid(sod_reveal_sprite):
		return
	sod_roll_frames = _load_sod_roll_frames()
	if sod_roll_frames.is_empty():
		_set_sod_reveal_width(sod_reveal_width)
		return
	var row_offsets: Array[float]
	match game_para.sod_rollout_rows:
		1:
			row_offsets = [0.0]
		3:
			row_offsets = [-102.0, 111.0]
		5:
			row_offsets = [-198.0, -102.0, 0.0, 111.0, 203.0]
		_:
			row_offsets = []
	for row_offset in row_offsets:
		_create_sod_roll_instance(row_offset)
	var sod_sound: AudioStreamPlayer = SoundManager.play_character_SFX("digger_zombie")
	var tween := create_tween()
	tween.tween_method(_apply_sod_roll_progress, 0.0, 1.0, 2.0)
	await tween.finished
	if is_instance_valid(sod_sound):
		sod_sound.stop()
	_apply_sod_roll_progress(1.0)
	_set_sod_reveal_width(sod_reveal_width)
	for instance in sod_roll_instances:
		(instance["root"] as Node2D).queue_free()
	sod_roll_instances.clear()


func _create_sod_roll_instance(row_offset: float) -> void:
	var root := Node2D.new()
	## reanim 的 x 坐标以草皮贴图左边缘为原点；必须补上草皮在背景中的本地 x。
	root.position = Vector2(sod_roll_origin_x, row_offset)
	root.z_index = 20
	background.add_child(root)
	var body := Sprite2D.new()
	body.texture = SOD_ROLL_BODY
	body.centered = false
	root.add_child(body)
	var cap := Sprite2D.new()
	cap.texture = SOD_ROLL_CAP
	cap.centered = false
	cap.z_index = 1
	root.add_child(cap)
	sod_roll_instances.append({"root": root, "body": body, "cap": cap})


func _apply_sod_roll_progress(progress: float) -> void:
	var body_frames: Array = sod_roll_frames.get("SodRoll", [])
	var cap_frames: Array = sod_roll_frames.get("SodRollCap", [])
	if body_frames.is_empty() or cap_frames.is_empty():
		return
	var frame_index := mini(body_frames.size() - 1, floori(clampf(progress, 0.0, 1.0) * float(body_frames.size() - 1)))
	var body_frame: Dictionary = body_frames[frame_index]
	var cap_frame: Dictionary = cap_frames[mini(frame_index, cap_frames.size() - 1)]
	## 直接使用卷起草皮本体的逐帧 x 作为展开边界，避免 Tween 线性宽度与原动画错位。
	_set_sod_reveal_width(float(body_frame.get("x", 0.0)))
	for instance in sod_roll_instances:
		_apply_sod_frame(instance["body"] as Sprite2D, body_frame)
		_apply_sod_frame(instance["cap"] as Sprite2D, cap_frame)


func _apply_sod_frame(sprite: Sprite2D, frame: Dictionary) -> void:
	sprite.position = Vector2(float(frame.get("x", 0.0)), float(frame.get("y", 0.0)))
	sprite.scale = Vector2(float(frame.get("sx", 1.0)), float(frame.get("sy", 1.0)))
	sprite.rotation = deg_to_rad(fmod(float(frame.get("kx", 0.0)), 360.0))


func _set_sod_reveal_width(width: float) -> void:
	if is_instance_valid(sod_reveal_sprite):
		sod_reveal_sprite.region_rect = Rect2(sod_reveal_source_x, 0.0, clampf(width, 0.0, sod_reveal_width), sod_reveal_height)


func _apply_sod_alpha_material(sprite: Sprite2D, texture: Texture2D) -> void:
	if texture != SOD_ONE_ROW and texture != SOD_THREE_ROWS:
		return
	var material := ShaderMaterial.new()
	material.shader = SOD_ALPHA_SHADER
	sprite.material = material


func _load_sod_roll_frames() -> Dictionary:
	var file := FileAccess.open(SOD_REANIM_PATH, FileAccess.READ)
	if file == null:
		return {}
	var result := {"SodRoll": [], "SodRollCap": []}
	var current_track := ""
	var previous := {"x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "kx": 0.0}
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.begins_with("<name>"):
			current_track = _tag_float_or_text(line, "name")
			previous = {"x": 0.0, "y": 0.0, "sx": 1.0, "sy": 1.0, "kx": 0.0}
		elif line.begins_with("<t>") and result.has(current_track):
			var frame: Dictionary = previous.duplicate()
			for key in ["x", "y", "sx", "sy", "kx"]:
				var text_value := _tag_float_or_text(line, key)
				if not text_value.is_empty():
					frame[key] = float(text_value)
			(result[current_track] as Array).append(frame)
			previous = frame
	file.close()
	return result


func _tag_float_or_text(line: String, tag: String) -> String:
	var start_tag := "<%s>" % tag
	var end_tag := "</%s>" % tag
	var start := line.find(start_tag)
	if start < 0:
		return ""
	start += start_tag.length()
	var finish := line.find(end_tag, start)
	return "" if finish < 0 else line.substr(start, finish - start)

## 初始化前景
func init_frontground():
	if game_para.is_fog:
		fog = FOG.instantiate()
		frontground.add_child(fog)
	if game_para.is_rain:
		rain = RAIN.instantiate()
		frontground.add_child(rain)

func start_next_game_background_manager_update():
	if is_instance_valid(fog):
		fog.fog_outside()
