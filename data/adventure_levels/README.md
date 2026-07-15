# 正式冒险关卡覆盖数据

在地图工坊载入“成品关卡”并点击“应用正式”后，会在本目录生成对应的 JSON：

- 普通线：`adventure_1_1.json` 至 `adventure_1_10.json`
- 棋盘格线：`chess_1_1.json` 至 `chess_1_10.json`

正式选关优先读取这里的 JSON；没有对应文件时，继续使用 `adventure_level_presets.gd` 中的内置默认生成规则。
