extends Control
class_name TitleLoadingScreen

const START_MENU_PATH := "res://scenes/main/01StartMenu.tscn"
const ALL_CARDS_PATH := "res://scenes/autoload/all_cards.tscn"
const LOADING_BGM_PATH := "res://assets/audio/BGM/start_menu_bgm.mp3"
const GRASS_FULL_WIDTH := 352.0
const GRASS_LEFT := 351.0
const ROLL_HALF_WIDTH := 36.0
const ROLL_PIVOT_Y := 35.0
const ROLL_VISIBLE_BOTTOM_RADIUS := 33.0
const ROLL_BASELINE_Y := 507.0
const ROLL_START_SCALE := 0.78
const ROLL_END_SCALE := 0.35
const ORNAMENT_GROW_PROGRESS_SPAN := 0.085
const DISPLAY_PROGRESS_SPEED := 0.105
const THREADED_STAGE_END := 0.64
const SESSION_STAGE_END := 0.79
const SPROUT_BODY_TEXTURE := preload("res://assets/reanim/sprout_body.png")
const SPROUT_PETAL_TEXTURE := preload("res://assets/reanim/sprout_petal.png")
const ROCK_SMALL_TEXTURE := preload("res://assets/reanim/PotatoMine_rock1.png")
const ROCK_LARGE_TEXTURE := preload("res://assets/reanim/PotatoMine_rock3.png")
const WINSTON_TEXTURE := preload("res://assets/image/main_game_item/LoadBar_winston.png")
const SWORD_TEXTURE := preload("res://assets/image/main_game_item/LoadBar_sword.png")
const ORNAMENT_LAYOUT := [
	{&"kind": &"sprout", &"progress": 0.10, &"rotation": 0.0},
	{&"kind": &"sword", &"progress": 0.31, &"rotation": 0.0},
	{&"kind": &"sprout", &"progress": 0.54, &"rotation": 0.0},
	{&"kind": &"winston", &"progress": 0.82, &"rotation": 0.0},
]

@onready var grass_clip: Control = $LoadingArea/GrassClip
@onready var ornament_layer: Node2D = $LoadingArea/Ornaments
@onready var grass_roll: TextureRect = $LoadingArea/GrassRoll
@onready var status_label: Label = $LoadingArea/StatusLabel
@onready var enter_button: Button = $LoadingArea/EnterButton
@onready var loadingbar_flower: AudioStreamPlayer = $LoadingbarFlower
@onready var loadingbar_zombie: AudioStreamPlayer = $LoadingbarZombie

var requested_paths := PackedStringArray()
var requested_path_kinds: Dictionary[String, StringName] = {}
var requested_path_types: Dictionary[String, String] = {}
var finished_paths: Dictionary = {}
var failed_paths: Dictionary = {}
var all_cards_packed_scene: PackedScene
var actual_progress := 0.0
var display_progress := 0.0
var loading_started := false
var finalizing_startup := false
var loading_finished := false
var ready_to_enter := false
var changing_scene := false
var loading_ornaments: Array[Node2D] = []
var ornament_reveal_starts: Array[float] = []
var ornament_kinds: Array[StringName] = []
var ornament_base_positions: Array[Vector2] = []
var ornament_sound_played: Array[bool] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	grass_clip.size.x = 0.0
	grass_roll.visible = false
	_build_loading_ornaments()
	enter_button.disabled = true
	enter_button.pressed.connect(_enter_start_menu)
	call_deferred("_start_threaded_loading")


func _process(delta: float) -> void:
	if loading_started:
		_poll_threaded_loading()

	## 视觉进度不超过真实进度，有进度积压时以恒定速度向前，避免资源分批完成导致草团忽快忽慢。
	display_progress = move_toward(
		display_progress,
		actual_progress,
		delta * DISPLAY_PROGRESS_SPEED
	)
	_update_progress_visual()

	if loading_finished and display_progress >= 0.999 and not ready_to_enter:
		_finish_loading_animation()


func _unhandled_input(event: InputEvent) -> void:
	if not ready_to_enter or changing_scene:
		return
	if event.is_action_pressed(&"ui_accept"):
		_enter_start_menu()


