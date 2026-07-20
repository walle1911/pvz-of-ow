# Agent Task Recipes

本文件给接手 agent 做常见任务用。任何流程都先从真实文件出发，不按名字猜。

## 通用起手式

```sh
git status --short
rg "关键词" .
rg --files | rg "关键词"
```

确认目标文件后再改。若工作区已有用户改动，读 diff，保留不相关改动。

## 新增或复制植物（含 OW 变体）

当基于已有植物原型创建新变体（如 `MelonPult_Ashe`）时，**必须**按以下完整流程操作，每一步都不可省略。

### 1. 新建脚本

复制原型脚本，新脚本直接 `extends` 原型类：

```gdscript
# scripts/character/plant/ow/plant_XXX_variant.gd
extends Plant042TwinSunFlower   # 原型类
class_name PlantXXXVariant
```

文件编号取现有 `plant_*.gd` 脚本最大号 +1。

### 2. 新建场景 `.tscn`

```bash
cp scenes/character/plant/原型.tscn scenes/character/plant/plant_Number_variant.tscn
```

**必须修改**：
- 开头的 `[gd_scene format=3]` **不写 uid**（避免冲突）
- 脚本引用改为 **纯 path** 格式（无 uid）：`[ext_resource type="Script" path="res://scripts/character/plant/ow/新脚本.gd" id="..."]`
- 其他 ext_resource 引用和节点树保持不变

Number 用 `PlantType` 枚举值（如 MelonPultAshe 枚举 =40，场景用 `plant_040_...`）。

### 3. 注册到 `character_registry.gd`

#### 3.1 PlantType 枚举

在 OW 变体区块（`P500PeaShooterSingle` 上方）添加：

```gdscript
P040MelonPultAshe = 40,
```

枚举值用植物在原版 PvZ 中的编号，查阅相邻变体确定可用值。

#### 3.2 PlantInfo 字典

在最近的同类变体条目后添加。`PlantName` 用 `"PrototypeName_OWName"` 格式，`PlantScenes` 指向新 `.tscn`，`CoolTime`、`SunCost`、`PlantConditionResource` 照抄原型。

#### 3.3 AllPrePlantPurple（仅紫卡）

若原型在 `AllPrePlantPurple` 中有前置植物关系，新变体复制一份：

```gdscript
PlantType.P544WinterMelon:[PlantType.P040MelonPultAshe, PlantType.P539MelonPult],
```

### 4. 添加到 `global_game_state.gd`

在 `curr_plant` 数组的 OW 变体区块添加新条目。

### 5. 添加存档 ID 映射

`save_service.gd` 和 `global_utils.gd` 的 `legacy_plant_type_map` 末尾追加，key 取现有最大 +1。

### 6. 添加图鉴

`data/almanac_data.json` 中 plants 对象的对应位置（紧邻原型条目）追加，key 与 `PlantInfo.PlantName` 一致。

### 7. 添加卡牌到 `all_cards.tscn`（**关键步骤，易遗漏**）

#### 7.1 定位 PlantCards 容器

OW 变体卡牌放在 `PlantCards` GridContainer（第一个植物卡牌网格），放在该容器的最后一个 Card 之后。

#### 7.2 添加 Card 节点

```tscn
[node name="CardN" parent="PlantCards" unique_id=NEG_VALUE instance=ExtResource("2_5pqky")]
layout_mode = 2
imitater_tint_color = Color(0.427, 0.757, 0.992, 1)
imitater_whiteness = 0.5
imitater_gray_strength = 0.0
card_plant_type = N    # 枚举值
cool_time = XXX        # 照抄原型
sun_cost = XXX         # 照抄原型

[node name="CardBg" parent="PlantCards/CardN" index="0"]
texture = ExtResource("3_m4n4y")
```

#### 7.3 复制原型的完整 Body 层级（**严格照抄**）

1. 在 `PlantCards2` 中搜索原型的 `card_plant_type = 原型枚举值` 定位其卡牌
2. 将该卡牌 `CharacterStatic` 下的**完整节点树**整段复制
3. 替换父路径：`PlantCards2/CardX` → `PlantCards/CardN`
4. 替换顶层 Node2D 节点名为变体名（如 `Plant042TwinSunFlowerIllari`）
5. **移除**所有 `unique_name_in_owner = true` 行
6. unique_id 换为不重复的负数序列

#### 7.4 更新 all_plant_card_prefabs 字典

添加映射（按枚举值排序）：

```gdscript
42: NodePath("PlantCards/Card32"),
```

### 8. 验证

```bash
python3 -m json.tool data/almanac_data.json
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1
```

关注输出中是否有 `缺少植物卡牌注册信息` 或 `parse error`。退出码 0 且无新增 WARNING 即通过。

### 检查清单

