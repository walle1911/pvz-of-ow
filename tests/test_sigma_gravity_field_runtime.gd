extends Node


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	if not _check_ellipse_geometry():
		return
	await get_tree().process_frame
	var main_game:= owner as MainGameManager
	if not is_instance_valid(main_game):
		_fail("missing MainGameManager owner")
		return
	var source_cell:PlantCell = main_game.plant_cell_manager.all_plant_cells[2][3]
	var target_cell:PlantCell = main_game.plant_cell_manager.all_plant_cells[2][4]
	var shoveled_sigma:= source_cell.create_plant(
		CharacterRegistry.PlantType.P024TallNutSigma,
		false,
		false
	) as Plant057TallNutSigma
	await get_tree().process_frame
	if not is_instance_valid(shoveled_sigma):
		_fail("failed to create shoveled Tall Nut Sigma")
		return
	shoveled_sigma.be_shovel_kill()
	await get_tree().process_frame
	if is_instance_valid(main_game.get_node_or_null(^"TallNutSigmaFieldSequence")):
		_fail("shoveling Sigma triggered the gravity field")
		return
	if is_instance_valid(shoveled_sigma):
		_fail("shoveled Sigma was not removed")
		return

	var sigma:= source_cell.create_plant(
		CharacterRegistry.PlantType.P024TallNutSigma,
		false,
		false
	) as Plant057TallNutSigma
	await get_tree().process_frame
	if not is_instance_valid(sigma):
		_fail("failed to create Tall Nut Sigma")
		return
	sigma.slam_charge_time = 0.12
	var expected_center:Vector2 = target_cell.plant_container_node[
		CharacterRegistry.PlacePlantInCell.Norm
	].global_position
	sigma.hp_component.Hp_loss(sigma.hp_component.max_hp)
	var field_sequence:Node = main_game.get_node_or_null(^"TallNutSigmaFieldSequence")
	if not is_instance_valid(field_sequence):
		_fail("lethal threshold crossing did not create the gravity field")
		return
	if field_sequence.effect_center.distance_to(expected_center) > 0.1:
		_fail("gravity field is not centered on the cell directly in front")
		return
	await get_tree().process_frame
	if is_instance_valid(sigma):
		_fail("Sigma did not complete normal death removal")
		return
	await get_tree().create_timer(0.2).timeout
	if is_instance_valid(field_sequence):
		_fail("detached gravity field did not finish")
		return
	print("test_sigma_gravity_field_runtime: PASS")
	get_tree().quit(0)


func _check_ellipse_geometry() -> bool:
	var field_probe:= Plant057TallNutSigma.TallNutSigmaFieldSequence.new()
	field_probe.effect_center = Vector2(100.0, 100.0)
	field_probe.effect_radii = Vector2(50.0, 25.0)
	if not field_probe._is_position_in_effect(Vector2(149.0, 100.0)):
		field_probe.free()
		_fail("ellipse rejected a point inside its visible edge")
		return false
	if field_probe._is_position_in_effect(Vector2(149.0, 124.0)):
		field_probe.free()
		_fail("ellipse included a rectangular corner outside the effect")
		return false
	field_probe.free()
	return true


func _fail(message:String) -> void:
	push_error("test_sigma_gravity_field_runtime: " + message)
	get_tree().quit(1)
