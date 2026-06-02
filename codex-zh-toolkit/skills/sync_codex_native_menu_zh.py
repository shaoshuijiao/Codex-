import argparse
import json
import re
from pathlib import Path


MENU_TITLE_BY_ID = {
    "codex.commandMenuTitle.newThread": "新对话",
    "codex.commandMenuTitle.quickChat": "快速对话",
    "codex.commandMenuTitle.openThreadInNewWindow": "在新窗口打开",
    "codex.commandMenuTitle.archiveThread": "归档对话",
    "codex.commandMenuTitle.toggleThreadPin": "固定/取消固定对话",
    "codex.commandMenuTitle.composer.startDictation": "听写",
    "codex.commandMenuTitle.openAvatarOverlay": "唤醒宠物",
    "codex.commandMenuTitle.previousThread": "上一个对话或标签页",
    "codex.commandMenuTitle.nextThread": "下一个对话或标签页",
    "codex.commandMenuTitle.settings": "设置...",
    "codex.commandMenuTitle.showKeyboardShortcuts": "键盘快捷键",
    "codex.commandMenuTitle.openProcessManager": "进程管理器",
    "codex.commandMenuTitle.openFolder": "打开文件夹...",
    "codex.commandMenuTitle.toggleSidebar": "显示/隐藏侧边栏",
    "codex.commandMenuTitle.toggleBottomPanel": "显示/隐藏底部面板",
    "codex.commandMenuTitle.toggleTerminal": "打开终端",
    "codex.commandMenuTitle.openBrowserTab": "打开浏览器标签页",
    "codex.commandMenuTitle.toggleBrowserPanel": "显示/隐藏浏览器面板",
    "codex.commandMenuTitle.openReviewTab": "打开审查标签页",
    "codex.commandMenuTitle.toggleSidePanel": "显示/隐藏侧边面板",
    "codex.commandMenuTitle.findInThread": "查找",
    "codex.commandMenuTitle.focusBrowserAddressBar": "聚焦浏览器地址栏",
    "codex.commandMenuTitle.navigateBack": "后退",
    "codex.commandMenuTitle.navigateForward": "前进",
    "codex.commandMenuTitle.copyConversationPath": "复制对话路径",
    "codex.commandMenuTitle.copyDeeplink": "复制深链接",
    "codex.commandMenuTitle.copySessionId": "复制会话 ID",
    "codex.commandMenuTitle.copyWorkingDirectory": "复制工作目录",
    "codex.commandMenuTitle.closeTabOrWindow": "关闭",
    "codex.commandMenuTitle.reloadBrowserPage": "重新加载浏览器页面",
    "codex.commandMenuTitle.hardReloadBrowserPage": "强制重新加载浏览器页面",
    "codex.commandMenuTitle.newWindow": "新窗口",
    "codex.commandMenuTitle.openCommandMenu": "打开命令菜单",
    "codex.commandMenuTitle.searchChats": "搜索对话...",
    "codex.commandMenuTitle.searchFiles": "搜索文件...",
    "codex.commandMenuTitle.renameThread": "重命名对话",
    "codex.commandMenuTitle.toggleFileTreePanel": "显示/隐藏文件树",
    "codex.commandMenuTitle.toggleTraceRecording": "开始追踪录制",
}


for index in range(1, 10):
    MENU_TITLE_BY_ID[f"codex.commandMenuTitle.thread{index}"] = f"转到对话 {index}"


MENU_TITLE_BY_DEFAULT = {
    "New Chat": "新对话",
    "Quick Chat": "快速对话",
    "Open in New Window": "在新窗口打开",
    "Archive chat": "归档对话",
    "Pin/unpin chat": "固定/取消固定对话",
    "Dictation": "听写",
    "Wake Pet": "唤醒宠物",
    "Previous Chat": "上一个对话",
    "Previous Chat or Tab": "上一个对话或标签页",
    "Next Chat": "下一个对话",
    "Next Chat or Tab": "下一个对话或标签页",
    "Settings": "设置",
    "Settings...": "设置...",
    "Settings…": "设置...",
    "Keyboard Shortcuts": "键盘快捷键",
    "Process Manager": "进程管理器",
    "Open Folder...": "打开文件夹...",
    "Open Folder…": "打开文件夹...",
    "Toggle Sidebar": "显示/隐藏侧边栏",
    "Toggle Bottom Panel": "显示/隐藏底部面板",
    "Open Terminal": "打开终端",
    "Open Browser Tab": "打开浏览器标签页",
    "Toggle Browser Panel": "显示/隐藏浏览器面板",
    "Toggle Side Panel": "显示/隐藏侧边面板",
    "Find": "查找",
    "Focus Browser Address Bar": "聚焦浏览器地址栏",
    "Back": "后退",
    "Forward": "前进",
    "Copy conversation path": "复制对话路径",
    "Copy deeplink": "复制深链接",
    "Copy session id": "复制会话 ID",
    "Copy working directory": "复制工作目录",
    "Close": "关闭",
    "Reload Browser Page": "重新加载浏览器页面",
    "Force Reload Browser Page": "强制重新加载浏览器页面",
    "New Window": "新窗口",
    "Open command menu": "打开命令菜单",
    "Search Chats...": "搜索对话...",
    "Search Chats…": "搜索对话...",
    "Search Files...": "搜索文件...",
    "Search Files…": "搜索文件...",
    "Rename chat": "重命名对话",
    "Toggle File Tree": "显示/隐藏文件树",
    "Start Trace Recording": "开始追踪录制",
}


