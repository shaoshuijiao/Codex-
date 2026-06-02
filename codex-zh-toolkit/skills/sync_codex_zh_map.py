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