- [ ] 脚本 exists + extends 原型类
- [ ] 场景 exists + 无 uid + 脚本引用用 path 格式
- [ ] PlantType 枚举 + PlantInfo + AllPrePlantPurple（如为紫卡）
- [ ] global_game_state.curr_plant 已添加
- [ ] save_service + global_utils save ID 映射
- [ ] almanac_data.json 条目 + JSON 校验
- [ ] all_cards.tscn：Card 节点 + 完整 Body 层级 + all_plant_card_prefabs 字典
- [ ] Godot headless 退出码 0，无新增 warning

## 新增或复制僵尸（含 OW 变体）

当基于已有僵尸原型创建新变体（如 `Gargantuar_Reinhardt`、`Zomboni_Shion`）时，**必须**按以下完整流程操作，每一步都不可省略。

### 1. 新建脚本

复制原型脚本，新脚本直接 `extends` 原型类：

```gdscript
# scripts/character/zombie/ow/zombie_XXX_variant.gd
extends Zombie013Zamboni   # 原型类
class_name ZombieXXXVariant
```

文件编号取现有 `zombie_*.gd` 脚本最大号 +1。文件名用下划线连接英文名。

### 2. 新建场景 `.tscn`

```bash
cp scenes/character/zombie/原型.tscn scenes/character/zombie/zombie_Number_variant.tscn
```

**必须修改**：
- 开头的 `[gd_scene format=3]` **不写 uid**（避免冲突）
- 脚本引用改为 **纯 path** 格式（无 uid）：`[ext_resource type="Script" path="res://scripts/character/zombie/ow/新脚本.gd" id="..."]`
- 其他 ext_resource 引用和节点树保持不变

Number 用原始僵尸的场景文件编号（如 Zamboni 是 013，Gargantuar 多变体时用下一个空闲号）。

### 3. 注册到 `character_registry.gd`

#### 3.1 ZombieType 枚举

在 OW 变体区块（`Z016JackboxReaper` 上方）添加：

```gdscript
Z013ZomboniShion = 13,
```

枚举值用原始僵尸编号。同一僵尸有多个变体时用下一个空闲值。

#### 3.2 ZombieInfo 字典

在 `Z016JackboxReaper` 条目**之后**紧邻添加。`ZombieName` 用 `"VariantName"` 格式，scene 指向新 `.tscn`，其他参数照抄原型。

### 4. 添加到 `global_game_state.gd`

在 `curr_zombie` 数组的 OW 变体区块添加新条目。

### 5. 添加存档 ID 映射

`save_service.gd` 和 `global_utils.gd` 中的 `legacy_zombie_type_map` 末尾追加新映射，key 取现有最大 +1。

### 6. 添加图鉴

`data/almanac_data.json` 中 zombies 对象的最后一个原版变体条目后追加，key 与 `ZombieInfo.ZombieName` 一致。**验证 JSON**：

```bash
python3 -m json.tool data/almanac_data.json
```

### 7. 添加卡牌到 `all_cards.tscn`（**关键步骤，易遗漏**）

#### 7.1 添加 Card 节点到 ZombieCards

在 `ZombieCards` GridContainer 的最后一个 Card 节点之后（`ZombieCards2` 之前）插入：

```tscn
[node name="CardN" parent="ZombieCards" unique_id=NEG_VALUE instance=ExtResource("2_5pqky")]
layout_mode = 2
imitater_tint_color = Color(0.427, 0.757, 0.992, 1)
imitater_whiteness = 0.5
imitater_gray_strength = 0.0
card_zombie_type = N   # 枚举值
cool_time = 0.0
sun_cost = XXX         # 照抄原型

[node name="CardBg" parent="ZombieCards/CardN" index="0"]
texture = ExtResource("3_m4n4y")
```

unique_id 用不重复的负数。

#### 7.2 复制原型的完整 Body 层级（**严格照抄，不自作主张**）

1. 在 `ZombieCards2` 中搜索原型的 `card_zombie_type = 原型枚举值` 定位其卡牌
2. 将该卡牌 `CharacterStatic` 下的**完整节点树**（从 `Node2D` 起，包括 `Body > BodyCorrect > ...` 所有子孙 Sprite2D）整段复制
3. 替换父路径：`ZombieCards2/CardX` → `ZombieCards/CardN`
4. 替换顶层 Node2D 节点名为变体名（如 `Z009DancingZombieLucio`）
5. **移除**所有 `unique_name_in_owner = true` 行，避免与原版冲突
6. unique_id 统一换为不重复的负数序列

#### 7.3 更新 all_zombie_card_prefabs 字典

在字典顶部添加新映射（按枚举值排序）：

```gdscript
N: NodePath("ZombieCards/CardX"),
```

### 8. 验证

```bash
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit 2>&1
```

关注输出：
- **绝不能有** `缺少僵尸卡牌注册信息` 或 `parse error`
- 退出码为 0 且无新增 WARNING 即通过
- 预存的 UID 相关 warning（如 `uid://ql7tf5nsep8d`）和 `resources still in use at exit` 非阻塞

