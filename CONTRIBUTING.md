# 参与贡献

感谢你愿意改进 PVZ of OW。项目同时包含 Godot 场景、资源、脚本和第三方素材引用，提交前请先确认改动范围与版权边界。

## 开始之前

1. 阅读 `AGENTS.md`、`README.md` 和 `docs/AGENT_PROJECT_MAP.md`。
2. 常见角色或卡牌任务还应阅读 `docs/AGENT_TASK_RECIPES.md`。
3. 较大的功能先创建 Issue 或在 QQ 群沟通，避免重复开发。
4. 从最新的 `main` 创建独立功能分支，一次 Pull Request 只解决一类问题。

## 本地开发

项目使用 Godot 4.6.x。完整运行需要使用者自行准备拥有合法使用权的 `assets/`；仓库不会分发完整的原版美术、字体、音乐和音效。

修改前先检查工作区：

```bash
git status --short
```

请使用 `rg` 定位真实文件和相邻实现，不要按常见 Godot 或 PVZ 项目结构猜路径。编辑 `.tscn`、`.tres` 时保留 UID、节点路径、导出值和无关序列化内容。

## 禁止提交的内容

- 未经授权的 PVZ、Overwatch 或其他第三方图片、音乐、音效、字体和商标素材
- `.godot/` 导入缓存、`.DS_Store`、个人编辑器配置和导出包
- 密钥、令牌、`.env`、个人联系方式、用户存档或其他隐私数据
- 与当前 Pull Request 无关的格式化或重排

第三方插件或代码必须保留原许可证和署名，并在 Pull Request 中注明来源。

## 验证

最低检查：

```bash
git diff --check
godot --headless --path . --quit
```

macOS 默认 Godot 安装路径可使用：

```bash
env HOME=/tmp /Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "$(pwd)" --quit
```

修改 JSON 时还应执行：

```bash
python3 -m json.tool data/almanac_data.json
```

根据改动范围运行 `tests/` 中对应场景或脚本。Godot 退出码为 0 时仍需检查输出中的 `SCRIPT ERROR`、`Parse Error` 和资源缺失错误。

## Pull Request 要求

Pull Request 请包含：

- 改动目的和用户可见效果
- 涉及的主要脚本、场景和资源
- 复现步骤或验收方式
- 实际执行的验证命令及结果
- 视觉改动的截图或短视频
- 新增第三方内容的来源和许可证

不要把完整的本地 `assets/` 上传到 Issue 或 Pull Request。
