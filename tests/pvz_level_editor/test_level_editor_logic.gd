extends SceneTree

const Logic := preload("res://addons/pvz_level_editor/level_editor_logic.gd")
const Runtime := preload("res://scripts/resources/level/level_json_runtime.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_test_valid_example()
	_test_validation_errors()
	_test_threat_calculation()
	_test_deterministic_simulation()
	_test_lane_rules()
	_test_runtime_loader()
	if failures.is_empty():
		print("PVZ level editor tests: 6 passed")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		print("PVZ level editor tests: %d failed" % failures.size())
		quit(1)


func _test_valid_example() -> void:
	var issues := Logic.validate_level(Logic.example_level())
	_expect(not issues.any(func(value): return value["severity"] == "error"), "示例关卡不应有校验错误")


func _test_validation_errors() -> void:
	var level := Logic.example_level()
	level["winConditions"] = []
	level["waves"][0]["spawnGroups"][0]["count"] = 0
	level["waves"][0]["spawnGroups"][0]["laneRule"] = "fixed"
	level["waves"][0]["spawnGroups"][0]["fixedLane"] = 99
	var paths := Logic.validate_level(level).map(func(value): return value["path"])
	_expect(paths.has("winConditions"), "应检查缺少胜利条件")
	_expect(paths.has("waves/0/spawnGroups/0/count"), "应检查数量为零")
	_expect(paths.has("waves/0/spawnGroups/0/fixedLane"), "应检查不存在的路线")


func _test_threat_calculation() -> void:
	var group := Logic.make_group("threat", "buckethead", 10)
	group["healthMultiplier"] = 2.0
	group["speedMultiplier"] = 1.0
	group["maxAlive"] = 10
	_expect(is_equal_approx(Logic.threat_for_group(group), 80.0), "威胁值应包含类型、数量、血量、速度与同屏上限")


func _test_deterministic_simulation() -> void:
	var level := Logic.example_level()
	var first := JSON.stringify(Logic.simulate_level(level))
	var second := JSON.stringify(Logic.simulate_level(level))
	_expect(first == second, "相同随机种子必须产生相同刷怪结果")
	level["randomSeed"] = int(level["randomSeed"]) + 1
	_expect(first != JSON.stringify(Logic.simulate_level(level)), "不同随机种子应改变随机刷怪结果")


func _test_lane_rules() -> void:
	var fixed := Logic.make_group("fixed", "normal", 4, 0.0, "fixed", 1.0, "fixed")
	fixed["fixedLane"] = 3
	var events := Logic.simulate_group(fixed, 0.0, 7, 5)
	_expect(events.all(func(value): return value["lane"] == 3), "指定路线应只生成在对应路线")
	var weighted := Logic.make_group("weighted", "normal", 4, 0.0, "fixed", 1.0, "weighted", [0, 0, 1, 0, 0])
	events = Logic.simulate_group(weighted, 0.0, 7, 5)
	_expect(events.all(func(value): return value["lane"] == 3), "单路线权重应只生成在对应路线")


func _test_runtime_loader() -> void:
	var result := Runtime.load_level("res://data/level_editor/example_front_lawn.json")
	_expect(result["ok"], "游戏侧运行时应能读取示例 JSON")
	_expect(Runtime.build_spawn_schedule(result["level"]).size() == 14, "运行时应生成完整刷怪计划")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
