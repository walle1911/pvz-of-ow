extends Plant000Base
class_name Plant052BonkChoyRamattra

@onready var detect_component: DetectComponent = $DetectComponent
@onready var frame_sprite: Sprite2D = $Body/BodyCorrect/FrameSprite

const SEQUENCE_BASE_PATH := "res://assets/image/plant/070_bonk_choy/frame_sequences"
const STATE_IDLE := &"idle"
const STATE_WATERED := &"watered"
const STATE_PLANT_FOOD_START := &"plant_food_start"
const STATE_PLANT_FOOD := &"plant_food"
const STATE_PLANT_FOOD_END := &"plant_food_end"
const ATTACK_STATE_FRONT := &"attack_1"
const ATTACK_STATE_BACK := &"attack_2"
const ATTACK_STATE_FRONT_UPPERCUT := &"attack_4"
const ATTACK_STATE_BACK_UPPERCUT := &"attack_5"
const NORMAL_ATTACK_STATES := [ATTACK_STATE_FRONT, ATTACK_STATE_BACK]
const UPPERCUT_ATTACK_STATES := [ATTACK_STATE_FRONT_UPPERCUT, ATTACK_STATE_BACK_UPPERCUT]
const ATTACK_STATES := [
	ATTACK_STATE_FRONT,
	ATTACK_STATE_BACK,
	ATTACK_STATE_FRONT_UPPERCUT,
	ATTACK_STATE_BACK_UPPERCUT,
]
const SIDE_FRONT := 1
const SIDE_BACK := -1

const FRAME_COUNTS := {
	STATE_IDLE: 30,
	ATTACK_STATE_FRONT: 10,
	ATTACK_STATE_BACK: 10,
	ATTACK_STATE_FRONT_UPPERCUT: 15,
	ATTACK_STATE_BACK_UPPERCUT: 15,
	STATE_PLANT_FOOD_START: 30,
	STATE_PLANT_FOOD: 30,
	STATE_PLANT_FOOD_END: 10,
	STATE_WATERED: 15,
}

const STATE_ANCHORS := {
	STATE_IDLE: Vector2(119.5, 207.0),
	ATTACK_STATE_FRONT: Vector2(154.5, 318.0),
	ATTACK_STATE_BACK: Vector2(280.5, 318.0),
	ATTACK_STATE_FRONT_UPPERCUT: Vector2(144.0, 323.0),
	ATTACK_STATE_BACK_UPPERCUT: Vector2(180.0, 323.0),
	STATE_PLANT_FOOD_START: Vector2(153.0, 171.0),
	STATE_PLANT_FOOD: Vector2(282.5, 505.0),
	STATE_PLANT_FOOD_END: Vector2(154.5, 171.0),
	STATE_WATERED: Vector2(138.5, 179.0),
}

const STATE_SCALES := {
	STATE_IDLE: 0.44,
	ATTACK_STATE_FRONT: 0.48,
	ATTACK_STATE_BACK: 0.48,
	ATTACK_STATE_FRONT_UPPERCUT: 0.48,
	ATTACK_STATE_BACK_UPPERCUT: 0.48,
}

const ATTACK_HIT_FRAMES := {
	ATTACK_STATE_FRONT: 3,
	ATTACK_STATE_BACK: 3,
	ATTACK_STATE_FRONT_UPPERCUT: 5,
	ATTACK_STATE_BACK_UPPERCUT: 5,
}

const PLANT_FOOD_HIT_FRAMES := [6, 12, 18, 24]

@export var attack_value := 15
@export var uppercut_attack_multiplier := 2.0
@export_range(1, 99, 1) var normal_attacks_before_uppercut := 15
@export var plant_food_attack_value := 45
@export var frame_time := 0.033
@export var frame_scale := 0.55
@export_group("动画平滑")
@export var idle_frame_blend_enabled := false
@export_range(0.0, 1.0, 0.05) var idle_frame_blend_strength := 1.0
@export_group("动画状态")
@export var is_attack := false
@export var is_plant_food := false

var _frames := {}
var _state: StringName = STATE_IDLE
var _frame_index := 0
var _frame_elapsed := 0.0
var _is_looping := true
var _sequence_queue := []
var _attack_side := SIDE_FRONT
var _has_hit_current_attack := false
var _plant_food_hits_done := {}
var _speed_product := 1.0
var _attack_speed_multiplier_sources:Dictionary[int, float] = {}
var _is_frames_loaded := false
var _normal_attack_streak_side := 0
var _normal_attack_streak_count := 0
var _frame_blend_sprite: Sprite2D = null


