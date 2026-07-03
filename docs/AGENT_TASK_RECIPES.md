# Agent Task Recipes

本文件给接手 agent 做常见任务用。任何流程都先从真实文件出发，不按名字猜。

## 通用起手式

```sh
git status --short
rg "关键词" .
rg --files | rg "关键词"
```

确认目标文件后再改。若工作区已有用户改动，读 diff，保留不相关改动。

## 新增或复制植物

1. 找一个最接近的已有植物，读它的脚本、场景、动画资源、卡牌预览和注册表。
2. 新植物脚本放 `scripts/character/plant/`，场景放 `scenes/character/plant/`。
3. 在 `scripts/autoload/global/character_registry.gd` 增加 `PlantType` 和 `PlantInfo`，包含名字、冷却、阳光、种植条件和场景 preload。
4. 若是紫卡，在 `AllPrePlantPurple` 添加前置植物关系。
5. 需要正式可选时，检查 `scripts/autoload/global/global_game_state.gd` 的 `curr_plant`。
6. 需要卡牌时，更新 `scenes/autoload/all_cards.tscn` 中对应卡牌和 `CharacterStatic` 预览。
7. 需要图鉴时，更新 `data/almanac_data.json`。
8. 验证：`rg` 新 id、新名字、新场景路径；必要时跑 Godot headless。

注意：

- 不要只加脚本。角色通常还需要场景、注册、卡牌、图鉴或关卡资源串联。
- 复制变体时优先沿用相邻变体的写法。
- 调整静态卡牌预览时改 `scenes/autoload/all_cards.tscn`，不是猜一个新的 all_cards 场景。

## 新增或复制僵尸

1. 从 `scripts/character/zombie/` 和 `scenes/character/zombie/` 找相似僵尸。
2. 场景通常继承 `scenes/character/zombie/zombie_000_base.tscn`。
3. 在 `scripts/autoload/global/character_registry.gd` 增加 `ZombieType` 和 `ZombieInfo`，包含名字、冷却、阳光、场景 preload、`ZombieRowType`。
4. 若出现在关卡波次中，检查 `resources/level_date_resource/` 相关 `.tres`。
5. 若可作为卡牌或解谜僵尸使用，检查 `global_game_state.gd`、`all_cards.tscn`、对应卡槽逻辑。

僵尸动画要注意：

- 移动动画开头通常有移动组件方法调用。
- 死亡动画末尾通常走已有 fade/remove 流程。
- 攻击动画打点应调用攻击组件，不要在脚本里另造平行伤害路径。

## 修改植物动画或状态

1. 先确认该植物用的是 `AnimationPlayer/AnimationTree`、逐帧 PNG 脚本，还是混合方案。
2. 检查 `.tscn` 保存的节点默认状态。可见性、scale、self_modulate、texture 很多时候比脚本更关键。
3. 保留原 idle 和攻击流程。新增治疗、buff、特效时优先用叠加 Sprite/Particles/Line2D/独立 AnimationPlayer。
4. 若状态会中断攻击或 idle，先确认 `_ready`、`ready_norm_signal_connect()`、DetectComponent、AttackComponent 的原始信号路径。
5. 对循环卡顿、对齐、锚点问题，优先在运行时脚本、场景节点 transform 或动画资源上做小改，不直接重写原始素材。

## 修改卡牌、预览或卡槽

相关路径：

- `scenes/autoload/all_cards.tscn`
- `scripts/ui/card/all_cards.gd`
- `scenes/ui/all_cards/card.tscn`
- `scripts/ui/card/card.gd`
- `scripts/ui/card/card_slot/`
- `scripts/manager/card_manager.gd`

规则：

- 卡牌预制体由 `AllCards` 自动加载，战斗里从这里复制。
- 卡牌静态角色通常在 `Card/CardBg/CharacterStatic` 下。
- 卡牌交互不要复用会破坏真实战斗状态的变量。若只是 UI 预览或卡牌效果，尽量走独立状态。

## 修改铲子、手持物或临时层

相关路径：

- `scripts/manager/hand_manager/`
- `scripts/ui/card/shovel_in_ui.gd`
- `scripts/main_game_item/real_shovel.gd`
- `scenes/main/MainGame00Base.tscn`
- `CanvasLayerTemp`

规则：

- UI 图标、鼠标跟随图、真实世界效果可能是三个节点。
- 坐标转换要注意 CanvasLayer，必要时用 `get_global_transform_with_canvas()`。
- 铲除植物应走已有 `be_shovel_kill`、植物死亡或格子释放流程，不直接删节点。

## 修改子弹

先读 `docs/子弹说明文档.md`。

标准流程：

1. 在 `scenes/bullet/` 找运动类型相近的场景。
2. 在 `scripts/bullet/` 找对应脚本继承链。
3. 标准子弹通常继承 `Bullet000NormBase` 的直线/抛物线/追踪分支。
4. 在 `scripts/autoload/global/bullet_registry.gd` 注册类型和场景。
5. 发射方调用 `init_bullet()` 时确认字典键、lane、direction、enemy 或落点参数。

若是玉米炮这类演出型特殊子弹，可以参考 `bullet_016_cob_cannon`，但不要把特殊流程塞进通用基类。

## 修改关卡或 debug 卡组

相关路径：

- `scripts/resources/level/level_data.gd`
- `resources/level_date_resource/`
- `scenes/main/MainGameDebug9999*.tscn`
- `scripts/manager/main_game_manager.gd`

优先使用 `MainGameManager` 的测试导出项改 debug 场景预设卡片：

- `test_pre_choosed_card_list_plant`
- `test_pre_choosed_card_list_zombie`
- `test_max_choosed_card_num`

不要为了临时测试直接改正式关卡资源，除非用户明确要求。

## 处理崩溃或报错

1. 先看堆栈指向的是共享组件、角色脚本、场景资源还是注册表。
2. 如果堆栈指向共享组件，先修共享逻辑，不要只修某一个角色场景。
3. 如果报缺资源或路径，查 `character_registry.gd`、`bullet_registry.gd`、`.tscn` 的 `ext_resource` 和 `.tres` preload。
4. 如果 headless 退出有 macOS CA 或资源占用警告，先看退出码和是否有脚本解析错误。

## 交接说明模板

给下一个 agent 或用户交接时，至少写清：

- 目标行为：要实现或修复什么。
- 关键路径：改了哪些 `.gd/.tscn/.tres/.json`。
- 行为约束：哪些原有 idle、攻击、卡牌、种植或关卡流程必须保留。
- 验证：跑过什么命令，退出码和关键输出。
- 剩余风险：未跑的场景、现有无关脏文件、非阻塞警告。

