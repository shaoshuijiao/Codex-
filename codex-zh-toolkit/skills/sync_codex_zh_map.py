import argparse
import json
import re
from pathlib import Path


BASE_REPLACEMENTS = {
    "New Chat": "新对话",
    "Search": "搜索",
    "Plugins": "插件",
    "Skills": "技能",
    "Automations": "自动化",
    "Settings": "设置",
    "Search plugins": "搜索插件",
    "Featured": "推荐",
    "Built by OpenAI": "由 OpenAI 构建",
    "All": "全部",
    "Manage": "管理",
    "Create": "创建",
    "Computer Use": "电脑操作",
    "Control Windows apps from Codex": "让 Codex 控制 Windows 应用",
    "Chrome": "Chrome 浏览器",
    "Control Chrome with Codex": "让 Codex 控制 Chrome",
    "Spreadsheets": "电子表格",
    "Create and edit spreadsheet files": "创建和编辑电子表格文件",
    "Presentations": "演示文稿",
    "Create and edit presentations": "创建和编辑演示文稿",
    "Triage PRs, issues, CI, and publish flows": "处理 PR、问题、CI 和发布流程",
    "Read and manage Slack": "读取和管理 Slack",
    "Read and manage Gmail": "读取和管理 Gmail",
    "Google Calendar": "Google 日历",
    "Google Drive": "Google 云端硬盘",
    "Work across Drive, Docs, Sheets, and Slides": "处理云端硬盘、文档、表格和幻灯片",
    "Summarize Teams and draft follow-ups": "总结 Teams 内容并起草后续事项",
    "Summarize SharePoint sites and files": "总结 SharePoint 站点和文件",
    "Outlook Email": "Outlook 邮箱",
    "Triage Outlook inboxes and draft replies": "整理 Outlook 收件箱并起草回复",
    "Outlook Calendar": "Outlook 日历",
}

