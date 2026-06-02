# Codex 中文化工具包

参考 `LinYiXin123/claude-code-zh-toolkit` 的思路：通过前端显示层补丁、中文映射表、技能/插件映射同步、原生菜单语言包补丁，把 Codex 桌面端界面尽量中文化。

当前官方 Codex 是 Store/MSIX 应用，前端资源在 `resources\app.asar`，不是参考项目默认的 `resources\ion-dist`。默认使用可回退中文化副本，不再写入 `WindowsApps` 官方安装目录。

## 方式一：中文化副本（推荐）

效果：创建一个独立的中文化副本和桌面快捷方式 `Codex 中文版.lnk`，官方 Codex 保持原样。

运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_zh.ps1 -ForceRefresh
```

脚本会：

- 定位 `Get-AppxPackage OpenAI.Codex` 的安装目录。
- 复制 Codex 到 `%LOCALAPPDATA%\OpenAI\Codex-zh`。
- 生成中文映射：`%USERPROFILE%\.codex\tools\codex-chinese\codex-zh-map.json`。
- 注入页面显示层补丁：`codex-zh-patch.js` 和 `codex-zh-map.json`。
- 合并原生菜单补丁：`native-menu-locales\zh-CN.json` 和 `codex-native-menu-zh.json`。
- 创建桌面快捷方式 `Codex 中文版.lnk`。

刷新副本映射：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\refresh_codex_zh.ps1
```

删除副本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_codex_zh.ps1
```

## 方式二：原位安装（不推荐）

`install_codex_zh_inplace.ps1` 和 `restore_codex_zh_inplace.ps1` 仍保留为实验性脚本。它们需要写入 `C:\Program Files\WindowsApps\OpenAI.Codex_...\app\resources\app.asar`，可能被 Store/MSIX 保护拒绝，也可能被 Codex 更新覆盖。

只生成原位补丁包做静态检查：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_zh_inplace.ps1 -PrepareOnly
```

## 说明

中文化分两层：

- 页面层：插件市场、技能列表、按钮、搜索框、tooltip 等。
- 原生菜单层：文件、编辑、查看、窗口、帮助及其下拉菜单项。

中文化只修改显示文字，不修改插件 ID、技能 ID、命令名、账号、网络请求或功能逻辑。