func ready_norm() -> void:
	_ensure_frames_loaded()
	super()
	_play_state_loop(STATE_IDLE)
	detect_component.need_judge = true


func ready_show() -> void:
	## 选关页和图鉴展示只需 idle，不应为未提供的 watered 帧反复报错。
	_ensure_frames_loaded([STATE_IDLE])
	super()
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	_play_state_loop(STATE_IDLE)


func ready_garden() -> void:
	_ensure_frames_loaded()
	super()
	detect_component.disable_component(ComponentNormBase.E_IsEnableFactor.InitType)
	_play_state_loop(STATE_IDLE)


func ready_norm_signal_connect():
	super()
	signal_update_speed.connect(owner_update_speed)
	detect_component.signal_can_attack.connect(_on_detect_can_attack)
	detect_component.signal_not_can_attack.connect(_on_detect_not_can_attack)


func _process(delta: float) -> void:
	if is_death or _speed_product <= 0.0:
		return
	if _frames.is_empty():
		return

	_frame_elapsed += delta * _speed_product * get_attack_speed_multiplier()
	while _frame_elapsed >= frame_time:
		_frame_elapsed -= frame_time
		_advance_frame()
	_update_frame_blend()


func owner_update_speed(speed_product: float):
	_speed_product = speed_product


func add_attack_speed_multiplier(source:Object, multiplier:float):
	if not is_instance_valid(source):
		return
	_attack_speed_multiplier_sources[source.get_instance_id()] = maxf(multiplier, 0.0)


func remove_attack_speed_multiplier(source:Object):
	if not is_instance_valid(source):
		return
	_attack_speed_multiplier_sources.erase(source.get_instance_id())


func get_attack_speed_multiplier() -> float:
	var result := 1.0
	for multiplier:float in _attack_speed_multiplier_sources.values():
		result = maxf(result, multiplier)
	return result


func play_plant_food():
	if is_death or is_plant_food:
		return

	is_plant_food = true
	is_attack = false
	_reset_normal_attack_streak()
	_sequence_queue = [STATE_PLANT_FOOD, STATE_PLANT_FOOD_END]
	_play_state_once(STATE_PLANT_FOOD_START)


func satisfy_need(item: GardenManager.E_NeedItem):
	var should_play_watered := false
	if is_instance_valid(garden_component):
		should_play_watered = character_init_type == E_CharacterInitType.IsGarden \
				and item == GardenManager.E_NeedItem.WateringCan \
				and garden_component.curr_need_item == GardenManager.E_NeedItem.WateringCan

	super(item)

	if should_play_watered and not is_plant_food:
		is_attack = false
		_reset_normal_attack_streak()
		_play_state_once(STATE_WATERED)


func _ensure_frames_loaded(states: Array = FRAME_COUNTS.keys()):
	if _is_frames_loaded:
		return

	for state in states:
		var textures := []
		var frame_count: int = FRAME_COUNTS[state]
		for frame_number in range(frame_count):
			var path := "%s/%s/%03d.png" % [SEQUENCE_BASE_PATH, String(state), frame_number]
			var texture := load(path) as Texture2D
			if texture == null:
				push_warning("菜问帧丢失: " + path)
				continue
			textures.append(texture)
		_frames[state] = textures

	_is_frames_loaded = true


func _on_detect_can_attack():
	if is_attack or is_plant_food or _state == STATE_WATERED:
		return
	_start_next_attack()


func _on_detect_not_can_attack():
	if not is_attack and not is_plant_food and _state != STATE_WATERED:
		_play_state_loop(STATE_IDLE)


func _start_next_attack(preferred_side := 0):
	if is_plant_food or is_death:
		return
	var target := _get_attack_target(preferred_side)
	if target == null and preferred_side != 0:
		target = _get_attack_target()
	if not is_instance_valid(target):
		_play_state_loop(STATE_IDLE)
		return

	_attack_side = _get_side_for_target(target)
	var attack_state := _get_attack_state_for_side(_attack_side)
	if _should_use_uppercut(_attack_side):
		attack_state = _get_uppercut_attack_state_for_side(_attack_side)
	is_attack = true
	_play_state_once(attack_state)


