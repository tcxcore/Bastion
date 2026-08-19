local AOP, Bastion = ...
local AOP = setmetatable({}, { __index = AOP })
Bastion.AOP = AOP

if Bastion then
    Bastion.DebugMode = false
end

local hostFrame = GetClickFrame("BastionHostFrame")
if not hostFrame then
    hostFrame = CreateFrame("Button", "BastionHostFrame")
end

if hostFrame then
    hostFrame.pendingModules = hostFrame.pendingModules or {}
    hostFrame.RegisterModule = function(self, createFunc)
        table.insert(self.pendingModules, createFunc)
    end
end

-- ============================================================
-- AOP 兼容适配层
-- ============================================================

-- ----------------------------------------------------------
-- 版本识别
-- ----------------------------------------------------------
local buildVersion = GetBuildInfo()
Bastion.buildVersion = buildVersion

if string.match(buildVersion, "^3%.80%.") then
    Bastion.Build = "Titan"
    AOP.classic = true
    AOP.era = false
elseif string.match(buildVersion, "^1%.15%.") then
    Bastion.Build = "Classic"
    AOP.classic = true
    AOP.era = true
elseif string.match(buildVersion, "^2%.5%.") then
    Bastion.Build = "TBC"
    AOP.classic = false
    AOP.era = true
elseif string.match(buildVersion, "^12%.1%.") then
    Bastion.Build = "Retail"
    AOP.classic = false
    AOP.era = false
elseif string.match(buildVersion, "^12%.2%.") then
    Bastion.Build = "PTR"
    AOP.classic = false
    AOP.era = false
elseif string.match(buildVersion, "^5%.5%.") then
    Bastion.Build = "Mop"
    AOP.classic = false
    AOP.era = false
else
    Bastion.Build = "Unknown"
    AOP.classic = false
    AOP.era = false
end

if hostFrame then
    hostFrame.Build = Bastion.Build
end



-- ----------------------------------------------------------
-- 兼容字段（原 Tinkr.classic/era/Common）
-- 现统一挂载到 Bastion.AOP 表下
-- ----------------------------------------------------------
AOP.Common                           = AOP.Common or {}
AOP.Common.GetAnglesBetweenPositions = function(x1, y1, z1, x2, y2, z2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- ----------------------------------------------------------
-- ----------------------------------------------------------
-- 覆盖或扩展 AOP API 行为 (避免污染全局 _G)
-- ----------------------------------------------------------
AOP.Click = function(x, y, z)
    return AOP.ClickPosition(x, y, z)
end




