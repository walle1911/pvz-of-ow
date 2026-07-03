# Agent Project Map

给新 agent 快速定位项目用。更完整的原项目说明见 `README.md`、`docs/开发相关.md` 和 `docs/子弹说明文档.md`。

## 一句话结构

`PVZ-of-OW` 是 Godot 4.6 项目：`project.godot` 配自动加载，`MainGame00Base.tscn` 承载主游戏节点树，`CharacterRegistry` 注册植物/僵尸，关卡资源决定本局参数，卡牌从 `AllCards` 复制，角色行为由根脚本加组件共同完成。

## 顶层目录

| 路径 | 用途 |
| --- | --- |
| `addons/` | Godot 插件，包含 `R2Ga_PVZ`、动画重构等插件 |
| `animation/` | `.tres/.res` 动画资源，多数角色动画在这里 |
| `assets/` | 图片、音频等素材。本目录被 `.gitignore` 忽略，本地可能有完整素材 |
| `data/` | 主题和数据文件，例如 `almanac_data.json` |
| `docs/` | 项目开发文档和 agent 接手文档 |
| `resources/` | 自定义资源，包含关卡、种植条件、掉血 body 变化、戴夫对话 |
| `scenes/` | Godot 场景，主游戏、角色、子弹、UI 都在这里 |
| `scripts/` | GDScript 脚本，按 autoload、manager、character、bullet、ui 等分类 |
| `shaders/` | Shader 与 include 文件 |
| `level_game_para/` | 自定义关卡参数文件 |

## 启动和全局单例

`project.godot` 的关键配置：

- `run/main_scene` 指向项目主入口。
- `Global`：`scenes/autoload/global.tscn`
- `SoundManager`：`scenes/autoload/sound_manager.tscn`
- `SceneRegistry`：`scripts/autoload/scene_registry.gd`
- `AllCards`：`scenes/autoload/all_cards.tscn`
- `GlobalUtils`：`scripts/autoload/util/global_utils.gd`
- `EventBus`：`scripts/autoload/event_bus.gd`
- `TreePauseManager`：`scripts/autoload/tree_pause_manager.gd`

`Global` 场景中挂有 `CharacterRegistry`、`GlobalGameState`、读档/存档等核心节点。查植物、僵尸、全局存档状态时先从这里追。

## 主游戏场景

| 路径 | 用途 |
| --- | --- |
| `scenes/main/MainGame00Base.tscn` | 主游戏基础节点树，包含卡槽、临时层、管理器、背景和 UI 层 |
| `scenes/main/MainGame01Front.tscn` | 前院类主游戏场景 |
| `scenes/main/MainGame02Back.tscn` | 后院/泳池类主游戏场景 |
| `scenes/main/MainGame03Roof.tscn` | 屋顶类主游戏场景 |
| `scenes/main/MainGameDebug9999*.tscn` | 直接测试不同地形的 debug 场景 |

常用节点层：

- `CanvasLayerCardSlot`：卡槽
- `CanvasLayerCardSlotFront`：卡槽前景
- `CanvasLayerTemp`：临时种植虚影、临时僵尸、真实铲子等
- `CanvasLayerEffect`：全屏效果
- `CanvasLayerUI`：菜单/UI

## 管理器

| 路径 | 说明 |
| --- | --- |
| `scripts/manager/main_game_manager.gd` | 主游戏总管理器，含测试导出项、关卡参数、管理器初始化 |
| `scripts/manager/main_game_date.gd` | 主游戏运行期共享数据 |
| `scripts/manager/card_manager.gd` | 卡槽和卡牌创建、使用流程 |
| `scripts/manager/hand_manager/` | 鼠标手持植物、僵尸、道具、铲子流程 |
| `scripts/manager/plant_cell_manager/` | 植物格子管理 |
| `scripts/manager/zombie_manager/` | 僵尸波次、创建、出场行选择 |
| `scripts/manager/game_item_manager/` | 小推车、脑子、其他场景物件 |
| `scripts/manager/drop_item_manager/` | 掉落物管理 |

