# Codex-

Codex 桌面端中文化工具。目标是把 Codex 插件市场、顶部菜单、左侧导航、插件名称、插件描述、搜索框和 tooltip 等英文界面尽量显示成中文。

当前核心工具在：

```text
codex-zh-toolkit/
```

## 功能

- 参考 `LinYiXin123/claude-code-zh-toolkit` 的显示层补丁思路。
- 不直接修改 WindowsApps 里的官方 Codex 安装目录。
- 复制一个可回退的 Codex 中文化副本到 `%LOCALAPPDATA%\OpenAI\Codex-zh`。
- 向 Codex 的 `app.asar` 注入前端中文化脚本、中文映射表和原生菜单语言包补丁。
- 支持扫描 `%USERPROFILE%\.codex\skills` 和 `%USERPROFILE%\.codex\plugins\cache` 生成技能/插件中文映射。

## 使用（中文化副本，推荐）

在仓库根目录运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\codex-zh-toolkit\scripts\install_codex_zh.ps1 -ForceRefresh
```

安装后会创建：

- 中文化副本：`%LOCALAPPDATA%\OpenAI\Codex-zh`
- 桌面快捷方式：`Codex 中文版.lnk`

原来的官方 Codex 图标和 WindowsApps 安装目录不会被修改。

脚本会补两层：

- 页面层：插件市场、技能列表、按钮、搜索框、tooltip 等。
- 原生菜单层：文件、编辑、查看、窗口、帮助及其下拉菜单项。

也可以双击仓库根目录的：

```text
install-codex-zh-copy.cmd
```

## 刷新副本

```powershell
powershell -ExecutionPolicy Bypass -File .\codex-zh-toolkit\scripts\refresh_codex_zh.ps1
```

## 卸载副本

```powershell
powershell -ExecutionPolicy Bypass -File .\codex-zh-toolkit\scripts\uninstall_codex_zh.ps1
```

## 原位安装（不推荐）

`install_codex_zh_inplace.ps1` 仍保留为实验性脚本，但 Store/MSIX 的 `WindowsApps` 保护可能拒绝覆盖官方 `app.asar`。默认不要使用它。

如果你只想生成原位补丁包做静态检查，可运行 `-PrepareOnly`；不要把它作为日常安装方式。

## 说明

中文化只修改显示文字，不修改插件 ID、技能 ID、命令名、账户、网络请求或功能逻辑。原始旧配置说明已保存在 `legacy-Codex-Chinese-README.md`。
