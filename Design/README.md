# 狮山有你设计素材

Git 只维护当前 4 份可编辑 PXD、12 张定稿源图（4 张全身差分、2 张头像、4 张 UI、2 张原生背景）和必要说明。放大导出、成品 PNG、项目截图、预览、ZIP 和历史草稿按 `.gitignore` 留在本地。

## 当前工作源文件

| 用途 | 文件 |
|---|---|
| 产品页标题 | [通用 PXD](AppStore/creative_assets-universal_asset_template-static.pxd) |
| 搜索结果 | [搜索 PXD](AppStore/creative_assets-search_results_template-static.pxd) |
| 日间图标 | [日间图标 PXD](AppStore/狮山有你.pxd) |
| 夜间图标 | [夜间图标 PXD](AppStore/狮山有你dark.pxd) |
| 角色、头像、UI 与原生背景 | [定稿组件说明](AppStore/ComponentKit-20261026/使用说明.md) |
| 最新人物设定 | [狮小铃](Character/狮小铃.md) |

最新 Banner、搜索页、Logo 成品 PNG 保留在本目录；App Store 截图与放大背景保留在原路径，作为本地导出使用。应用运行所需的图标以 `shishanyouni/Assets.xcassets/AppIcon.appiconset/` 为准。

## 本地归档

[2026-10-26 归档](Archive/2026-10-26-设计稿精简/README.md) 保存 35 个旧稿、重复导出、预览和压缩包；同目录的 `归档清单.json` 记录了每个文件的原路径和 SHA-256，便于恢复。归档不进入 Git。

新增设计先留本地，确认成为当前主稿后，再在根目录 `.gitignore` 的 `curated Design sources` 白名单中加入对应路径。已有 Git 历史保持原样；本次清理只收敛当前版本和今后的提交内容。