`MainGameManager` 里有调试预设卡片导出项：`test_pre_choosed_card_list_plant`、`test_pre_choosed_card_list_zombie`、`test_max_choosed_card_num`。调试卡组时优先用这些，不要直接污染正式关卡资源。

## 角色系统

基础继承：

- 通用角色：`scripts/character/character_000_base.gd`
- 植物基类：`scripts/character/plant/plant_000_base.gd`
- 僵尸基类：`scripts/character/zombie/zombie_000_base.gd`
- 组件：`scripts/character/components/`

场景继承：

- 植物基础场景：`scenes/character/plant/plant_000_base.tscn`
- 底部植物基础场景：`scenes/character/plant/plant_000_down_base.tscn`
- 僵尸基础场景：`scenes/character/zombie/zombie_000_base.tscn`

注册入口：

- `scripts/autoload/global/character_registry.gd`
- 植物用 `PlantType` 和 `PlantInfo`
- 僵尸用 `ZombieType` 和 `ZombieInfo`
- 紫卡前置关系在 `AllPrePlantPurple`

角色展示、出战、花园初始化不是同一个上下文。改角色时检查 `character_init_type` 对应的 `ready_norm()`、`ready_show()`、`ready_garden()` 路径。

## 卡牌和选择

| 路径 | 说明 |
| --- | --- |
| `scenes/autoload/all_cards.tscn` | 卡牌预制体和静态角色预览的权威场景 |
| `scripts/ui/card/all_cards.gd` | `AllCards` 逻辑 |
| `scenes/ui/all_cards/card.tscn` | 单张卡牌场景 |
| `scripts/ui/card/card.gd` | 卡牌脚本 |
| `scripts/ui/card/card_slot/` | 普通卡槽、战斗卡槽、传送带、种子雨、金币卡槽等 |
| `scripts/manager/card_manager.gd` | 本局卡牌创建和使用 |

卡牌上的角色静态图通常在 `Card/CardBg/CharacterStatic` 下。预览错位时优先检查 `scenes/autoload/all_cards.tscn`，不要假设存在 `scenes/ui/all_cards/all_cards.tscn`。

## 种植和格子

| 路径 | 说明 |
| --- | --- |
| `scripts/main_game_item/plant_cell.gd` | 单个植物格子，记录格子类型、植物位置、特殊状态 |
| `resources/character_resource/plant_condition/` | 种植条件资源 |
| `scripts/resources/plant_condition/` | 种植条件脚本 |

植物格子位置类型：`Norm`、`Shell`、`Down`、`Float`、`Imitater`。普通植物、壳、底座、漂浮植物的容器和跟随关系见 `docs/开发相关.md`。

## 子弹系统

先读 `docs/子弹说明文档.md`。

| 路径 | 说明 |
| --- | --- |
| `scenes/bullet/` | 子弹场景 |
| `scripts/bullet/` | 子弹脚本 |
| `scripts/bullet/component/movement/` | 直线、抛物线、追踪移动组件 |
| `scripts/autoload/global/bullet_registry.gd` | 子弹类型和场景注册 |

标准子弹通常走 `Bullet000NormBase.init_bullet()`，再由对应移动组件驱动。玉米炮等特殊子弹可以只继承薄基类，走独立初始化。

## 关卡和数据

| 路径 | 说明 |
| --- | --- |
| `scripts/resources/level/level_data.gd` | `ResourceLevelData` 脚本 |
| `resources/level_date_resource/mode_adventure/` | 冒险和 debug 关卡资源 |
| `resources/level_date_resource/mode_minigame/` | 小游戏资源 |
| `resources/level_date_resource/mode_survival/` | 生存资源 |
| `resources/level_date_resource/mode_puzzle/` | 解谜资源 |
| `level_game_para/` | 自定义关卡参数 |
| `data/almanac_data.json` | 图鉴数据 |

## 验证命令

```sh
git diff --check
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW --quit
```

已知非阻塞输出：

- macOS CA certificate 报错
- 退出时 `resources still in use`
- RID/ObjectDB leak 警告

判断优先级：退出码、脚本解析错误、任务相关场景是否能实例化。