BASE_REPLACEMENTS.update({
    "Reload": "重新加载",
    "Open in External Browser": "在外部浏览器中打开",
    "Inspect": "检查",
    "Log Out": "退出登录",
    "Reload Window": "重新加载窗口",
    "Toggle Debug Menu": "显示/隐藏调试菜单",
    "Open Deeplink from Clipboard": "从剪贴板打开深层链接",
    "Toggle Query Devtools": "显示/隐藏查询开发工具",
    "Toggle React Scan": "显示/隐藏 React 扫描",
    "Check for Updates…": "检查更新…",
    "Codex Documentation": "Codex 文档",
    "Troubleshooting": "故障排查",
    "Send Feedback": "发送反馈",
    "Bundled skill": "内置技能",
    "Bundled plugin marketplace": "内置插件市场",
    "Create a plan": "创建计划",
    "Use an existing folder": "使用现有文件夹",
    "Enable the plugins experience in Codex": "启用 Codex 插件体验",
    "Configure approval policy and sandbox settings <a>Learn more</a>": "配置审批策略和沙盒设置 <a>了解更多</a>",
    "Custom config.toml settings": "自定义 config.toml 设置",
    "Open file": "打开文件",
    "Edit your config to customize agent behavior": "编辑配置以自定义代理行为",
    "Restart Codex after editing to apply changes": "编辑后重启 Codex 以应用更改",
    "Codex dependencies may need repair. Send /feedback if this keeps happening": "Codex 依赖可能需要修复。如果问题持续出现，请发送 /feedback",
    "Checks the current bundle and records diagnostic logs": "检查当前组件包并记录诊断日志",
    "Deletes the local bundle, downloads it again, and reloads tools": "删除本地组件包，重新下载并加载工具",
    "Managed by admin policy": "由管理员策略管理",
    "Sandbox settings": "沙盒设置",
    "This config source cannot be edited here.": "此配置来源不能在这里编辑。",
    "This value is managed by admin policy.": "此值由管理员策略管理。",
    "How ChatGPT uses data": "ChatGPT 如何使用数据",
    "Manage on ChatGPT": "在 ChatGPT 中管理",
    "Open in browser": "在浏览器中打开",
    "Advanced settings (opens ChatGPT.com)": "高级设置（打开 ChatGPT.com）",
    "This connector needs setup in your browser.": "此连接器需要在浏览器中完成设置。",
    "Continue in browser": "在浏览器中继续",
    "Open settings": "打开设置",
    "New chat": "新对话",
    "Please sign in with ChatGPT to use plugins": "请使用 ChatGPT 登录以使用插件",
    "Quick chat": "快速对话",
    "Edit section": "编辑分区",
    "Search emoji": "搜索表情",
    "Save": "保存",
    "Archive all": "全部归档",
    "Rename project": "重命名项目",
    "Pin project": "固定项目",
    "Unpin project": "取消固定项目",
    "Create permanent worktree": "创建永久工作树",
    "Archive chats": "归档对话",
    "Create worktree and save as a project": "创建工作树并保存为项目",
    "Expand folder": "展开文件夹",
    "Collapse folder": "折叠文件夹",
    "Recent chats": "最近对话",
    "No recent chats": "没有最近对话",
    "Chats": "对话",
    "Pinned": "已固定",
    "Move chat": "移动对话",
    "Automation folders": "自动化文件夹",
    "Could not create automation": "无法创建自动化",
    "Could not update automation": "无法更新自动化",
    "No recently viewed threads": "没有最近查看的会话",
    "Recently viewed": "最近查看",
    "Untitled chat": "未命名对话",
    "Search chats": "搜索对话",
    "Create a chat to get started!": "创建一个对话即可开始！",
    "Create chat": "创建对话",
    "Loading chats…": "正在加载对话…",
    "Chat": "对话",
    "Search commands and past chats.": "搜索命令和历史对话。",
    "Search files": "搜索文件",
    "Pinned chats": "固定的对话",
    "Recently viewed chats": "最近查看的对话",
    "Switch to dark theme": "切换到深色主题",
    "Switch to light theme": "切换到浅色主题",
    "Dark color theme": "深色主题",
    "Light color theme": "浅色主题",
    "Feedback ID": "反馈 ID",
    "Feedback uploaded": "反馈已上传",
    "Feedback": "反馈",
    "Send feedback about this chat": "发送关于此对话的反馈",
    "Keyboard shortcuts": "键盘快捷键",
    "Loading shortcuts…": "正在加载快捷键…",
    "No active shortcuts": "没有启用的快捷键",
    "No matching shortcuts": "没有匹配的快捷键",
    "General": "通用",
    "Chat handoff needs attention": "对话交接需要处理",
    "Chat handoff failed": "对话交接失败",
    "No running chat-started processes": "没有由对话启动的运行中进程",
    "Background terminal": "后台终端",
    "Processes started by Codex chats": "由 Codex 对话启动的进程",
    "Process is stopping": "进程正在停止",
    "Stopping…": "正在停止…",
    "Process Manager": "进程管理器",
    "Choose folder path": "选择文件夹路径",
    "Folder path": "文件夹路径",
    "Use folder": "使用文件夹",
    "Login required": "需要登录",
    "Log in to Codex": "登录 Codex",
    "See Settings to connect": "前往设置连接",
    "File": "文件",
    "Edit": "编辑",
    "View": "查看",
    "Window": "窗口",
    "Help": "帮助",
    "Open folder": "打开文件夹",
    "Create your own pet": "创建你自己的宠物",
    "Selected": "已选择",
    "Select": "选择",
    "Create new site": "创建新站点",
    "Delete site": "删除站点",
    "Permanently delete this site": "永久删除此站点",
    "Share settings": "共享设置",
    "Permanently delete": "永久删除",
    "Copy link": "复制链接",
    "View source": "查看源代码",
    "Loading plugins…": "正在加载插件…",
    "Type to search for files": "输入以搜索文件",
    "Searching files…": "正在搜索文件…",
    "Files": "文件",
    "Computer use": "电脑操作",
    "Loading skills…": "正在加载技能…",
    "Create title": "创建标题",
    "Select project": "选择项目",
    "Select chat": "选择对话",
    "Choose a model": "选择模型",
    "Automation": "自动化",
    "Automation title": "自动化标题",
    "Automation sandbox details": "自动化沙盒详情",
    "Automation templates": "自动化模板",
    "Choose a folder": "选择文件夹",
    "Edit automation": "编辑自动化",
    "Delete": "删除",
    "Model": "模型",
    "Loading model": "正在加载模型",
    "Choose a pinned chat": "选择一个固定对话",
    "Target chat": "目标对话",
    "Automation actions": "自动化操作",
    "Automation sections": "自动化分区",
    "Could not delete automation": "无法删除自动化",
    "Automation started": "自动化已启动",
    "Could not start automation": "无法启动自动化",
    "New automation": "新建自动化",
    "Delete automation": "删除自动化",
    "Create manually": "手动创建",
    "Create via chat": "通过对话创建",
    "View templates": "查看模板",
    "New automation options": "新自动化选项",
    "Automation not found": "未找到自动化",
    "Back to automations": "返回自动化",
    "Create your first automation": "创建你的第一个自动化",
    "Weekly review": "每周回顾",
    "Run was archived": "运行已归档",
    "Deleted": "已删除",
    "Resume automation": "恢复自动化",
    "Pause automation": "暂停自动化",
    "File access": "文件访问",
    "Plugin": "插件",
    "Review": "审查",
    "Review command": "审查命令",
    "Listed files": "已列出文件",
    "Listing files": "正在列出文件",
    "Searched files": "已搜索文件",
    "Searched web": "已搜索网页",
    "Add files and more": "添加文件和更多内容",
    "Select photos": "选择照片",
    "Add remote files": "添加远程文件",
    "Add files": "添加文件",
    "Add photos & files": "添加照片和文件",
    "Extensions settings": "扩展设置",
    "Password manager settings": "密码管理器设置",
    "Site settings": "网站设置",
    "Browser": "浏览器",
    "Password manager": "密码管理器",
    "Extension manager": "扩展管理器",
    "Cached images and files": "缓存的图片和文件",
    "Delete cookies": "删除 Cookie",
    "Delete site data": "删除网站数据",
    "Delete cached images and files": "删除缓存的图片和文件",
    "Browser cookies cleared": "浏览器 Cookie 已清除",
    "Browser site data cleared": "浏览器网站数据已清除",
    "Browser cache cleared": "浏览器缓存已清除",
    "Manage connections": "管理连接",
    "Enable computer use": "启用电脑操作",
    "Set up Chrome extension": "设置 Chrome 扩展",
    "Continue on chatgpt.com": "在 chatgpt.com 继续",
    "Add to chat": "添加到对话",
    "Ask in side chat": "在侧边对话中询问",
    "Setting up the sandbox…": "正在设置沙盒…",
    "View Usage": "查看用量",
    "Add Credits": "添加额度",
    "Buy credits": "购买额度",
    "You're out of credits": "你的额度已用完",
    "Select model": "选择模型",
    "Edit goal": "编辑目标",
    "Remove selected text attachment": "移除所选文本附件",
    "Selected page element": "已选择页面元素",
    "Selected region attached": "已附加所选区域",
    "Context window:": "上下文窗口：",
    "Auto-review": "自动审查",
    "Ask Codex anything. @ to use plugins or mention files": "向 Codex 提问。输入 @ 使用插件或提及文件",
    "Code review": "代码审查",
    "Review unstaged changes or compare against a branch": "审查未暂存更改或与分支比较",
    "Copy ID": "复制 ID",
    "Copy session id": "复制会话 ID",
    "Search and run slash commands": "搜索并运行斜杠命令",
    "Remove images or switch models to send this message": "移除图片或切换模型后再发送此消息",
})