func _play_state_loop(state: StringName):
	_state = state
	_frame_index = 0
	_frame_elapsed = 0.0
	_is_looping = true
	_has_hit_current_attack = false
	if state == STATE_IDLE:
		_reset_normal_attack_streak()
	_apply_frame()


func _play_state_once(state: StringName):
	_state = state
	_frame_index = 0
	_frame_elapsed = 0.0
	_is_looping = false
	_has_hit_current_attack = false
	if state == STATE_PLANT_FOOD:
		_plant_food_hits_done.clear()
	_apply_frame()


func _advance_frame():
	var textures: Array = _frames.get(_state, [])
	if textures.is_empty():
		return

	_frame_index += 1
	if _frame_index >= textures.size():
		if _is_looping:
			_frame_index = 0
			_apply_frame()
		else:
			_on_state_finished()
		return

	_apply_frame()
	_handle_frame_events()


func _apply_frame():
	var textures: Array = _frames.get(_state, [])
	if textures.is_empty():
		return

	_frame_index = clampi(_frame_index, 0, textures.size() - 1)
	var state_scale := _get_state_scale(_state)
	frame_sprite.texture = textures[_frame_index]
	frame_sprite.centered = false
	frame_sprite.scale = Vector2(state_scale, state_scale)
	frame_sprite.position = -STATE_ANCHORS.get(_state, STATE_ANCHORS[STATE_IDLE]) * state_scale
	_update_frame_blend()


func _get_state_scale(state: StringName) -> float:
	return float(STATE_SCALES.get(state, frame_scale))


func _update_frame_blend():
	if not _should_blend_state(_state) or frame_time <= 0.0:
		_hide_frame_blend()
		return

	var textures: Array = _frames.get(_state, [])
	if textures.size() <= 1:
		_hide_frame_blend()
		return

	var next_frame_index := _frame_index + 1
	if next_frame_index >= textures.size():
		if _is_looping:
			next_frame_index = 0
		else:
			_hide_frame_blend()
			return

	var blend_sprite := _ensure_frame_blend_sprite()
	var blend_alpha := clampf(_frame_elapsed / frame_time, 0.0, 1.0) * clampf(idle_frame_blend_strength, 0.0, 1.0)
	var state_scale := _get_state_scale(_state)
	frame_sprite.self_modulate = Color(1.0, 1.0, 1.0, 1.0 - blend_alpha)
	blend_sprite.visible = blend_alpha > 0.0
	blend_sprite.texture = textures[next_frame_index]
	blend_sprite.centered = false
	blend_sprite.scale = Vector2(state_scale, state_scale)
	blend_sprite.position = frame_sprite.position
	blend_sprite.self_modulate = Color(1.0, 1.0, 1.0, blend_alpha)


func _should_blend_state(state: StringName) -> bool:
	return idle_frame_blend_enabled and state == STATE_IDLE


func _ensure_frame_blend_sprite() -> Sprite2D:
	if is_instance_valid(_frame_blend_sprite):
		return _frame_blend_sprite

	_frame_blend_sprite = Sprite2D.new()
	_frame_blend_sprite.name = "FrameBlendSprite"
	_frame_blend_sprite.centered = false
	_frame_blend_sprite.visible = false
	frame_sprite.get_parent().add_child(_frame_blend_sprite)
	frame_sprite.get_parent().move_child(_frame_blend_sprite, frame_sprite.get_index() + 1)
	return _frame_blend_sprite


func _hide_frame_blend():
	frame_sprite.self_modulate = Color.WHITE
	if is_instance_valid(_frame_blend_sprite):
		_frame_blend_sprite.visible = false
		_frame_blend_sprite.texture = null


func _handle_frame_events():
	if ATTACK_HIT_FRAMES.has(_state) and not _has_hit_current_attack:
		if _frame_index >= ATTACK_HIT_FRAMES[_state]:
			_has_hit_current_attack = true
			_attack_once()
	elif _state == STATE_PLANT_FOOD:
		for hit_frame: int in PLANT_FOOD_HIT_FRAMES:
			if _frame_index >= hit_frame and not _plant_food_hits_done.has(hit_frame):
				_plant_food_hits_done[hit_frame] = true
				_plant_food_hit_once()


