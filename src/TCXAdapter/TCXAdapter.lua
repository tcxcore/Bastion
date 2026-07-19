local tcx, Bastion = ...
local TCX = setmetatable({}, { __index = tcx })
Bastion.TCX = TCX

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
-- TCX 兼容适配层
-- ============================================================

-- ----------------------------------------------------------
-- 版本识别
-- ----------------------------------------------------------
local buildVersion = GetBuildInfo()
Bastion.buildVersion = buildVersion

if string.match(buildVersion, "^3%.80%.") then
    Bastion.Build = "Titan"
    TCX.classic = true
    TCX.era = false
elseif string.match(buildVersion, "^1%.15%.") then
    Bastion.Build = "Classic"
    TCX.classic = true
    TCX.era = true
elseif string.match(buildVersion, "^2%.5%.") then
    Bastion.Build = "TBC"
    TCX.classic = false
    TCX.era = true
elseif string.match(buildVersion, "^12%.0%.") then
    Bastion.Build = "Retail"
    TCX.classic = false
    TCX.era = false
elseif string.match(buildVersion, "^12%.1%.") then
    Bastion.Build = "PTR"
    TCX.classic = false
    TCX.era = false
elseif string.match(buildVersion, "^5%.5%.") then
    Bastion.Build = "Mop"
    TCX.classic = false
    TCX.era = false
else
    Bastion.Build = "Unknown"
    TCX.classic = false
    TCX.era = false
end

if hostFrame then
    hostFrame.Build = Bastion.Build
end



-- ----------------------------------------------------------
-- 兼容字段（原 Tinkr.classic/era/Common）
-- 现统一挂载到 Bastion.TCX 表下
-- ----------------------------------------------------------
TCX.Common                           = TCX.Common or {}
TCX.Common.GetAnglesBetweenPositions = function(x1, y1, z1, x2, y2, z2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- ----------------------------------------------------------
-- ----------------------------------------------------------
-- 覆盖或扩展 TCX API 行为 (避免污染全局 _G)
-- ----------------------------------------------------------
TCX.Click = function(x, y, z)
    return TCX.ClickPosition(x, y, z)
end

-- ----------------------------------------------------------
-- 载具坐标与朝向折算世界坐标
-- ----------------------------------------------------------

local function GetWorldRotation(obj, _depth)
    _depth = _depth or 0
    if _depth > 5 then return tcx.ObjectRotation(obj) end
    local f = tcx.ObjectRotation(obj)
    if not f then return nil end
    local t = tcx.ObjectTransport(obj)
    if t and t ~= obj then
        local tr = GetWorldRotation(t, _depth + 1)
        if tr then
            f = (f + tr) % (2 * math.pi)
        end
    end
    return f
end

local function GetWorldPosition(obj, _depth)
    _depth = _depth or 0
    if _depth > 5 then return tcx.ObjectPosition(obj) end
    local x, y, z = tcx.ObjectPosition(obj)
    if not x then return nil end
    local t = tcx.ObjectTransport(obj)
    if t and t ~= obj then
        local tx, ty, tz = GetWorldPosition(t, _depth + 1)
        local yaw = GetWorldRotation(t, _depth + 1)
        if tx and yaw then
            local c, s = math.cos(yaw), math.sin(yaw)
            return tx + (x * c - y * s),
                   ty + (x * s + y * c),
                   tz + z
        end
    end
    return x, y, z
end

-- 覆盖 Bastion.TCX 代理表中的 API
TCX.ObjectPosition = GetWorldPosition
TCX.ObjectRotation = GetWorldRotation