NAME_HINTS = {
    "github": "GitHub",
    "figma": "Figma",
    "browser": "浏览器控制",
    "computer-use": "电脑操作",
    "spreadsheets": "电子表格",
    "presentations": "演示文稿",
    "documents": "文档",
    "openai-docs": "OpenAI 文档",
    "imagegen": "图片生成",
    "playwright": "Playwright 自动化",
    "pdf": "PDF 处理",
    "speech": "语音生成",
    "transcribe": "音频转写",
    "render-deploy": "Render 部署",
    "cloudflare-deploy": "Cloudflare 部署",
    "skill-creator": "技能创建器",
    "skill-installer": "技能安装器",
    "plugin-creator": "插件创建器",
}


DESC_HINTS = {
    "Control Windows apps from Codex": "让 Codex 控制 Windows 应用",
    "Create and edit spreadsheet files": "创建和编辑电子表格文件",
    "Create and edit presentations": "创建和编辑演示文稿",
    "Create and edit document artifacts": "创建和编辑文档",
    "Generate or edit raster images": "生成或编辑图片",
    "Use when the user asks": "当用户提出相关需求时使用",
    "Deploy applications": "部署应用",
    "Use when tasks involve": "当任务涉及相关文件时使用",
}


def read_text(path: Path) -> str:
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return path.read_text(encoding=encoding)
        except UnicodeDecodeError:
            continue
    return path.read_text(errors="ignore")


