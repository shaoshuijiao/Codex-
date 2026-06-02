# Codex 中文化工具包

参考 `LinYiXin123/claude-code-zh-toolkit` 的思路：通过前端显示层补丁、中文映射表、技能/插件映射同步、原生菜单语言包补丁，把 Codex 桌面端界面尽量中文化。

当前官方 Codex 是 Store/MSIX 应用，前端资源在 `resources\app.asar`，不是参考项目默认的 `resources\ion-dist`，所以本工具包提供两种安装方式。

## 方式一：原版内嵌安装（推荐）

效果：继续打开原来的 Codex 图标，界面直接中文化。

注意：需要管理员权限；Codex 更新后可能需要重新运行。

先完全关闭 Codex，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_zh_inplace.ps1
```

脚本会：

- 定位 `Get-AppxPackage OpenAI.Codex` 的安装目录。
- 生成中文映射：`%USERPROFILE%\.codex\tools\codex-chinese\codex-zh-map.json`。
- 备份原始 `app.asar` 到 `%LOCALAPPDATA%\OpenAI\Codex-zh-backups`。
- 注入页面显示层补丁：`codex-zh-patch.js` 和 `codex-zh-map.json`。
- 合并原生菜单补丁：`native-menu-locales\zh-CN.json` 和 `codex-native-menu-zh.json`。
- 以管理员权限覆盖官方 `resources\app.asar`。

只生成补丁包、不覆盖官方 Codex：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_zh_inplace.ps1 -PrepareOnly
```

## 恢复原版

先完全关闭 Codex，然后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\restore_codex_zh_inplace.ps1
```

## 方式二：中文化副本（低风险备选）

效果：创建一个可回退副本和 `Codex-ZH.lnk`。如果你希望原图标直接生效，不要用这个方式。

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_zh.ps1
```

刷新副本映射：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\refresh_codex_zh.ps1
```

删除副本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_codex_zh.ps1
```

## 说明

中文化分两层：

- 页面层：插件市场、技能列表、按钮、搜索框、tooltip 等。
- 原生菜单层：文件、编辑、查看、窗口、帮助及其下拉菜单项。

中文化只修改显示文字，不修改插件 ID、技能 ID、命令名、账号、网络请求或功能逻辑。