func _start_threaded_loading() -> void:
	## 先让轻量启动场景进入一帧，并在播放声音前应用当前用户的音量配置。
	await get_tree().process_frame
	await Global.initialize_startup_preferences()
	_queue_startup_path(LOADING_BGM_PATH, &"bgm", "AudioStream")
	for scene_path in Global.adventure_scene_cache_paths():
		_queue_startup_path(scene_path, &"adventure")
	_queue_startup_path(ALL_CARDS_PATH, &"all_cards")
	for scene_path in Global.character_registry.character_scene_paths():
		_queue_startup_path(scene_path, &"character")
	for scene_path in Global.bullet_registry.bullet_scene_paths():
		_queue_startup_path(scene_path, &"bullet")
	for scene_path in SceneRegistry.scene_paths():
		_queue_startup_path(scene_path, &"registry")
	loading_started = true

	for scene_path in requested_paths:
		var request_error := ResourceLoader.load_threaded_request(
			scene_path,
			requested_path_types[scene_path],
			false,
			ResourceLoader.CACHE_MODE_REUSE
		)
		if request_error != OK:
			failed_paths[scene_path] = request_error

	if requested_paths.is_empty() and not finalizing_startup:
		finalizing_startup = true
		call_deferred("_finalize_startup")


func _queue_startup_path(
		scene_path: String,
		kind: StringName,
		resource_type: String = "PackedScene") -> void:
	if scene_path.is_empty() or requested_paths.has(scene_path):
		return
	requested_paths.append(scene_path)
	requested_path_kinds[scene_path] = kind
	requested_path_types[scene_path] = resource_type


func _poll_threaded_loading() -> void:
	var progress_sum := 0.0
	var terminal_count := 0

	for scene_path in requested_paths:
		if finished_paths.has(scene_path):
			progress_sum += 1.0
			terminal_count += 1
			continue
		if failed_paths.has(scene_path):
			progress_sum += 1.0
			terminal_count += 1
			continue

		var progress_values: Array = []
		var status := ResourceLoader.load_threaded_get_status(scene_path, progress_values)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				if not progress_values.is_empty():
					progress_sum += clampf(float(progress_values[0]), 0.0, 1.0)
			ResourceLoader.THREAD_LOAD_LOADED:
				var loaded_resource := ResourceLoader.load_threaded_get(scene_path) as Resource
				if loaded_resource != null and _cache_loaded_startup_resource(scene_path, loaded_resource):
					finished_paths[scene_path] = true
					progress_sum += 1.0
				else:
					failed_paths[scene_path] = ERR_CANT_OPEN
				terminal_count += 1
			ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
				failed_paths[scene_path] = ERR_CANT_OPEN
				terminal_count += 1

	actual_progress = THREADED_STAGE_END * progress_sum / maxf(float(requested_paths.size()), 1.0)
	if terminal_count == requested_paths.size() and not finalizing_startup:
		loading_started = false
		finalizing_startup = true
		if not failed_paths.is_empty():
			push_warning("启动封面后台加载失败的资源：%s" % [failed_paths.keys()])
		call_deferred("_finalize_startup")


func _cache_loaded_startup_resource(scene_path: String, loaded_resource: Resource) -> bool:
	match requested_path_kinds.get(scene_path, &""):
		&"bgm":
			var loading_bgm := loaded_resource as AudioStream
			if loading_bgm == null:
				return false
			## 与主菜单沿用同一播放器响度；切场景时只续播，不再二次升降音量。
			SoundManager.play_bgm(loading_bgm)
		&"all_cards":
			var packed_scene := loaded_resource as PackedScene
			if packed_scene == null:
				return false
			all_cards_packed_scene = packed_scene
		&"adventure":
			var packed_scene := loaded_resource as PackedScene
			if packed_scene == null:
				return false
			Global.cache_adventure_scene(scene_path, packed_scene)
		&"character":
			var packed_scene := loaded_resource as PackedScene
			if packed_scene == null:
				return false
			Global.character_registry.cache_preloaded_character_scene(scene_path, packed_scene)
		&"bullet":
			var packed_scene := loaded_resource as PackedScene
			if packed_scene == null:
				return false
			Global.bullet_registry.cache_preloaded_bullet_scene(scene_path, packed_scene)
		&"registry":
			var packed_scene := loaded_resource as PackedScene
			if packed_scene == null:
				return false
			SceneRegistry.cache_preloaded_scene(scene_path, packed_scene)
		_:
			return false
	return true


func _finalize_startup() -> void:
	if failed_paths.has(START_MENU_PATH) or all_cards_packed_scene == null:
		status_label.text = "启动资源加载失败"
		return

	await Global.initialize_startup_session(_on_session_progress)
	actual_progress = SESSION_STAGE_END
	await get_tree().process_frame

	await AllCards.hydrate_from_packed_scene(all_cards_packed_scene, _on_all_cards_progress)
	if AllCards.all_plant_card_prefabs.is_empty() or AllCards.all_zombie_card_prefabs.is_empty():
		push_error("启动时卡牌目录装配失败")
		status_label.text = "卡牌资源初始化失败"
		return
	actual_progress = 1.0
	loading_finished = true


