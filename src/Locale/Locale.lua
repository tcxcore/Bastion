local tcx, Bastion = ...
-- Bastion 本地化模块
-- 通过 WoW GetLocale() API 自动检测客户端语言，回退策略：找不到翻译则返回原始键名

---@class Locale
local Locale = {}
Locale.__index = Locale

-- 存储所有已注册的语言数据
Locale._data = {}

-- 检测当前客户端语言（WoW API）
Locale._lang = (GetLocale and GetLocale()) or "enUS"

-- 注册一组语言翻译
---@param lang string  语言代码，例如 "zhCN"、"zhTW"
---@param strings table  键值对翻译表
function Locale:Register(lang, strings)
    if not self._data[lang] then
        self._data[lang] = {}
    end
    for k, v in pairs(strings) do
        self._data[lang][k] = v
    end
end

-- 获取当前语言的翻译表（找不到翻译时回退到键名本身）
---@return table
function Locale:GetLocale()
    local strings = self._data[self._lang] or {}
    return setmetatable(strings, {
        -- 找不到翻译时直接返回原始英文键名，保证向后兼容
        __index = function(_, k) return k end
    })
end

-- ============================================================
-- 简体中文翻译 (zhCN)
-- ============================================================
Locale:Register("zhCN", {
    -- 命令帮助文本
    ["Toggle bastion on/off"]                       = "切换 Bastion 开启/关闭",
    ["Toggle debug mode on/off"]                    = "切换调试模式 开启/关闭",
    ["Dump spells to a file"]                       = "将法术列表导出到文件",
    ["Toggle a module on/off"]                      = "切换指定模块 开启/关闭",
    ["Toggle m+ module on/off"]                     = "切换大秘境模块 开启/关闭",
    ["Dump the list of immune kidney shot spells"]  = "导出免疫技能列表",

    -- 通用状态
    ["Enabled"]             = "已启用",
    ["Disabled"]            = "已禁用",
    ["enabled"]             = "已启用",
    ["disabled"]            = "已禁用",
    ["Registered"]          = "已注册",

    -- 调试模式
    ["Debug mode enabled"]  = "调试模式已启用",
    ["Debug mode disabled"] = "调试模式已禁用",

    -- 模块管理
    ["Module not found"]    = "未找到该模块",

    -- 大秘境工具 (MythicPlusUtils)
    ["Debuff logging"]                  = "减益效果记录",
    ["Cast logging"]                    = "施法记录",
    ["[MythicPlusUtils] Unknown command"] = "[大秘境工具] 未知命令",
    ["Available commands:"]             = "可用命令：",
    ["debuffs"]                         = "减益效果 (debuffs)",
    ["casts"]                           = "施法记录 (casts)",

    -- 模块库依赖检查（格式化字符串，使用 :format() 填充参数）
    ["Circular dependency detected between %s and %s"]      = "检测到 %s 与 %s 之间存在循环依赖",
    ["Library %s depends on %s but it's not registered"]    = "模块库 %s 依赖 %s，但后者尚未注册",
    ["Library %s not found"]                                = "模块库 %s 未找到",
    ["Library %s has no exports"]                           = "模块库 %s 没有导出任何内容",
    ["Library %s does not exist"]                           = "模块库 %s 不存在",

    -- ============================================================
    -- UI 系统
    -- ============================================================
    ["Control Panel"]           = "控制面板",
    ["Module Management"]       = "模块管理",
    ["Module Settings"]         = "模块设置",
    ["Select Module"]           = "选择模块",
    ["Enable Module"]           = "启用模块",
    ["Open Settings"]           = "打开设置",
    ["No settings available"]   = "无可用设置",
    ["Module Info"]             = "模块信息",
    ["Module"]                  = "模块",
    ["Status"]                  = "状态",
    ["Settings Count"]          = "设置项数量",
    ["Settings"]                = "设置",
    ["Back"]                    = "返回",
    ["Reset to Default"]        = "恢复默认",
    ["Settings reset to default"] = "设置已恢复为默认值",

    -- 快捷键提示
    ["Toggle on/off"]           = "切换开关",
    ["Toggle UI panel"]         = "切换界面",
    ["Toggle current module"]   = "切换当前模块",
    ["Left-Click"]              = "左键点击",
    ["Right-Click"]             = "右键点击",
    ["Toggle Bastion on/off"]   = "切换 Bastion 开关",

    -- UI 初始化
    ["UI system initialized"]   = "UI 系统已初始化",
    ["Config loaded"]           = "配置已加载",
    ["Config saved"]            = "配置已保存",
    ["Please download it from:"]              = "请前往此处下载：",

    -- 框架设置页
    ["Framework Settings"]                  = "框架设置",
    ["Hotkey Settings"]                     = "快捷键设置",
    ["General Settings"]                    = "通用设置",
    ["Modifier"]                            = "修饰键",
    ["Key"]                                 = "按键",
    ["Debug Mode"]                          = "调试模式",
    ["Debug mode enabled"]                  = "调试模式已启用",
    ["Debug mode disabled"]                 = "调试模式已禁用",
    ["Update Frequency"]                    = "数据更新频率",
    ["Update frequency set to "]            = "数据更新频率已设置为 ",
    ["1Hz (Low power - 1000ms)"]           = "1Hz (节能 - 1000ms)",
    ["2Hz (Recommended - 500ms)"]          = "2Hz (推荐 - 500ms)",
    ["5Hz (Standard - 200ms)"]             = "5Hz (标准 - 200ms)",
    ["10Hz (Responsive - 100ms)"]          = "10Hz (流畅 - 100ms)",
    ["20Hz (High speed - 50ms)"]           = "20Hz (高频 - 50ms)",
    ["60Hz (Extreme - 16.6ms)"]            = "60Hz (极速 - 16.6ms)",
    ["Click button then press key combo"]   = "点击按钮后按下组合键进行录制",
    ["Press key combo..."]                  = "请按下组合键...",
    ["Hotkey updated"]                      = "快捷键已更新",
})

Bastion.Locale = Locale
return Locale