### 检查清单

- [ ] 脚本 exists + extends 原型类
- [ ] 场景 exists + 无 uid + 脚本引用用 path 格式
- [ ] 枚举 + ZombieInfo 注册
- [ ] global_game_state.curr_zombie 已添加
- [ ] save_service + global_utils save ID 映射
- [ ] almanac_data.json 条目 + JSON 校验通过
- [ ] all_cards.tscn：Card 节点 + 完整 Body 层级 + all_zombie_card_prefabs 字典
- [ ] Godot headless 退出码 0，无新增 warning

## 修改植物动画或状态

1. 先确认该植物用的是 `AnimationPlayer/AnimationTree`、逐帧 PNG 脚本，还是混合方案。
2. 检查 `.tscn` 保存的节点默认状态。可见性、scale、self_modulate、texture 很多时候比脚本更关键。
3. 保留原 idle 和攻击流程。新增治疗、buff、特效时优先用叠加 Sprite/Particles/Line2D/独立 AnimationPlayer。
4. 若状态会中断攻击或 idle，先确认 `_ready`、`ready_norm_signal_connect()`、DetectComponent、AttackComponent 的原始信号路径。
5. 对循环卡顿、对齐、锚点问题，优先在运行时脚本、场景节点 transform 或动画资源上做小改，不直接重写原始素材。

### 成功案例：植物杂交动画迁移

案例：`plant_042_twin_sun_flower_illari.tscn` 右侧花头替换为原版豌豆射手模块，来源为 `plant_500_pea_shooter_single.tscn`。

核心原则：不要把杂交部件拆成几张 Sprite 手搓动画。若目标是复用原版生命感，应把原版部件当成完整动画模块迁移，只在目标场景外层做位置、缩放和连接关系适配。

推荐流程：

1. 先找到源植物的完整动画子树和动画资源。豌豆射手头部不是只有 `PeaShooter_Head` 和 `PeaShooter_mouth`，还包含 `Anim_stem/stem_correct/Anim_sprout`、`Anim_face`、`Idle_mouth`、`Idle_shoot_blink`、`Anim_blink`、`Marker2DBullet`。
2. 在目标植物里加一个外层容器节点，例如 `PeaShooterRightRoot`。这个节点只负责杂交部件整体位置、缩放和跟随目标根茎，不承载源部件的内部关键帧。
3. 将源植物内部子树挂到外层容器下，并保留源部件的相对结构。迁移动画时只重映射 `NodePath` 和 `ExtResource` id，不重新设计头、嘴、嫩芽、眨眼的关键帧。
4. 将动画层拆清楚：
   - 目标植物原 idle：继续驱动目标身体和根茎，例如 `TwinSunFlower_idle`。
   - 杂交部件锚点 idle：只驱动外层容器，例如 `PeaAnchor_Idle` 驱动 `PeaShooterRightRoot:position`。
   - 源部件局部 idle/attack：继续使用原版 `Head_Idle`、`Head_Attack`，驱动 `Anim_sprout`、头、嘴、眨眼等局部节点。
5. 若杂交部件需要和目标根茎连接紧密，不要让源部件根节点和目标根茎各自使用独立摆动曲线。更稳的做法是复用目标连接根茎的位移曲线，再加固定偏移。例如让 `PeaAnchor_Idle` 复用 `TwinSunflower_stem1:position` 曲线，使豌豆整体和右根茎同方向移动。
6. 攻击点也随模块迁移。`AttackComponent.markers_2d_bullet` 应指向迁移后的 `Marker2DBullet`，例如 `../Body/BodyCorrect/PeaShooterRightRoot/Anim_stem/stem_correct/Marker2DBullet`。
7. 若源攻击动画含 `_shoot_bullet` 方法轨道，确认轨道仍指向目标场景里的 `AttackComponent`，不要丢掉方法轨道。

容易失败的做法：

- 只复制头和嘴两张贴图，手调位置和 scale。这样会丢失 `Anim_sprout`、眨眼层、头嘴联动和攻击挤压感。
- 直接修改源动画内部关键帧来适配目标植物。优先改外层容器；内部关键帧越少动，越能保留原版动画质量。
- 同时保留目标根茎摆动和源部件根摆动，且两者相位不同。结果会出现根茎和头部反向移动、连接断裂。
- 只改 `.tscn` 节点默认值，不检查动画轨道。动画每帧会覆盖默认值，视觉上仍可能没有变化。

验证：

- `git diff --check`
- `HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW res://scenes/character/plant/plant_042_twin_sun_flower_illari.tscn --quit`
- `HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW --quit`

退出码为 0 且没有新增解析错误即可。macOS CA 证书提示、既有资源 UID warning、直接加载角色场景时的 `lane == -1` 初始化提示通常不是此类动画迁移的阻塞项。

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
