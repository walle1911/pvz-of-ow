# AGENTS.md

本文件适用于整个 `PVZ-of-OW` 仓库。给自动化 agent 接手任务时，先读本文件，再按需读：

- `README.md`
- `docs/开发相关.md`
- `docs/子弹说明文档.md`
- `docs/AGENT_PROJECT_MAP.md`
- `docs/AGENT_TASK_RECIPES.md`

## 项目定位

这是 Godot 4.6 系列的 PVZ 复刻和同人改版项目。主项目入口是 `project.godot`，主游戏基础场景是 `scenes/main/MainGame00Base.tscn`，角色、卡牌、关卡、子弹和全局状态都由明确的脚本/资源表串联。

不要按 PVZ 或 Godot 惯例猜路径。先用 `rg`、`rg --files`、现有 `.tscn/.tres/.gd` 文件确认真实结构。

## 绝对禁止的删除方式

禁止执行任何批量删除或递归删除操作。

不要使用：

- `rm -rf`
- `rm -r`
- `rm -R`
- `find ... -delete`
- `find ... -exec rm ...`
- `xargs rm`
- `trash` 删除多个文件或目录

删除操作必须满足：

- 只能删除单个文件
- 必须使用明确的绝对路径
- 不得删除目录
- 不得使用通配符，例如 `*`、`?`
- 不得通过脚本循环删除多个文件

正确示例：

```sh
rm "/Users/yourname/Documents/example.txt"
```

如果任务需要删除多个文件、清空目录、删除目录或使用通配符，应立即停止，并请求用户手动确认或手动删除。

## 工作区规则

- 开始修改前先看 `git status --short`。
- 本仓库经常有用户或其他 agent 留下的未提交改动。不要回滚、格式化或顺手清理与任务无关的文件。
- 如果需要提交，只 stage 用户明确要求的范围。不要把 `.DS_Store`、无关 `.tmp`、无关资源导入文件混进提交。
- `.gitignore` 当前忽略 `.godot/`、`/android/`、`.vscode`、`assets`。完整素材可能在本地存在但不进仓库。
- 文本编辑尽量小范围修改。`.tscn`、`.tres` 是 Godot 序列化文件，保留 `uid`、`unique_id`、`ext_resource`、节点路径和 Inspector 导出值，避免无关重排。

## UI 弹窗硬性规则

- 所有需要用户决策的弹窗都必须在目标分辨率内始终显示明确的“确认”和“取消/关闭”按钮。
- 可滚动内容只能占用中间内容区，操作按钮必须使用固定底栏，不能依赖 `ConfirmationDialog` 自动布局把按钮放在内容之后。
- 新增或修改弹窗后，必须检查长内容、滚动到底部以及窗口缩放场景，确认操作按钮不会被内容挤出屏幕或遮挡。

## 代码和玩法约束

- 植物/僵尸的原有 idle、攻击、睡眠、死亡和状态机行为优先保留。新效果尽量作为独立状态、叠加节点或组件接入。
- 角色根节点负责初始化和信号连接。继承角色通常不要重写 `_ready()`；先检查 `Character000Base`、`Plant000Base`、`Zombie000Base` 当前使用的 `ready_norm()`、`ready_show()`、`ready_garden()`、`ready_norm_signal_connect()` 等入口。
- 正常出战角色死亡应走血量组件和已有死亡流程，不要直接删除角色节点。
- 组件之间的自定义信号连接遵循 `docs/开发相关.md` 的规则：除组件父子依赖等特例外，由角色本体统一连接。
- 视觉修正要改对层：Gameplay 场景、卡牌静态预览、图鉴展示、花园展示可能是不同节点树。
- 用户要求“替换原路径”时，默认改权威路径，不新建平行资源绕开。

## 常用验证

优先使用项目上下文校验，而不是单文件脚本裸跑。Godot 可执行文件通常在：

```sh
/Applications/Godot.app/Contents/MacOS/Godot
```

推荐校验命令：

```sh
git diff --check
HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/liuyu-yangpocunban/GameDve/PVZ-of-OW --quit
```

说明：

- `HOME=/tmp` 可避开部分 macOS `user://logs` 权限/路径问题。
- headless 输出中的 CA 证书、`resources still in use at exit`、RID/ObjectDB 退出警告，在退出码为 `0` 且没有脚本解析错误时通常不是本次任务阻塞项。
- 修改 JSON 时可额外跑 `python3 -m json.tool data/almanac_data.json`。
- 修改具体场景/角色时，优先用 debug 场景或临时 SceneTree 脚本实例化相关 `.tscn` 做窄范围验证。

## 关键路径速查

- 全局入口：`project.godot`
- 自动加载：`scenes/autoload/global.tscn`、`scenes/autoload/all_cards.tscn`
- 角色注册：`scripts/autoload/global/character_registry.gd`
- 当前解锁/选择状态：`scripts/autoload/global/global_game_state.gd`
- 主游戏基础场景：`scenes/main/MainGame00Base.tscn`
- 调试场景：`scenes/main/MainGameDebug9999Sun.tscn`、`MainGameDebug9999Night.tscn`、`MainGameDebug9999Pool.tscn`、`MainGameDebug9999Fog.tscn`、`MainGameDebug9999Roof.tscn`
- 植物脚本/场景：`scripts/character/plant/`、`scenes/character/plant/`
- 僵尸脚本/场景：`scripts/character/zombie/`、`scenes/character/zombie/`
- 角色组件：`scripts/character/components/`
- 子弹脚本/场景：`scripts/bullet/`、`scenes/bullet/`
- 子弹注册：`scripts/autoload/global/bullet_registry.gd`
- 卡牌 UI：`scripts/ui/card/`、`scenes/ui/all_cards/`
- 卡牌预览权威场景：`scenes/autoload/all_cards.tscn`
- 关卡资源：`resources/level_date_resource/`
- 种植条件资源：`resources/character_resource/plant_condition/`
- 图鉴数据：`data/almanac_data.json`

## 接手任务的默认流程

1. 读用户需求，确认目标是代码、场景、资源、卡牌、关卡还是文案。
2. `git status --short`，记录已有未提交改动。
3. 用 `rg` 定位真实脚本、场景、资源和注册表。
4. 阅读相邻实现，沿用现有模式。
5. 做最小修改，避免跨系统重构。
6. 运行窄范围检查和必要的 Godot headless 检查。
7. 汇报改了哪些文件、验证结果、未处理的既有脏文件或无关警告。
