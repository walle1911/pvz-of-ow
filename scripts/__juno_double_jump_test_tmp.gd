extends Node


func _init() -> void:
	call_deferred(&"run_test")


func run_test() -> void:
	var juno_scene:PackedScene = load("res://scenes/character/plant/plant_013_hypno_shroom_juno.tscn")
	var zombie_scene:PackedScene = load("res://scenes/character/zombie/zombie_501_norm.tscn")
	var juno = juno_scene.instantiate()
	var zombie = zombie_scene.instantiate()
	juno.character_init_type = Character000Base.E_CharacterInitType.IsShow
	zombie.character_init_type = Character000Base.E_CharacterInitType.IsShow
	add_child(juno)
	add_child(zombie)
	await get_tree().process_frame
	juno._pulsar_body_rest_position = juno.body.position
	juno._pulsar_body_rest_scale = juno.body.scale
	var hp_before_bite:int = juno.hp_component.curr_hp
	juno._pulsar_bite_invulnerable = true
	juno.be_zombie_eat(10, zombie)
	juno.be_zombie_eat_once(zombie)
	assert(juno.hp_component.curr_hp == hp_before_bite)
	assert(not juno.is_death)
	juno._pulsar_targets.append(zombie)
	juno._pulsar_is_targeting = true
	juno._pulsar_phase = juno.E_PulsarPhase.FirstJump
	var first_jump_duration:float = juno._get_pulsar_first_jump_duration()
	juno._pulsar_phase_elapsed = first_jump_duration * 0.5
	juno._update_first_jump()
	assert(juno.body.position.y < juno._pulsar_body_rest_position.y)
	assert(juno.body.position.y > juno._pulsar_body_rest_position.y - juno.pulsar_first_jump_height)
	juno._pulsar_phase_elapsed = first_jump_duration
	juno._update_first_jump()
	assert(juno._pulsar_phase == juno.E_PulsarPhase.SecondJumpAscent)
	assert(is_equal_approx(
		juno.body.position.y,
		juno._pulsar_body_rest_position.y - juno._get_pulsar_first_jump_transition_height()
	))
	assert(is_equal_approx(
		juno.body.scale.y,
		juno._pulsar_body_rest_scale.y * juno.pulsar_charge_scale_y
	))
	juno._pulsar_phase_elapsed = juno.pulsar_charge_hold_duration * 0.5
	juno._update_second_jump_ascent(juno.pulsar_charge_hold_duration * 0.5)
	assert(is_equal_approx(
		juno.body.scale.y,
		juno._pulsar_body_rest_scale.y * juno.pulsar_charge_scale_y
	))
	juno._pulsar_phase_elapsed = juno.pulsar_second_jump_ascent_time * 0.5
	juno._update_second_jump_ascent(juno.pulsar_second_jump_ascent_time * 0.5)
	var jump_motion:Vector2 = juno._get_pulsar_jump_motion()
	var half_ascent_time:float = juno.pulsar_second_jump_ascent_time * 0.5
	var expected_half_height:float = juno._get_pulsar_first_jump_transition_height() \
		+ juno._get_pulsar_ballistic_height(half_ascent_time, jump_motion)
	assert(is_equal_approx(
		juno.body.position.y,
		juno._pulsar_body_rest_position.y - expected_half_height
	))
	var step:float = 0.1
	juno._pulsar_phase_elapsed = juno.pulsar_second_jump_ascent_time
	juno._pulsar_lock_elapsed[zombie.get_instance_id()] = juno.pulsar_second_jump_ascent_time - step
	juno._update_second_jump_ascent(step)
	assert(juno._pulsar_phase == juno.E_PulsarPhase.ApexHold)
	assert(juno._pulsar_locked.get(zombie.get_instance_id(), false))
	assert(is_equal_approx(
		juno.body.position.y,
		juno._pulsar_body_rest_position.y - juno._get_pulsar_second_jump_apex_height()
	))
	juno._pulsar_phase_elapsed = juno.pulsar_fire_delay
	juno._update_apex_hold()
	assert(juno._pulsar_phase == juno.E_PulsarPhase.Descent)
	juno._pulsar_phase_elapsed = juno.pulsar_descent_time
	juno._update_descent()
	assert(juno._pulsar_phase == juno.E_PulsarPhase.Idle)
	assert(juno.body.position == juno._pulsar_body_rest_position)
	assert(not juno._pulsar_bite_invulnerable)
	juno.be_zombie_eat(10, zombie)
	assert(juno.hp_component.curr_hp == hp_before_bite - 10)
	print("JUNO_DOUBLE_JUMP_TEST_OK")
	get_tree().quit()
