(() => {
  const builtinMap = new Map([
    ["New Chat", "新对话"],
    ["New chat", "新对话"],
    ["New session", "新会话"],
    ["Search", "搜索"],
    ["Plugins", "插件"],
    ["Plugin", "插件"],
    ["Skills", "技能"],
    ["Automations", "自动化"],
    ["Projects", "项目"],
    ["Settings", "设置"],
    ["Dashboard", "仪表盘"],
    ["Search plugins", "搜索插件"],
    ["Featured", "推荐"],
    ["Built by OpenAI", "由 OpenAI 构建"],
    ["All", "全部"],
    ["Manage", "管理"],
    ["Create", "创建"],
    ["Announcements", "公告"],
    ["Computer Use", "电脑操作"],
    ["Control Windows apps from Codex", "让 Codex 控制 Windows 应用"],
    ["Chrome", "Chrome 浏览器"],
    ["Control Chrome with Codex", "让 Codex 控制 Chrome"],
    ["Spreadsheets", "电子表格"],
    ["Create and edit spreadsheet files", "创建和编辑电子表格文件"],
    ["Presentations", "演示文稿"],
    ["Create and edit presentations", "创建和编辑演示文稿"],
    ["GitHub", "GitHub"],
    ["Triage PRs, issues, CI, and publish flows", "处理 PR、问题、CI 和发布流程"],
    ["Slack", "Slack"],
    ["Read and manage Slack", "读取和管理 Slack"],
    ["Notion", "Notion"],
    ["Notion workflows for specs, research,...", "用于规格说明、研究等的 Notion 工作流"],
    ["Linear", "Linear"],
    ["Find and reference issues and projects,...", "查找和引用问题、项目等"],
    ["NVIDIA", "NVIDIA"],
    ["Guided help for NVIDIA AI, GPU, robotics,...", "NVIDIA AI、GPU、机器人等指导帮助"],
    ["Gmail", "Gmail"],
    ["Read and manage Gmail", "读取和管理 Gmail"],
    ["Google Calendar", "Google 日历"],
    ["Manage Google Calendar events and...", "管理 Google 日历事件等"],
    ["Google Drive", "Google 云端硬盘"],
    ["Work across Drive, Docs, Sheets, and Slides", "处理云端硬盘、文档、表格和幻灯片"],
    ["Teams", "Teams"],
    ["Summarize Teams and draft follow-ups", "总结 Teams 内容并起草后续事项"],
    ["SharePoint", "SharePoint"],
    ["Summarize SharePoint sites and files", "总结 SharePoint 站点和文件"],
    ["Outlook Email", "Outlook 邮箱"],
    ["Triage Outlook inboxes and draft replies", "整理 Outlook 收件箱并起草回复"],
    ["Outlook Calendar", "Outlook 日历"],
    ["Manage Outlook schedules and meeting...", "管理 Outlook 日程和会议"],
    ["Figma", "Figma"],
    ["Vercel", "Vercel"],
    ["Toggle Sidebar", "显示/隐藏侧边栏"],
    ["Toggle Bottom Panel", "显示/隐藏底部面板"],
    ["Open Terminal", "打开终端"],
    ["Toggle File Tree", "显示/隐藏文件树"],
    ["Open Browser Tab", "打开浏览器标签页"],
    ["Reload Browser Page", "重新加载浏览器页面"],
    ["Toggle Side Panel", "显示/隐藏侧边面板"],
    ["Previous Chat", "上一个对话"],
    ["Next Chat", "下一个对话"],
    ["Back", "后退"],
    ["Forward", "前进"],
    ["Zoom In", "放大"],
    ["Zoom Out", "缩小"],
    ["Actual Size", "实际大小"],
    ["Toggle Full Screen", "切换全屏"]
  ]);

  const dynamicMapUrl = "./codex-zh-map.json";
  const cacheKey = "codex-zh-auto-cache-v1";
  const textMap = new Map();
  const pendingTranslations = new Set();
  const tooltipSelector = [
    "[role='tooltip']",
    "[data-radix-popper-content-wrapper]",
    "[data-radix-tooltip-content]",
    "[class*='tooltip']",
    "[class*='Tooltip']",
    "[class*='popover']",
    "[class*='Popover']"
  ].join(", ");

  function normalizeText(value) {
    return String(value || "").replace(/\s+/g, " ").trim();
  }

  function loadCache() {
    try {
      const parsed = JSON.parse(localStorage.getItem(cacheKey) || "{}");
      return parsed && typeof parsed === "object" ? parsed : {};
    } catch (_) {
      return {};
    }
  }

  function saveCache(value) {
    try {
      localStorage.setItem(cacheKey, JSON.stringify(value));
    } catch (_) {
    }
  }

  function rebuildTextMap(extraMap) {
    textMap.clear();
    for (const [source, target] of builtinMap.entries()) {
      textMap.set(source, target);
    }
    for (const [source, target] of Object.entries(loadCache())) {
      if (source && target) {
        textMap.set(source, String(target));
      }
    }
    if (extraMap && typeof extraMap === "object") {
      for (const [source, target] of Object.entries(extraMap)) {
        if (source && target) {
          textMap.set(source, String(target));
        }
      }
    }
  }

  function shouldTranslateText(value) {
    const text = normalizeText(value);
    if (!text || text.length < 2 || text.length > 420) {
      return false;
    }
    if (/[\u3400-\u9fff]/.test(text)) {
      return false;
    }
    if (!/[A-Za-z]/.test(text)) {
      return false;
    }
    if (/^[\d\s`~!@#$%^&*()_+\-=[\]{};':"\\|,.<>/?]+$/.test(text)) {
      return false;
    }
    return true;
  }

  function sanitizeTranslation(value) {
    return normalizeText(String(value || "").replace(/^["'\s]+|["'\s]+$/g, "").replace(/^中文[:：]\s*/i, ""));
  }

  function rememberTranslation(source, target) {
    const normalizedSource = normalizeText(source);
    const normalizedTarget = normalizeText(target);
    if (!normalizedSource || !normalizedTarget || normalizedSource === normalizedTarget) {
      return false;
    }
    const cached = loadCache();
    cached[normalizedSource] = normalizedTarget;
    saveCache(cached);
    textMap.set(normalizedSource, normalizedTarget);
    return true;
  }

  async function translateAndStore(value) {
    const source = normalizeText(value);
    if (!shouldTranslateText(source) || pendingTranslations.has(source) || textMap.has(source)) {
      return;
    }
    pendingTranslations.add(source);
    try {
      const url = `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=zh-CN&dt=t&q=${encodeURIComponent(source)}`;
      const response = await fetch(url, { cache: "no-store" });
      if (!response.ok) {
        return;
      }
      const payload = await response.json();
      const translated = sanitizeTranslation(
        Array.isArray(payload?.[0]) ? payload[0].map((item) => Array.isArray(item) ? item[0] : "").join("") : ""
      );
      if (translated && rememberTranslation(source, translated)) {
        patchTree(document);
      }
    } catch (_) {
    } finally {
      pendingTranslations.delete(source);
    }
  }

  function shouldUsePartialReplacement(source) {
    const text = normalizeText(source);
    return text.length >= 12 || /\s/.test(text) || /[^\w-]/.test(text);
  }

  function getReplacement(value) {
    const text = normalizeText(value);
    if (!text) {
      return null;
    }
    const exact = textMap.get(text);
    if (exact) {
      return exact;
    }
    let replaced = text;
    let changed = false;
    for (const [source, target] of textMap.entries()) {
      if (source !== target && shouldUsePartialReplacement(source) && replaced.includes(source)) {
        replaced = replaced.split(source).join(target);
        changed = true;
      }
    }
    return changed ? replaced : null;
  }

  function shouldSkipElement(element) {
    return !element || element.closest("input, textarea, [contenteditable='true'], [contenteditable=''], [role='textbox']");
  }

  function replaceTextNode(node) {
    if (!node || node.nodeType !== Node.TEXT_NODE) {
      return;
    }
    const parent = node.parentElement;
    if (!parent || shouldSkipElement(parent)) {
      return;
    }
    const raw = node.nodeValue || "";
    const normalized = normalizeText(raw);
    if (!normalized) {
      return;
    }
    const replacement = getReplacement(normalized);
    if (!replacement || replacement === normalized) {
      translateAndStore(normalized);
      return;
    }
    node.nodeValue = raw.includes(normalized) ? raw.replace(normalized, replacement) : replacement;
  }

  function replaceAttribute(element, name) {
    const value = element.getAttribute(name);
    if (!value) {
      return;
    }
    const replacement = getReplacement(value);
    if (replacement && replacement !== value) {
      element.setAttribute(name, replacement);
    } else {
      translateAndStore(value);
    }
  }

  function isTooltipLike(element) {
    return !!(element && element.matches && element.matches(tooltipSelector));
  }

  function patchElement(element) {
    if (!(element instanceof HTMLElement) || shouldSkipElement(element)) {
      return;
    }
    ["title", "aria-label", "placeholder", "data-tooltip", "data-tooltip-content", "data-original-title"].forEach((attr) => replaceAttribute(element, attr));
    if (element.childNodes.length === 1 && element.firstChild?.nodeType === Node.TEXT_NODE) {
      replaceTextNode(element.firstChild);
    }
    const text = normalizeText(element.textContent);
    if (isTooltipLike(element) && text.length <= 320) {
      const replacement = getReplacement(text);
      if (replacement && replacement !== text) {
        element.textContent = replacement;
      } else {
        translateAndStore(text);
      }
    }
  }

  function patchTree(root) {
    if (!root) {
      return;
    }
    if (root.nodeType === Node.TEXT_NODE) {
      replaceTextNode(root);
      return;
    }
    if (root.nodeType !== Node.ELEMENT_NODE && root.nodeType !== Node.DOCUMENT_NODE) {
      return;
    }
    const walker = document.createTreeWalker(root, NodeFilter.SHOW_ELEMENT | NodeFilter.SHOW_TEXT);
    let current = walker.currentNode;
    while (current) {
      if (current.nodeType === Node.TEXT_NODE) {
        replaceTextNode(current);
      } else {
        patchElement(current);
      }
      current = walker.nextNode();
    }
  }

  async function loadDynamicMap() {
    try {
      const response = await fetch(`${dynamicMapUrl}?t=${Date.now()}`, { cache: "no-store" });
      if (!response.ok) {
        rebuildTextMap();
        return;
      }
      const payload = await response.json();
      rebuildTextMap(payload?.replacements);
    } catch (_) {
      rebuildTextMap();
    }
    patchTree(document);
  }

  function start() {
    rebuildTextMap();
    patchTree(document);
    loadDynamicMap();
    const observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        if (mutation.type === "characterData") {
          replaceTextNode(mutation.target);
          continue;
        }
        if (mutation.type === "attributes" && mutation.target instanceof HTMLElement) {
          patchElement(mutation.target);
        }
        mutation.addedNodes.forEach((node) => patchTree(node));
      }
    });
    observer.observe(document.documentElement, {
      subtree: true,
      childList: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["title", "aria-label", "placeholder", "data-tooltip", "data-tooltip-content", "data-original-title"]
    });
    setInterval(() => patchTree(document), 1500);
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", start, { once: true });
  } else {
    start();
  }
})();
