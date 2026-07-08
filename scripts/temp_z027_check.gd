extends Node
## TEMP runtime check for 027 rebuild — removed after.
func _ready():
	_run()

func _run():
	var ps = load("res://scenes/character/zombie/zombie_026_peashooter_zombie.tscn")
	var z = ps.instantiate()
	z.character_init_type = Character000Base.E_CharacterInitType.IsShow
	add_child(z)
	await get_tree().process_frame

	# 1. head + anims + root_node
	var head = z.get_node_or_null("%PeashooterHead")
	_assert(head is PeashooterHead, "head missing/wrong type: %s" % str(head))
	var ap: AnimationPlayer = head.anim
	_assert(is_instance_valid(ap), "head HeadAnimPlayer missing")
	_assert(ap.has_animation("Head_Idle") and ap.has_animation("Head_Attack"), "head anims missing")
	_assert(ap.root_node == NodePath(".."), "root_node must be .. (got %s)" % str(ap.root_node))
	_L("1/5 OK head+anims+root_node")

	# 2. head idle animates over time
	var face = head.get_node("Anim_stem/stem_correct/Anim_face")
	var p0 = face.position
	await get_tree().create_timer(0.4).timeout
	var p1 = face.position
	_assert(p0 != p1, "HEAD IDLE NOT ANIMATING (face pos unchanged %s)" % str(p0))
	_L("2/5 OK head idle animates ", p0, " -> ", p1)

	# 3. head under Body/BodyCorrect (connected to body)
	_assert(head.get_parent().name == "BodyCorrect", "head not under BodyCorrect (got %s)" % str(head.get_parent().name))
	_L("3/5 OK head parent=", head.get_parent().name, " head.local=", head.position, " face.global=", face.global_position)

	# 4. attack wiring + fire_pea connected
	var ab = z.get_node_or_null("%AttackComponentBullet")
	_assert(ab is AttackComponentBulletPeashooterZombie, "attack component missing/wrong")
	_assert(ab.peashooter_head == head, "attack.peashooter_head ref mismatch")
	_assert(ab.markers_2d_bullet.size() == 1, "markers missing")
	_assert(ab.markers_2d_bullet[0] is Marker2D, "marker not Marker2D (got %s)" % str(ab.markers_2d_bullet[0]))
	_assert(head.fire_pea.get_connections().size() >= 1, "fire_pea not connected")
	_L("4/5 OK attack wired marker=", ab.markers_2d_bullet[0].get_path(), " fire_pea_conns=", head.fire_pea.get_connections().size())

	# 5. pea spawn + camp=Zombie + collision_mask=257
	var tb = Node2D.new(); tb.name = "TestBullets"; add_child(tb); ab.bullets = tb
	ab._shoot_bullet()
	await get_tree().process_frame
	var pea = tb.get_child(0)
	_assert(is_instance_valid(pea), "no pea spawned")
	_assert(pea.bullet_camp == CharacterRegistry.CharacterType.Zombie, "pea camp wrong: %s" % str(pea.bullet_camp))
	_assert(pea is Bullet000NormBase, "pea not Bullet000NormBase")
	var mask = (pea as Bullet000NormBase).area_2d_attack.collision_mask
	_assert(mask == 257, "pea collision_mask wrong: %d (must be 257)" % mask)
	_L("5/5 OK pea spawned camp=Zombie mask=", mask)

	_L("ALL 027 CHECKS PASSED")
	get_tree().quit()

func _assert(cond, msg):
	if not cond:
		push_error("ASSERT FAIL: " + msg)
		print("ASSERT FAIL: ", msg)
		get_tree().quit(1)
func _L(p1="", p2="", p3="", p4="", p5=""): print(p1, p2, p3, p4, p5)
