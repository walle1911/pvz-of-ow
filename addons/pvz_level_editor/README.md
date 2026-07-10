# PVZ 关卡编辑器 MVP

关卡编辑能力现在有两个入口：

- 普通玩家：运行游戏后，从主菜单进入“关卡工坊”，在真实草坪背景上通过僵尸卡片逐波编排，并在右侧道路查看真实僵尸。
- 开发者：Godot 底部面板中的“PVZ 关卡编辑器”，用于更紧凑的专业编辑。

运行时使用与开发者审核流程见 `res://docs/关卡工坊.md`。

## 使用

1. 用 Godot 打开项目，点击底部的“PVZ 关卡编辑器”。
2. 在左侧选择植物、僵尸或事件；在右侧编辑当前波次和刷怪组。
3. 在底部新增、复制、删除、排序波次，或水平拖动波次色块调整开始时间。
4. 点击“校验配置”，消除错误后导出 JSON。
5. 自动保存位于 `user://pvz_level_editor/autosave.json`，下次打开插件会恢复。

游戏侧通过 `LevelJsonRuntime.load_level(path)` 读取 JSON，通过 `LevelJsonRuntime.build_spawn_schedule(level)` 获得确定性刷怪计划。MVP 不会替换现有 `ResourceLevelData` 的自然波次系统；接入具体关卡时，应由对应模式的刷怪管理器消费此计划。

## 数据与测试

- JSON Schema：`res://addons/pvz_level_editor/level.schema.json`
- 示例关卡：`res://data/level_editor/example_front_lawn.json`
- 运行测试：

```sh
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW --script res://tests/pvz_level_editor/test_level_editor_logic.gd
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW --script res://tests/pvz_level_editor/test_level_editor_panel_smoke.gd
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW --script res://tests/pvz_level_editor/test_level_workshop_runtime.gd
```
