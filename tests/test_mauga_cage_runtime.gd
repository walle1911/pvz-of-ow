extends Node

const Policy := preload("res://scripts/resources/numerical_adjustment_policy.gd")
const L10n := preload("res://scripts/ui/numerical_editor/numerical_editor_localization.gd")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	await get_tree().process_frame
	var main_game:= owner as MainGameManager
	if not is_instance_valid(main_game):
		_fail("missing MainGameManager owner")
		return
	var source_cell:PlantCell = main_game.plant_cell_manager.all_plant_cells[2][4]
	var mauga:= source_cell.create_plant(
		CharacterRegistry.PlantType.P037GarlicMauga,
		false,
		false
	) as Plant037GarlicMauga
	await get_tree().process_frame
	if not is_instance_valid(mauga):
		_fail("failed to create Garlic Mauga")
		return
	## 该调试关会覆写角色血量；这里固定为足够完成首次循环的测试血量。
	mauga.hp_component.max_hp = 1000
	mauga.hp_component.curr_hp = 1000
	if Policy.get_rule(mauga, "chain_health_cost").is_empty():
		_fail("health cost is missing from the numerical adjustment whitelist")
		return
	if L10n.property_name("chain_health_cost") != "锁链生命消耗":
		_fail("health cost is missing its numerical editor label")
		return
	if mauga.chain_health_cost != 200:
		_fail("Cage Fight health cost is not 200 HP")
		return
	if not is_equal_approx(mauga.chain_skill_duration, 6.0):
		_fail("Cage Fight duration is not 6 seconds")
		return
	if not is_equal_approx(mauga.chain_lunge_distance, 25.0):
		_fail("Cage Fight pre-jump lunge is not 25 pixels")
		return
	var center_x:float = mauga.shadow.global_position.x
	var selected_columns:PackedInt32Array = mauga.call("_get_cage_column_indices")
	if selected_columns.size() != 3:
		_fail("Cage Fight did not resolve three columns centered on Mauga")
		return
	var lane_cells:Array = main_game.plant_cell_manager.all_plant_cells[2]
	var selected_center_index:int = selected_columns.find(lane_cells.find(source_cell))
	if selected_center_index != 1:
		_fail("Cage Fight was not centered on Mauga's current cell")
		return
	var previous_column_x:float = -INF
	for selected_column:int in selected_columns:
		var selected_cell:PlantCell = lane_cells[selected_column]
		var selected_x:float = selected_cell.plant_container_node[
			CharacterRegistry.PlacePlantInCell.Norm
		].global_position.x
		if selected_x <= previous_column_x:
			_fail("Cage Fight centered columns are not ordered from left to right")
			return
		previous_column_x = selected_x
	var cage_bounds:Rect2 = mauga.call("_get_current_cage_ground_bounds")
	var cage_x_ranges:Dictionary = mauga.call("_get_current_cage_x_ranges")
	if cage_x_ranges.size() != 3:
		_fail("Cage Fight did not resolve three vertical rows")
		return
	var left_cell:= _find_horizontal_neighbor(lane_cells, source_cell, -1)
	if not is_instance_valid(left_cell):
		_fail("test setup has no left cell to verify the removed ninth-grid column")
		return
	var excluded_left:= _spawn_zombie(
		main_game,
		2,
		left_cell.get_global_rect().get_center().x
	)
	var trapped_lane_range:Vector2 = cage_x_ranges[1]
	var trapped:= _spawn_zombie(
		main_game,
		1,
		(trapped_lane_range.x + trapped_lane_range.y) * 0.5
	)
	var forward_cell:PlantCell = mauga.call("_get_forward_plant_cell")
	var forward_landing_x:float = forward_cell.plant_container_node[
		CharacterRegistry.PlacePlantInCell.Norm
	].global_position.x
	var stomp_victim:= _spawn_zombie(
		main_game,
		2,
		forward_landing_x
	)
	var underground_venture:= _spawn_zombie(
		main_game,
		2,
		forward_landing_x,
		CharacterRegistry.ZombieType.Z018DiggerZombieVenture
	)
	var underwater_snorkle:= _spawn_zombie(
		main_game,
		2,
		forward_landing_x,
		CharacterRegistry.ZombieType.Z512Snorkle
	)
	underground_venture.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsDownGround
	underwater_snorkle.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsDownPool
	var stomp_visual_parent:= stomp_victim.get_parent()
	var flattened_body_count_before:= _count_flattened_body_copies(stomp_visual_parent)
	if not is_instance_valid(trapped):
		_fail("failed to create trapped zombie")
		return
	var explicit_candidates:Array[Zombie000Base] = [
		trapped,
		stomp_victim,
		underground_venture,
		underwater_snorkle,
	]
	var hp_before_cast:int = mauga.hp_component.curr_hp
	mauga.call("_activate_chain_skill", explicit_candidates)
	if not bool(mauga.get("_chain_intro_active")) or bool(mauga.get("_chain_skill_active")):
		_fail("Cage Fight did not begin with the invulnerable stomp intro")
		return
	if mauga.hp_component.damage_immunity_sources.is_empty():
		_fail("Mauga was not invulnerable during the stomp cast")
		return
	await get_tree().create_timer(mauga.chain_lunge_duration + mauga.chain_jump_duration * 0.4).timeout
	if mauga.hp_component.curr_hp >= hp_before_cast or mauga.hp_component.curr_hp <= hp_before_cast - mauga.chain_health_cost:
		_fail("the 200 HP cost was not drained progressively during the stomp animation")
		return
	if not await _wait_for_chain_active(mauga):
		_fail("Cage Fight did not open after the landing stomp")
		return
	if mauga.hp_component.curr_hp != hp_before_cast - 200:
		_fail("the stomp animation did not consume exactly 200 HP")
		return
	if is_instance_valid(stomp_victim):
		_fail("the zombie in the landing cell was not removed by the stomp execution")
		return
	if not is_instance_valid(underground_venture):
		_fail("Cage Fight stomp affected underground Venture")
		return
	if not is_instance_valid(underwater_snorkle):
		_fail("Cage Fight stomp affected the submerged Snorkel Zombie")
		return
	if _count_flattened_body_copies(stomp_visual_parent) <= flattened_body_count_before:
		_fail("the stomp execution did not leave the squash-style flattened body visual")
		return
	if mauga.plant_cell != forward_cell:
		_fail("Mauga did not land in the nearest physical cell to the right")
		return
	selected_columns = mauga.call("_get_cage_column_indices")
	if selected_columns.find(lane_cells.find(forward_cell)) != 1:
		_fail("Cage Fight was not recentered on Mauga after the jump")
		return
	if selected_columns.find(lane_cells.find(source_cell)) < 0:
		_fail("the pre-jump cell was not included as the left column of the centered cage")
		return
	cage_bounds = mauga.call("_get_current_cage_ground_bounds")
	cage_x_ranges = mauga.call("_get_current_cage_x_ranges")
	trapped_lane_range = cage_x_ranges[1]
	var immune_lane_range:Vector2 = cage_x_ranges[2]
	var immune_ground_x:float = (immune_lane_range.x + immune_lane_range.y) * 0.5
	_set_ground_x(underground_venture, immune_ground_x)
	_set_ground_x(underwater_snorkle, immune_ground_x)
	mauga.call("_chain_new_zombies_in_area")
	if _is_chained(mauga, underground_venture):
		_fail("Cage Fight chained underground Venture")
		return
	if _is_chained(mauga, underwater_snorkle):
		_fail("Cage Fight chained the submerged Snorkel Zombie")
		return
	_set_ground_x(trapped, (trapped_lane_range.x + trapped_lane_range.y) * 0.5)
	mauga.call("_chain_new_zombies_in_area")
	if not _is_chained(mauga, trapped):
		_fail("enemy inside the post-jump centered 3x3 region was not chained")
		return
	if _is_chained(mauga, excluded_left):
		_fail("the cell two spaces behind post-jump Mauga was chained")
		return
	if bool(trapped.move_component.move_factors.get(MoveComponent.E_MoveFactor.IsGarlicMaugaChain, false)):
		_fail("cage incorrectly disabled normal zombie movement")
		return
	var trapped_target_range:Vector2 = mauga.call(
		"_get_chain_target_ground_x_range",
		trapped.get_instance_id(),
		trapped,
		trapped.shadow.global_position.y
	)
	var walking_start_x:float = trapped.shadow.global_position.x
	await get_tree().create_timer(0.4).timeout
	if trapped.shadow.global_position.x >= walking_start_x - 0.1:
		_fail("zombie did not keep walking freely inside the active cage")
		return
	_set_ground_x(trapped, trapped_target_range.x + 1.0)
	await get_tree().create_timer(0.25).timeout
	if trapped.shadow.global_position.x < trapped_target_range.x - 0.01:
		_fail("normal walking crossed the left wall between process frames")
		return
	var free_x:float = (trapped_target_range.x + trapped_target_range.y) * 0.5
	_set_ground_x(trapped, free_x)
	mauga.call("_update_chain_target_leash", trapped.get_instance_id(), trapped)
	if not is_equal_approx(trapped.shadow.global_position.x, free_x):
		_fail("free movement inside the cage was modified")
		return
	_set_ground_x(trapped, cage_bounds.position.x - 100.0)
	var left_clamp_range:Vector2 = mauga.call(
		"_get_chain_target_ground_x_range",
		trapped.get_instance_id(),
		trapped,
		trapped.shadow.global_position.y
	)
	mauga.call("_update_chain_target_leash", trapped.get_instance_id(), trapped)
	if not is_equal_approx(trapped.shadow.global_position.x, left_clamp_range.x):
		_fail("left-side escape was not clamped to the visible wall")
		return
	_set_ground_x(trapped, cage_bounds.end.x + 100.0)
	var right_clamp_range:Vector2 = mauga.call(
		"_get_chain_target_ground_x_range",
		trapped.get_instance_id(),
		trapped,
		trapped.shadow.global_position.y
	)
	mauga.call("_update_chain_target_leash", trapped.get_instance_id(), trapped)
	if not is_equal_approx(trapped.shadow.global_position.x, right_clamp_range.y):
		_fail("right-side escape was not clamped to the visible wall")
		return
	var late_lane_range:Vector2 = cage_x_ranges[3]
	var late_entrant:= _spawn_zombie(main_game, 3, cage_bounds.end.x + 30.0)
	if not is_instance_valid(late_entrant):
		_fail("failed to create late entrant")
		return
	if _is_chained(mauga, late_entrant):
		_fail("enemy outside the cage was chained early")
		return
	## 即使 X 落在该行预计算区间内，只要当前脚点仍位于椭圆弧线外就不能上锁。
	var center:Vector2 = cage_bounds.get_center()
	var off_curve_y:float = cage_bounds.position.y + 1.0
	var off_curve_wall_range:Vector2 = mauga.call(
		"_get_cage_hard_x_range_at_y",
		cage_bounds,
		off_curve_y
	)
	var off_curve_x:float = minf(
		late_lane_range.y - 1.0,
		off_curve_wall_range.y + 12.0
	)
	if off_curve_x <= off_curve_wall_range.y:
		off_curve_x = maxf(
			late_lane_range.x + 1.0,
			off_curve_wall_range.x - 12.0
		)
	_set_ground_position(late_entrant, Vector2(off_curve_x, off_curve_y))
	mauga.call("_chain_new_zombies_in_area")
	if _is_chained(mauga, late_entrant):
		_fail("enemy outside the curved force-field boundary was chained by its lane X range")
		return
	_set_ground_position(late_entrant, Vector2(late_lane_range.y - 1.0, center.y))
	mauga.call("_chain_new_zombies_in_area")
	if not _is_chained(mauga, late_entrant):
		_fail("enemy entering after deployment was not chained")
		return
	var cage_visual:= mauga.get("_cage_visual") as PlantEffectGarlicMaugaCage
	if not is_instance_valid(cage_visual):
		_fail("closed cage visual was not created")
		return
	var perimeter_segments:Array = cage_visual.call("_build_perimeter_segments")
	if perimeter_segments.size() <= 24:
		_fail("the closed force-field footprint is not a smooth curve")
		return
	var visual_ground_size:Vector2 = cage_visual.get("_ground_size")
	if not visual_ground_size.is_equal_approx(cage_bounds.size):
		_fail("force-field footprint does not use the post-jump centered nine-cell bounds")
		return
	if cage_visual.scale != Vector2.ONE or not cage_visual.global_position.is_equal_approx(cage_bounds.get_center()):
		_fail("force-field footprint uses an extra transform")
		return
	if not is_equal_approx(cage_visual.shield_height, 145.0):
		_fail("Cage Fight did not restore the original wall height")
		return
	var radius_x:float = visual_ground_size.x * 0.5
	var radius_y:float = visual_ground_size.y * 0.5
	for segment:Dictionary in perimeter_segments:
		for point_key:String in ["a", "b"]:
			var point:Vector2 = segment[point_key]
			var ellipse_value:float = (
				pow(point.x / radius_x, 2.0)
				+ pow(point.y / radius_y, 2.0)
			)
			if not is_equal_approx(ellipse_value, 1.0):
				_fail("rendered bottom ring and gameplay ellipse use different curves")
				return
	var wall_range:Vector2 = mauga.call(
		"_get_cage_hard_x_range_at_y",
		cage_bounds,
		trapped.shadow.global_position.y
	)
	if (
		trapped.shadow.global_position.x < wall_range.x - 0.01
		or trapped.shadow.global_position.x > wall_range.y + 0.01
	):
		_fail("zombie foot point crossed the rendered force-field boundary")
		return
	var trapped_visuals:Dictionary = mauga.get("_chain_visuals")
	var trapped_chain:= trapped_visuals.get(trapped.get_instance_id()) as PlantEffectGarlicMaugaChain
	var body_offsets:Vector2 = trapped_chain.get_target_visible_body_x_offsets_from_ground()
	if (
		trapped.shadow.global_position.x + body_offsets.x < wall_range.x - 0.01
		or trapped.shadow.global_position.x + body_offsets.y > wall_range.y + 0.01
	):
		_fail("visible zombie body crossed the rendered force-field boundary")
		return
	if not _check_chain_body_alignment(mauga, trapped):
		return
	var multipart_zombie:= _spawn_zombie(
		main_game,
		2,
		cage_bounds.get_center().x,
		CharacterRegistry.ZombieType.Z510Dancer
	)
	if not is_instance_valid(multipart_zombie):
		_fail("failed to create multipart dancer zombie")
		return
	mauga.call("_chain_new_zombies_in_area")
	var multipart_visuals:Dictionary = mauga.get("_chain_visuals")
	var multipart_chain:= multipart_visuals.get(
		multipart_zombie.get_instance_id()
	) as PlantEffectGarlicMaugaChain
	if not is_instance_valid(multipart_chain):
		_fail("multipart dancer inside the cage was not chained")
		return
	var multipart_attachment:= multipart_chain.get("_target_body_attachment") as Sprite2D
	if (
		not is_instance_valid(multipart_attachment)
		or multipart_attachment.name != &"Zombie_Jackson_body1"
	):
		_fail("multipart dancer chain did not attach to its visible upper torso")
		return
	if OS.get_environment("MAUGA_CAPTURE") == "1":
		await get_tree().process_frame
		await get_tree().process_frame
		var screenshot:= get_viewport().get_texture().get_image()
		if screenshot == null:
			_fail("visual QA screenshot is unavailable with the active display driver")
			return
		var save_error:= screenshot.save_png("/tmp/mauga_cage_visual.png")
		if save_error != OK:
			_fail("failed to save visual QA screenshot")
			return
	trapped.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsDownPool
	mauga.call("_process", 0.0)
	if _is_chained(mauga, trapped):
		_fail("Cage Fight did not release a chained zombie after it submerged")
		return
	trapped.curr_be_attack_status = Zombie000Base.E_BeAttackStatusZombie.IsNorm
	_set_ground_x(trapped, (trapped_lane_range.x + trapped_lane_range.y) * 0.5)
	mauga.call("_chain_new_zombies_in_area")
	if not _is_chained(mauga, trapped):
		_fail("Cage Fight did not recapture a surfaced zombie inside the cage")
		return
	mauga.call("_finish_chain_skill")
	await get_tree().process_frame
	if _is_chained(mauga, trapped) or trapped.has_meta(&"garlic_mauga_chain_owners"):
		_fail("chain ownership was not released when the cage ended")
		return
	if is_instance_valid(mauga.get("_cage_visual")):
		_fail("cage visual survived after the skill ended")
		return
	if not bool(mauga.call("_can_activate_chain_skill")):
		_fail("Cage Fight was not immediately available after the skill ended")
		return
	## 不足 200 HP 仍允许最后一次完整施放，笼中斗结束时才死亡。
	mauga.hp_component.curr_hp = 100
	var low_health_candidates:Array[Zombie000Base] = []
	mauga.call("_activate_chain_skill", low_health_candidates)
	if not await _wait_for_chain_active(mauga):
		_fail("low-health final cast did not open Cage Fight")
		return
	if mauga.hp_component.curr_hp != 0 or mauga.is_death:
		_fail("low-health cast did not defer death while Cage Fight was active")
		return
	mauga.call("_finish_chain_skill")
	await get_tree().process_frame
	if is_instance_valid(mauga) and not mauga.is_death:
		_fail("low-health final cast did not die after Cage Fight ended")
		return
	print("test_mauga_cage_runtime: PASS")
	get_tree().quit(0)


