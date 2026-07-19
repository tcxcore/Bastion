-- Bastion 配置管理器
-- 使用 TCX 文件系统 + JSON 编解码实现配置持久化

local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx

---@class ConfigManager
local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- 配置文件路径
local CONFIG_DIR       = "scripts/Bastion/config/"
local FRAMEWORK_FILE   = CONFIG_DIR .. "framework.json"

--- 创建新的配置管理器实例
---@return ConfigManager
function ConfigManager:New()
    local self = setmetatable({}, ConfigManager)
    self.data = {}
    return self
end

--- 获取配置文件路径
---@return string
function ConfigManager:GetPath()
    return CONFIG_FILE
end

--- 确保配置目录存在
function ConfigManager:EnsureDir()
    local path = ""
    for segment in string.gmatch(CONFIG_DIR, "[^/]+") do
        if path == "" then
            path = segment
        else
            path = path .. "/" .. segment
        end
        if not TCX.DirectoryExists(path) then
            TCX.CreateDirectory(path)
        end
    end
end



--- 从所有已注册模块收集设置并分别保存
---@param modules table 模块列表
function ConfigManager:SaveAll(modules)
    self:EnsureDir()

    for i = 1, #modules do
        local m = modules[i]
        local moduleConfig = {
            enabled = m.enabled,
            settings = m:ExportSettings(),
        }

        local ok, jsonStr = pcall(function()
            return TCX.JsonEncode(moduleConfig)
        end)

        if ok and jsonStr then
            TCX.WriteFile(CONFIG_DIR .. m.name .. ".json", jsonStr, false)
        else
            Bastion:Print("|cFFFF4444[ConfigManager]|r 配置序列化失败: " .. m.name)
        end
    end
end

--- 将已保存的配置应用到所有已注册模块（读取独立配置文件）
---@param modules table 模块列表
function ConfigManager:LoadAll(modules)
    -- 恢复各模块（战斗循环）独立配置
    for i = 1, #modules do
        local m = modules[i]
        local moduleFile = CONFIG_DIR .. m.name .. ".json"
        local saved = nil

        if TCX.FileExists(moduleFile) then
            local content = TCX.ReadFile(moduleFile)
            if content and content ~= "" then
                local ok, result = pcall(function()
                    return TCX.JsonDecode(content)
                end)
                if ok and type(result) == "table" then
                    saved = result
                end
            end
        end



        if saved then
            if saved.enabled then
                m:Enable()
            else
                m:Disable()
            end
            if saved.settings then
                m:ImportSettings(saved.settings)
            end
        end
    end
end

--- 保存框架级设置（快捷键、调试模式等）
---@param settings table
function ConfigManager:SaveFrameworkSettings(settings)
    self:EnsureDir()
    local ok, jsonStr = pcall(function()
        return TCX.JsonEncode(settings)
    end)
    if ok and jsonStr then
        TCX.WriteFile(FRAMEWORK_FILE, jsonStr, false)
    end
end

--- 加载框架级设置
---@return table|nil
function ConfigManager:LoadFrameworkSettings()
    if not TCX.FileExists(FRAMEWORK_FILE) then return nil end
    local content = TCX.ReadFile(FRAMEWORK_FILE)
    if not content or content == "" then return nil end
    local ok, result = pcall(function()
        return TCX.JsonDecode(content)
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

Bastion.ConfigManager = ConfigManager
return ConfigManager