func _on_state_finished():
	if not _sequence_queue.is_empty():
		_play_state_once(_sequence_queue.pop_front())
		return

	if _is_attack_state(_state):
		if _is_normal_attack_state(_state):
			_record_completed_normal_attack(_state)
		elif _is_uppercut_attack_state(_state):
			_reset_normal_attack_streak()
		is_attack = false
		if _get_attack_target(_attack_side) != null:
			_start_next_attack(_attack_side)
		else:
			_resume_idle_or_attack()
		return

	if _state == STATE_PLANT_FOOD_END:
		is_plant_food = false
		_resume_idle_or_attack()
		return

	if _state == STATE_WATERED:
		_resume_idle_or_attack()
		return

	_play_state_loop(STATE_IDLE)


func _resume_idle_or_attack():
	if character_init_type == E_CharacterInitType.IsNorm and _has_attack_target():
		_start_next_attack()
	else:
		_play_state_loop(STATE_IDLE)


func _is_attack_state(state: StringName) -> bool:
	return ATTACK_STATES.has(state)


func _is_normal_attack_state(state: StringName) -> bool:
	return NORMAL_ATTACK_STATES.has(state)


func _is_uppercut_attack_state(state: StringName) -> bool:
	return UPPERCUT_ATTACK_STATES.has(state)


func _has_attack_target() -> bool:
	if not is_instance_valid(detect_component):
		return false
	return _get_attack_target() != null


func _get_attack_target(preferred_side := 0) -> Zombie000Base:
	var target: Zombie000Base = null
	var min_distance := INF
	var all_enemy_can_be_attacked := detect_component.get_all_enemy_can_be_attacked()
	for enemy: Character000Base in all_enemy_can_be_attacked:
		if not is_instance_valid(enemy) or not enemy is Zombie000Base:
			continue
		var enemy_side := _get_side_for_target(enemy)
		if preferred_side != 0 and enemy_side != preferred_side:
			continue
		var distance := absf(to_local(enemy.global_position).x)
		if distance < min_distance:
			min_distance = distance
			target = enemy as Zombie000Base
	return target


func _get_side_for_target(target: Character000Base) -> int:
	if to_local(target.global_position).x >= 0.0:
		return SIDE_FRONT
	return SIDE_BACK


func _get_attack_state_for_side(side: int) -> StringName:
	if side == SIDE_BACK:
		return ATTACK_STATE_BACK
	return ATTACK_STATE_FRONT


func _get_uppercut_attack_state_for_side(side: int) -> StringName:
	if side == SIDE_BACK:
		return ATTACK_STATE_BACK_UPPERCUT
	return ATTACK_STATE_FRONT_UPPERCUT


func _get_side_for_attack_state(state: StringName) -> int:
	if state == ATTACK_STATE_BACK or state == ATTACK_STATE_BACK_UPPERCUT:
		return SIDE_BACK
	return SIDE_FRONT


func _should_use_uppercut(side: int) -> bool:
	return _normal_attack_streak_side == side \
			and _normal_attack_streak_count >= normal_attacks_before_uppercut


func _record_completed_normal_attack(state: StringName):
	var side := _get_side_for_attack_state(state)
	if _normal_attack_streak_side == side:
		_normal_attack_streak_count += 1
	else:
		_normal_attack_streak_side = side
		_normal_attack_streak_count = 1


func _reset_normal_attack_streak():
	_normal_attack_streak_side = 0
	_normal_attack_streak_count = 0


func _attack_once():
	var target := _get_attack_target(_attack_side)
	if not is_instance_valid(target):
		return

	SoundManager.play_other_SFX(&"bonk")
	var attack_multiplier := uppercut_attack_multiplier if _is_uppercut_attack_state(_state) else 1.0
	var final_attack_value := int(round(attack_value * attack_multiplier * get_attack_damage_multiplier()))
	target.be_attacked_bullet(final_attack_value, BulletRegistry.AttackMode.Real, true, true)


func _plant_food_hit_once():
	var final_attack_value := int(round(plant_food_attack_value * get_attack_damage_multiplier()))
	var all_enemy_can_be_attacked := detect_component.get_all_enemy_can_be_attacked()
	if all_enemy_can_be_attacked.is_empty():
		return

	SoundManager.play_other_SFX(&"bonk")
	for enemy: Character000Base in all_enemy_can_be_attacked:
		if enemy is Zombie000Base:
			var zombie := enemy as Zombie000Base
			if is_instance_valid(zombie):
				zombie.be_attacked_bullet(final_attack_value, BulletRegistry.AttackMode.Real, true, true)
