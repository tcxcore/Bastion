-- Bastion 配置管理器
-- 使用 TCX 文件系统 + YAML 编解码实现配置持久化

local _, Bastion = ...
local TCX = Bastion.TCX

---@class ConfigManager
local ConfigManager = {}
ConfigManager.__index = ConfigManager

-- 配置文件路径
local CONFIG_DIR       = "scripts/Bastion/config/"
local CONFIG_FILE      = CONFIG_DIR .. "settings.yaml"
local FRAMEWORK_FILE   = CONFIG_DIR .. "framework.yaml"

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
    if not TCX.DirectoryExists(CONFIG_DIR) then
        TCX.CreateDirectory(CONFIG_DIR)
    end
end

--- 从磁盘加载配置（YAML 反序列化）
---@return boolean 是否加载成功
function ConfigManager:Load()
    if not TCX.FileExists(CONFIG_FILE) then
        self.data = {}
        return false
    end

    local content = TCX.ReadFile(CONFIG_FILE)
    if not content or content == "" then
        self.data = {}
        return false
    end

    local ok, result = pcall(function()
        return TCX.YamlDecode(content)
    end)

    if ok and type(result) == "table" then
        self.data = result
        return true
    else
        Bastion:Print("|cFFFF4444[ConfigManager]|r 配置文件解析失败，使用默认配置")
        self.data = {}
        return false
    end
end

--- 保存配置到磁盘（YAML 序列化）
---@return boolean 是否保存成功
function ConfigManager:Save()
    self:EnsureDir()

    local ok, yamlStr = pcall(function()
        return TCX.YamlEncode(self.data)
    end)

    if not ok or not yamlStr then
        Bastion:Print("|cFFFF4444[ConfigManager]|r 配置序列化失败")
        return false
    end

    local success = TCX.WriteFile(CONFIG_FILE, yamlStr, false)
    if not success then
        Bastion:Print("|cFFFF4444[ConfigManager]|r 配置文件写入失败")
    end
    return success == true
end

--- 从所有已注册模块收集设置并保存
---@param modules table 模块列表
---@param enabled boolean Bastion 总开关状态
function ConfigManager:SaveAll(modules, enabled)
    self.data.bastion = self.data.bastion or {}
    self.data.bastion.enabled = enabled

    self.data.modules = {}
    for i = 1, #modules do
        local m = modules[i]
        self.data.modules[m.name] = {
            enabled = m.enabled,
            settings = m:ExportSettings(),
        }
    end

    self:Save()
end

--- 将已保存的配置应用到所有已注册模块
---@param modules table 模块列表
---@return boolean bastion_enabled Bastion 总开关状态
function ConfigManager:LoadAll(modules)
    self:Load()

    -- 恢复 Bastion 总开关
    local bastion_enabled = false
    if self.data.bastion then
        bastion_enabled = self.data.bastion.enabled or false
    end

    -- 恢复各模块配置
    if self.data.modules then
        for i = 1, #modules do
            local m = modules[i]
            local saved = self.data.modules[m.name]
            if saved then
                if saved.enabled then
                    m:Enable()
                else
                    m:Disable()
                end
                m:ImportSettings(saved.settings)
            end
        end
    end

    return bastion_enabled
end

--- 保存框架级设置（快捷键、调试模式等）
---@param settings table
function ConfigManager:SaveFrameworkSettings(settings)
    self:EnsureDir()
    local ok, yamlStr = pcall(function()
        return TCX.YamlEncode(settings)
    end)
    if ok and yamlStr then
        TCX.WriteFile(FRAMEWORK_FILE, yamlStr, false)
    end
end

--- 加载框架级设置
---@return table|nil
function ConfigManager:LoadFrameworkSettings()
    if not TCX.FileExists(FRAMEWORK_FILE) then return nil end
    local content = TCX.ReadFile(FRAMEWORK_FILE)
    if not content or content == "" then return nil end
    local ok, result = pcall(function()
        return TCX.YamlDecode(content)
    end)
    if ok and type(result) == "table" then
        return result
    end
    return nil
end

return ConfigManager