func _spawn_zombie(
	main_game:MainGameManager,
	lane:int,
	ground_x:float,
	zombie_type:= CharacterRegistry.ZombieType.Z501Norm
) -> Zombie000Base:
	var row:ZombieRow = main_game.zombie_manager.all_zombie_rows[lane]
	var init_para:= {
		Zombie000Base.E_ZInitAttr.CharacterInitType: Character000Base.E_CharacterInitType.IsNorm,
		Zombie000Base.E_ZInitAttr.Lane: lane,
		Zombie000Base.E_ZInitAttr.CurrZombieRowType: row.zombie_row_type,
		Zombie000Base.E_ZInitAttr.CurrWave: -1,
	}
	var zombie:= main_game.zombie_manager.create_norm_zombie(
		zombie_type,
		row,
		init_para,
		row.zombie_create_position.global_position
	)
	if is_instance_valid(zombie):
		_set_ground_x(zombie, ground_x)
	return zombie


func _wait_for_chain_active(mauga:Plant037GarlicMauga, timeout:= 1.2) -> bool:
	var elapsed:= 0.0
	while elapsed < timeout:
		if bool(mauga.get("_chain_skill_active")):
			return true
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	return false


func _set_ground_x(zombie:Zombie000Base, ground_x:float) -> void:
	zombie.global_position.x += ground_x - zombie.shadow.global_position.x


