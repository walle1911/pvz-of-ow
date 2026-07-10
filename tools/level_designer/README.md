# PVZ-of-OW 关卡设计工具

直接用浏览器打开 `index.html`。它会依据本项目的 `ResourceLevelData`、`PrePlantResource` 和 `ConstLevelData` 生成可加载的 `.tres` 关卡参数。

## 使用

1. 填写背景、波数、阳光、卡槽和出怪僵尸 ID。
2. 填写一个“当前预种植物 ID”，在 5 × 9 棋盘点击格子放置；右键清除某一个格子。
3. 点击“复制 .tres”，新建同名文本文件并放到项目根目录的 `level_game_para/`。
4. 从游戏的自定义关卡入口读取该资源。

ID 必须是当前 `scripts/autoload/global/character_registry.gd` 中已经注册的 `PlantType` / `ZombieType`；设计工具不会代替角色注册或卡牌注册。

该工具只生成关卡资源，不修改游戏数据或角色文件。