func _on_session_progress(progress: float) -> void:
	actual_progress = maxf(
		actual_progress,
		lerpf(THREADED_STAGE_END, SESSION_STAGE_END, progress)
	)


func _on_all_cards_progress(progress: float) -> void:
	actual_progress = maxf(
		actual_progress,
		lerpf(SESSION_STAGE_END, 0.99, progress)
	)


func _update_progress_visual() -> void:
	grass_clip.size.x = GRASS_FULL_WIDTH * display_progress
	_update_loading_ornaments()
	## 草皮从第一帧就贴紧土地上沿，只沿 X 轴展开；不再从错误高度向上漂移。
	grass_clip.position.y = 476.0
	if display_progress > 0.005 and display_progress < 0.999:
		grass_roll.visible = true
		## 草团均匀缩到与绿色草皮主体厚度相近的尺寸；加载结束前不再收成小点。
		var roll_scale := lerpf(ROLL_START_SCALE, ROLL_END_SCALE, display_progress)
		## 草团中心与草皮裁剪前沿共用同一个 X 坐标。
		## 不再把动态半径混入路程插值，避免前期草团超前、后期草皮反超。
		var roll_center_x := GRASS_LEFT + GRASS_FULL_WIDTH * display_progress
		grass_roll.position.x = roll_center_x - ROLL_HALF_WIDTH
		## 围绕中心旋转，但根据当前缩放反向补偿 Y，使可见底部切线始终锁在同一高度。
		grass_roll.position.y = (
			ROLL_BASELINE_Y
			- ROLL_PIVOT_Y
			- ROLL_VISIBLE_BOTTOM_RADIUS * roll_scale
		)
		grass_roll.rotation = display_progress * TAU * 6.0
		grass_roll.scale = Vector2.ONE * roll_scale
		grass_roll.modulate.a = 1.0
	else:
		grass_roll.visible = false


func _build_loading_ornaments() -> void:
	for layout: Dictionary in ORNAMENT_LAYOUT:
		var ornament := Node2D.new()
		var reveal_progress := float(layout[&"progress"])
		ornament.position = Vector2(
			GRASS_LEFT + GRASS_FULL_WIDTH * reveal_progress,
			468.0
		)
		ornament.rotation = float(layout[&"rotation"])
		ornament_layer.add_child(ornament)
		match layout[&"kind"]:
			&"sprout":
				_build_sprout_ornament(ornament)
			&"sword":
				_build_sword_ornament(ornament)
			&"winston":
				_build_winston_ornament(ornament)
		ornament.visible = false
		loading_ornaments.append(ornament)
		ornament_kinds.append(layout[&"kind"] as StringName)
		ornament_base_positions.append(ornament.position)
		ornament_sound_played.append(false)
		## 草团中心越过装饰物后才开始出现，避免装饰提前进入未加载区域。
		ornament_reveal_starts.append(reveal_progress + 0.012)


func _build_sprout_ornament(root: Node2D) -> void:
	## 严格沿用 LoadBar_sprout.reanim 的最终轨道顺序；六块泥土彼此重叠形成紧密土团。
	_add_ornament_sprite(root, ROCK_LARGE_TEXTURE, Vector2(5.2, 22.6), Vector2.ONE * 0.20, deg_to_rad(15.0))
	_add_ornament_sprite(root, SPROUT_BODY_TEXTURE, Vector2(-1.5, 4.5), Vector2(0.80, 0.753))
	_add_ornament_sprite(root, ROCK_LARGE_TEXTURE, Vector2(-0.2, 29.6), Vector2.ONE * 0.424, deg_to_rad(-119.9))
	_add_ornament_sprite(root, ROCK_LARGE_TEXTURE, Vector2(6.0, 22.5), Vector2(0.382, 0.359))
	_add_ornament_sprite(root, ROCK_LARGE_TEXTURE, Vector2(1.2, 24.1), Vector2.ONE * 0.20, deg_to_rad(15.0))
	_add_ornament_sprite(root, ROCK_LARGE_TEXTURE, Vector2(6.4, 24.9), Vector2.ONE * 0.20, deg_to_rad(15.0))
	_add_ornament_sprite(root, ROCK_SMALL_TEXTURE, Vector2(2.1, 28.9), Vector2.ONE * 0.555, deg_to_rad(-104.9))
	_add_ornament_sprite(root, SPROUT_PETAL_TEXTURE, Vector2(5.0, -6.4), Vector2.ONE * 0.80, deg_to_rad(84.5), deg_to_rad(-2.0))
	_add_ornament_sprite(root, SPROUT_PETAL_TEXTURE, Vector2(11.1, -4.1), Vector2.ONE * 0.80, deg_to_rad(135.0), deg_to_rad(-179.9))
	_add_ornament_sprite(root, SPROUT_PETAL_TEXTURE, Vector2(-5.7, 1.5), Vector2.ONE * 0.80, 0.127)


