local _, Bastion = ...
local TCX = Bastion.TCX

-- ============================================================
-- TCX 兼容适配层
-- 将原 Bastion 框架依赖的全局函数映射到 C_Timer.TCX.*
-- 并自动处理战斗中原生 API 返回值的 secret 加密标志
-- ============================================================

-- ----------------------------------------------------------
-- 版本识别与 Unwrap 解密逻辑重构
-- ----------------------------------------------------------
local buildVersion = GetBuildInfo()
Bastion.buildVersion = buildVersion

if string.match(buildVersion, "^3%.80%.") then
    Bastion.Build = "Titan"
    TCX.classic = true
    TCX.era = false
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
else
    Bastion.Build = "Unknown"
    TCX.classic = false
    TCX.era = false
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

