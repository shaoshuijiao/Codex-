# Codex 中文化工具包

这个工具包参考 `LinYiXin123/claude-code-zh-toolkit` 的显示层补丁思路，把官方 Codex 桌面端复制到用户目录后注入中文化脚本。

默认不会修改 `C:\Program Files\WindowsApps` 里的原版 Codex。

## 安装

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\install_codex_zh.ps1
```

安装后会创建：

- `%LOCALAPPDATA%\OpenAI\Codex-zh\...` 中文化副本
- 桌面快捷方式 `Codex 中文版.lnk`
- `%USERPROFILE%\.codex\tools\codex-chinese` 映射生成工具

## 刷新映射

新增技能或插件后运行：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\refresh_codex_zh.ps1
```

## 卸载

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\uninstall_codex_zh.ps1
```

卸载只删除中文化副本，不影响官方 Codex。