def parse_frontmatter(text: str) -> dict:
    if not text.startswith("---"):
        return {}
    match = re.match(r"^---\s*\n(.*?)\n---", text, flags=re.S)
    if not match:
        return {}
    values = {}
    for line in match.group(1).splitlines():
        if ":" not in line:
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip().strip('"').strip("'")
    return values


def chinese_for_name(name: str) -> str | None:
    normalized = name.strip()
    lower = normalized.lower()
    if lower in NAME_HINTS:
        return NAME_HINTS[lower]
    if ":" in normalized:
        left, right = normalized.split(":", 1)
        right_zh = chinese_for_name(right) or right
        return f"{left}: {right_zh}"
    return None


def chinese_for_description(description: str) -> str | None:
    text = " ".join(description.split())
    for source, target in DESC_HINTS.items():
        if source in text:
            return target
    return None


def collect_skill_replacements(root: Path) -> dict:
    replacements = {}
    if not root.exists():
        return replacements
    for skill_file in root.rglob("SKILL.md"):
        meta = parse_frontmatter(read_text(skill_file))
        name = meta.get("name") or skill_file.parent.name
        description = meta.get("description", "")
        name_zh = chinese_for_name(name)
        desc_zh = chinese_for_description(description)
        if name_zh:
            replacements[name] = name_zh
        if description and desc_zh:
            replacements[description] = desc_zh
    return replacements


def collect_plugin_replacements(root: Path) -> dict:
    replacements = {}
    if not root.exists():
        return replacements
    for plugin_json in root.rglob("plugin.json"):
        try:
            data = json.loads(read_text(plugin_json))
        except Exception:
            continue
        for key in ("name", "display_name", "title"):
            value = data.get(key)
            if isinstance(value, str):
                value_zh = chinese_for_name(value)
                if value_zh:
                    replacements[value] = value_zh
        for key in ("description", "short_description"):
            value = data.get(key)
            if isinstance(value, str):
                value_zh = chinese_for_description(value)
                if value_zh:
                    replacements[value] = value_zh
    return replacements


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--codex-home", default=str(Path.home() / ".codex"))
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    codex_home = Path(args.codex_home)
    replacements = dict(BASE_REPLACEMENTS)
    replacements.update(collect_skill_replacements(codex_home / "skills"))
    replacements.update(collect_plugin_replacements(codex_home / "plugins" / "cache"))

    output = {
        "generatedBy": "codex-zh-toolkit",
        "replacements": dict(sorted(replacements.items(), key=lambda item: item[0].lower())),
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(output, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Wrote {len(output['replacements'])} replacements to {out_path}")


if __name__ == "__main__":
    main()