func _set_ground_position(zombie:Zombie000Base, ground_position:Vector2) -> void:
	zombie.global_position += ground_position - zombie.shadow.global_position


func _find_horizontal_neighbor(
	lane_cells:Array,
	source_cell:PlantCell,
	direction:int
) -> PlantCell:
	var source_x:float = source_cell.get_global_rect().get_center().x
	var result:PlantCell
	var best_distance:float = INF
	for candidate:PlantCell in lane_cells:
		var signed_distance:float = (
			candidate.get_global_rect().get_center().x - source_x
		) * float(direction)
		if signed_distance > 0.01 and signed_distance < best_distance:
			best_distance = signed_distance
			result = candidate
	return result


func _is_chained(mauga:Plant037GarlicMauga, zombie:Zombie000Base) -> bool:
	var chained:Dictionary = mauga.get("_chained_zombies")
	return chained.has(zombie.get_instance_id())


func _count_flattened_body_copies(parent:Node) -> int:
	var result:= 0
	for child:Node in parent.get_children():
		if child is BodyCharacter:
			result += 1
	return result


func _check_chain_body_alignment(mauga:Plant037GarlicMauga, zombie:Zombie000Base) -> bool:
	var visuals:Dictionary = mauga.get("_chain_visuals")
	var chain_visual:= visuals.get(zombie.get_instance_id()) as PlantEffectGarlicMaugaChain
	if not is_instance_valid(chain_visual):
		_fail("missing body-bound chain visual")
		return false
	var attachment:= chain_visual.get("_target_body_attachment") as Node2D
	var anchor:= chain_visual.get("_target_body_anchor") as Marker2D
	if not is_instance_valid(attachment) or not is_instance_valid(anchor) or anchor.get_parent() != attachment:
		_fail("chain cuff is not parented to the zombie torso")
		return false
	if attachment is Sprite2D:
		var sprite:= attachment as Sprite2D
		var original_transform:Transform2D = sprite.transform
		sprite.position += Vector2(7.0, -4.0)
		sprite.rotation += 0.12
		sprite.scale *= Vector2(1.08, 0.94)
		chain_visual.call("_sync_target_body_anchor")
		var expected_anchor:Vector2 = sprite.to_global(sprite.get_rect().get_center())
		if anchor.global_position.distance_to(expected_anchor) > 0.01:
			sprite.transform = original_transform
			_fail("chain cuff drifted after torso animation transforms")
			return false
		sprite.transform = original_transform
		chain_visual.call("_sync_target_body_anchor")
	return true


func _fail(message:String) -> void:
	push_error("test_mauga_cage_runtime: " + message)
	get_tree().quit(1)
