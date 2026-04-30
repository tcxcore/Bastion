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
})

return Locale