RAW_MENU_LABELS = {
    "File": "文件",
    "Edit": "编辑",
    "View": "查看",
    "Window": "窗口",
    "Help": "帮助",
    "Zoom In": "放大",
    "Zoom Out": "缩小",
    "Actual Size": "实际大小",
    "Toggle Full Screen": "切换全屏",
    "Codex Documentation": "Codex 文档",
    "What's new": "最新变化",
    "Automations": "自动化",
    "Local Environments": "本地环境",
    "Worktrees": "工作树",
    "Install Update": "安装更新",
    "Check for Updates": "检查更新",
    "Quit": "退出",
}


WINDOWS_MENU_BAR = {
    "windowsMenuBar.file": "文件",
    "windowsMenuBar.edit": "编辑",
    "windowsMenuBar.view": "查看",
    "windowsMenuBar.window": "窗口",
    "windowsMenuBar.help": "帮助",
}


EDIT_MENU_TEMPLATE = (
    "{label:`编辑`,id:e.Dn.edit,submenu:["
    "{label:`撤销`,role:`undo`},"
    "{label:`重做`,role:`redo`},"
    "{type:`separator`},"
    "{label:`剪切`,role:`cut`},"
    "{label:`复制`,role:`copy`},"
    "{label:`粘贴`,role:`paste`},"
    "{label:`全选`,role:`selectAll`}"
    "]}"
)

WINDOW_MENU_TEMPLATE = (
    "{label:`窗口`,id:e.Dn.window,submenu:["
    "{label:`最小化`,role:`minimize`},"
    "{label:`关闭`,role:`close`}"
    "]}"
)


def read_json(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ValueError(f"Expected a JSON object: {path}")
    return value


def write_json(path: Path, value: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(value, handle, ensure_ascii=False, separators=(",", ":"))
        handle.write("\n")


def unescape_js_template(value: str) -> str:
    return (
        value.replace("\\`", "`")
        .replace("\\n", "\n")
        .replace("\\r", "\r")
        .replace("\\t", "\t")
    )


def collect_command_menu_titles(app_root: Path) -> dict:
    replacements = dict(WINDOWS_MENU_BAR)
    pattern = re.compile(
        r"id:`(?P<id>codex\.commandMenuTitle\.[^`]+)`[^{}]*?defaultMessage:`(?P<message>(?:\\`|[^`])*)`"
    )

    candidates = list((app_root / ".vite" / "build").glob("*.js"))
    candidates += list((app_root / "webview" / "assets").glob("*.js"))
    for path in candidates:
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in pattern.finditer(text):
            message_id = match.group("id")
            default_message = unescape_js_template(match.group("message")).replace("…", "...")
            target = MENU_TITLE_BY_ID.get(message_id) or MENU_TITLE_BY_DEFAULT.get(default_message)
            if target:
                replacements[message_id] = target
    return replacements


def replace_raw_labels(text: str) -> tuple[str, int]:
    changed = 0
    for source, target in RAW_MENU_LABELS.items():
        old = f"label:`{source}`"
        new = f"label:`{target}`"
        if old in text:
            text = text.replace(old, new)
            changed += 1
    return text, changed


def patch_role_menus(text: str) -> tuple[str, int]:
    changed = 0
    replacements = {
        "{role:`editMenu`,id:e.Dn.edit}": EDIT_MENU_TEMPLATE,
        "{role:`windowMenu`,id:e.Dn.window}": WINDOW_MENU_TEMPLATE,
        "{role:`help`,id:e.Dn.help,submenu:": "{label:`帮助`,id:e.Dn.help,submenu:",
    }
    for source, target in replacements.items():
        if source in text:
            text = text.replace(source, target)
            changed += 1
    return text, changed


def patch_main_menu_js(app_root: Path) -> int:
    changed_files = 0
    for path in (app_root / ".vite" / "build").glob("main-*.js"):
        text = path.read_text(encoding="utf-8", errors="ignore")
        updated, raw_count = replace_raw_labels(text)
        updated, role_count = patch_role_menus(updated)
        if updated != text:
            path.write_text(updated, encoding="utf-8", newline="")
            changed_files += 1
            print(f"Patched native menu labels in {path.name}: raw={raw_count}, role={role_count}")
    return changed_files


def merge_native_menu_locale(app_root: Path, replacements: dict) -> Path:
    locale_path = app_root / "native-menu-locales" / "zh-CN.json"
    if not locale_path.exists():
        raise FileNotFoundError(f"Missing native menu locale file: {locale_path}")
    existing = read_json(locale_path)
    existing.update(replacements)
    write_json(locale_path, dict(sorted(existing.items())))
    return locale_path


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--app-root", required=True, help="Extracted app.asar root")
    parser.add_argument("--out", required=True, help="Generated native menu map JSON")
    args = parser.parse_args()

    app_root = Path(args.app_root)
    if not (app_root / "native-menu-locales" / "zh-CN.json").exists():
        raise SystemExit(f"Invalid Codex app root: {app_root}")

    replacements = collect_command_menu_titles(app_root)
    locale_path = merge_native_menu_locale(app_root, replacements)
    patched_files = patch_main_menu_js(app_root)

    output = {
        "generatedBy": "codex-zh-toolkit",
        "patchedLocale": str(locale_path),
        "patchedMainMenuFiles": patched_files,
        "replacements": dict(sorted(replacements.items())),
    }
    out_path = Path(args.out)
    write_json(out_path, output)

    marker_path = app_root / "native-menu-locales" / "codex-native-menu-zh.json"
    write_json(marker_path, output)
    print(f"Wrote {len(replacements)} native menu replacements to {out_path}")


if __name__ == "__main__":
    main()
