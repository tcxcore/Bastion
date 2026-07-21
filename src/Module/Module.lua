local tcx, Bastion = ...
-- Bastion 模块类
-- 支持声明式设置系统，UI 可自动根据设置定义生成对应控件

---@class Module
local Module = {}
Module.__index = Module

-- __tostring
---@return string
function Module:__tostring()
    return "Bastion.__Module(" .. self.name .. ")"
end

-- 构造函数
---@param name string
---@return Module
function Module:New(name)
    local module = {}
    setmetatable(module, Module)

    module.name = name
    module.enabled = false
    module.synced = {}

    -- 设置系统
    module.displayName = nil       -- {en="...", zh="..."}
    module.settingDefs = {}        -- 设置定义数组
    module.settings = {}           -- 当前设置值字典

    return module
end

----------------------------------------------------------------------
-- 基础模块控制
----------------------------------------------------------------------

-- 启用模块
---@return nil
function Module:Enable()
    self.enabled = true
end

-- 禁用模块
---@return nil
function Module:Disable()
    self.enabled = false
end

-- 切换模块
---@return nil
function Module:Toggle()
    if self.enabled then
        self:Disable()
    else
        self:Enable()
    end
end

----------------------------------------------------------------------
-- 同步（战斗循环）
----------------------------------------------------------------------

-- 添加同步函数
---@param func function
---@return nil
function Module:Sync(func)
    table.insert(self.synced, func)
end

-- 移除同步函数
---@param func function
---@return nil
function Module:Unsync(func)
    for i = 1, #self.synced do
        if self.synced[i] == func then
            table.remove(self.synced, i)
            return
        end
    end
end

-- Tick（每帧执行）
---@return nil
function Module:Tick()
    if self.enabled then
        for i = 1, #self.synced do
            self.synced[i]()
        end
    end
end

----------------------------------------------------------------------
-- 双语显示名
----------------------------------------------------------------------

--- 设置模块的中英文显示名称
---@param en string 英文名称
---@param zh string 中文名称
function Module:SetDisplayName(en, zh)
    self.displayName = { en = en, zh = zh }
end

--- 获取本地化显示名（根据客户端语言自动选择）
---@return string
function Module:GetDisplayName()
    if self.displayName then
        local lang = (GetLocale and GetLocale()) or "enUS"
        if lang == "zhCN" or lang == "zhTW" then
            return self.displayName.zh or self.displayName.en or self.name
        else
            return self.displayName.en or self.name
        end
    end
    return self.name
end

----------------------------------------------------------------------
-- 声明式设置系统
----------------------------------------------------------------------

--- 声明模块的可配置设置项
--- 每个设置项为一个 table，包含以下字段：
---   key      (string)  唯一标识符
---   type     (string)  控件类型: "slider" / "toggle" / "dropdown" / "header"
---   label    (string)  英文标签
---   labelZh  (string)  中文标签
---   default  (any)     默认值
---   min/max/step (number)  slider 专用
---   options  (table)   dropdown 专用 {{text="...", value=...}, ...}
---@param defs table 设置定义数组
function Module:DefineSettings(defs)
    self.settingDefs = defs
    -- 尝试优先恢复硬盘上该模块已保存的 JSON 设置
    if Bastion and Bastion.ConfigManager and Bastion.ConfigManager.LoadModuleConfig then
        Bastion.ConfigManager:LoadModuleConfig(self)
    end
    -- 初始化默认值（仅当未设置时）
    for _, def in ipairs(defs) do
        if def.key and def.default ~= nil and self.settings[def.key] == nil then
            self.settings[def.key] = def.default
        end
    end
end

--- 获取设置值，未设置时回退到默认值
---@param key string
---@return any
function Module:GetSetting(key)
    if self.settings[key] ~= nil then
        return self.settings[key]
    end
    -- 回退到定义中的默认值
    for _, def in ipairs(self.settingDefs) do
        if def.key == key then
            return def.default
        end
    end
    return nil
end

--- 设置指定配置项的值
---@param key string
---@param value any
function Module:SetSetting(key, value)
    self.settings[key] = value
end

--- 获取所有设置定义（供 UI 自动生成控件）
---@return table
function Module:GetSettingDefinitions()
    return self.settingDefs
end

--- 判断是否有可配置的设置项
---@return boolean
function Module:HasSettings()
    return #self.settingDefs > 0
end

--- 恢复所有设置为默认值
function Module:ResetSettings()
    self.settings = {}
    for _, def in ipairs(self.settingDefs) do
        if def.key and def.default ~= nil then
            self.settings[def.key] = def.default
        end
    end
end

--- 导出当前设置为 table（用于持久化序列化）
---@return table
function Module:ExportSettings()
    local data = {}
    for _, def in ipairs(self.settingDefs) do
        if def.key then
            data[def.key] = self.settings[def.key]
        end
    end
    return data
end

--- 从 table 导入设置值（用于从配置文件恢复）
---@param data table
function Module:ImportSettings(data)
    if not data then return end
    for k, v in pairs(data) do
        self.settings[k] = v
    end
end

Bastion.Module = Module
return Module