func _build_sword_ornament(root: Node2D) -> void:
	## 透明内容边界为 (152, 18)-(422, 484)；按截图将可见高度缩至约 77 px。
	_add_ornament_sprite(root, SWORD_TEXTURE, Vector2(-47.4, -47.9), Vector2.ONE * 0.165)


func _build_winston_ornament(root: Node2D) -> void:
	## 透明内容边界为 (75, 178)-(454, 431)；按截图将可见宽度缩至约 76 px。
	_add_ornament_sprite(root, WINSTON_TEXTURE, Vector2(-52.9, -54.2), Vector2.ONE * 0.20)


func _add_ornament_sprite(
		root: Node2D,
		texture: Texture2D,
		position_value: Vector2,
		scale_value: Vector2,
		rotation_value: float = 0.0,
		skew_value: float = 0.0) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	## 原版 reanim 的 x/y 是贴图左上角坐标，不是中心点坐标。
	sprite.centered = false
	sprite.position = position_value
	sprite.scale = scale_value
	sprite.rotation = rotation_value
	sprite.skew = skew_value
	root.add_child(sprite)


func _update_loading_ornaments() -> void:
	for ornament_index in loading_ornaments.size():
		var ornament := loading_ornaments[ornament_index]
		var reveal_start := ornament_reveal_starts[ornament_index]
		var growth := smoothstep(
			reveal_start,
			reveal_start + ORNAMENT_GROW_PROGRESS_SPAN,
			display_progress
		)
		if growth > 0.001 and not ornament_sound_played[ornament_index]:
			ornament_sound_played[ornament_index] = true
			loadingbar_flower.play()
			if ornament_index == loading_ornaments.size() - 1:
				loadingbar_zombie.play()
		ornament.visible = growth > 0.001
		if not ornament.visible:
			continue
		ornament.position = ornament_base_positions[ornament_index]
		if ornament_kinds[ornament_index] == &"winston":
			## 坐姿温斯顿保持完整宽高比，只从草皮后轻微上浮并淡入，不再压缩成小点。
			var settle := smoothstep(0.0, 1.0, growth)
			var uniform_scale := lerpf(0.92, 1.0, settle) + sin(settle * PI) * 0.025
			ornament.scale = Vector2.ONE * uniform_scale
			ornament.position.y += lerpf(7.0, 0.0, settle) - sin(settle * PI) * 1.5
			ornament.modulate.a = smoothstep(0.0, 0.22, growth)
			continue
		var pop_scale := 1.0 + sin(growth * PI) * 0.10
		ornament.scale = Vector2(
			lerpf(0.28, pop_scale, growth),
			lerpf(0.04, pop_scale, growth)
		)
		ornament.modulate.a = smoothstep(0.0, 0.18, growth)


func _finish_loading_animation() -> void:
	ready_to_enter = true
	enter_button.disabled = false
	enter_button.focus_mode = Control.FOCUS_ALL
	enter_button.grab_focus()
	status_label.text = "点击开始"

	var label_tween := status_label.create_tween().set_loops()
	label_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	label_tween.tween_property(status_label, ^"modulate:a", 0.58, 0.7)
	label_tween.tween_property(status_label, ^"modulate:a", 1.0, 0.7)


func _enter_start_menu() -> void:
	if not ready_to_enter or changing_scene:
		return
	if not Global.adventure_scene_cache.has(START_MENU_PATH):
		status_label.text = "主菜单资源加载失败"
		status_label.modulate = Color.WHITE
		return

	changing_scene = true
	enter_button.disabled = true
	status_label.text = "正在进入游戏……"
	var fade_tween := create_tween()
	fade_tween.tween_property(self, ^"modulate:a", 0.0, 0.22)
	await fade_tween.finished
	var change_error := Global.change_scene_to_cached(START_MENU_PATH)
	if change_error != OK:
		changing_scene = false
		modulate.a = 1.0
		status_label.text = "无法进入主菜单"
		enter_button.disabled = false
