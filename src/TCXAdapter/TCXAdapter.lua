local _, Bastion = ...
local TCX = Bastion.TCX

-- ============================================================
-- TCX 兼容适配层
-- 将原 Bastion 框架依赖的全局函数映射到 C_Timer.TCX.*
-- 并自动处理战斗中原生 API 返回值的 secret 加密标志
-- ============================================================

-- ----------------------------------------------------------
-- 兼容字段（原 Tinkr.classic/era/Common）
-- 现统一挂载到 Bastion.TCX 表下，TCX 仅支持 Retail
-- ----------------------------------------------------------
TCX.classic                          = false
TCX.era                              = false
TCX.Common                           = TCX.Common or {}
TCX.Common.GetAnglesBetweenPositions = function(x1, y1, z1, x2, y2, z2)
    return math.atan2(y2 - y1, x2 - x1)
end

-- ----------------------------------------------------------
-- 对象管理 API
-- ----------------------------------------------------------
Object                               = function(v) return TCX.Object(v) end
Objects                              = function(ft) return TCX.Objects(ft) end
ObjectGUID                           = function(o) return TCX.ObjectGUID(o) end
ObjectType                           = function(o) return TCX.ObjectType(o) end
ObjectToken                          = function(o) return TCX.ObjectToken(o) end

-- ----------------------------------------------------------
-- 对象属性 API
-- ----------------------------------------------------------
ObjectPosition                       = function(o) return TCX.ObjectPosition(o) end
ObjectRotation                       = function(o) return TCX.ObjectRotation(o) end
ObjectCombatReach                    = function(o) return TCX.ObjectCombatReach(o) end
ObjectMovementFlag                   = function(o) return TCX.ObjectMovementFlag(o) end
ObjectID                             = function(o) return TCX.ObjectId(o) end
ObjectHeight                         = function(o) return TCX.ObjectHeight(o) end

-- ----------------------------------------------------------
-- 状态判断 API
-- ----------------------------------------------------------
ObjectIsOutdoors                     = function(o) return TCX.ObjectIsOutdoors(o) end
ObjectIsSubmerged                    = function(o) return TCX.ObjectIsSubmerged(o) end
ObjectLootable                       = function(o) return TCX.ObjectLootable(o) end

-- ----------------------------------------------------------
-- TraceLine 语义转换
-- (此名称不与暴雪 UI 冲突)
TraceLine                            = function(sx, sy, sz, ex, ey, ez, flags)
    local cx, cy, cz = TCX.TraceLine(sx, sy, sz, ex, ey, ez, flags)
    if cx == ex and cy == ey and cz == ez then
        return 0, 0, 0
    end
    return cx, cy, cz
end

-- AOE 落点点击
Click                                = function(x, y, z)
    return TCX.ClickPosition(x, y, z)
end

-- ----------------------------------------------------------
-- 文件系统 API
-- ----------------------------------------------------------
ReadFile                             = function(p) return TCX.ReadFile(p) end
WriteFile                            = function(p, d, a) return TCX.WriteFile(p, d, a) end
ListFiles                            = function(d) return TCX.ListFiles(d) end
ListDirectories                      = function(d) return TCX.ListDirectories(d) end
CreateDirectory                      = function(d) return TCX.CreateDirectory(d) end
DirectoryExists                      = function(d) return TCX.DirectoryExists(d) end
FileExists                           = function(f) return TCX.FileExists(f) end
-- (所有的 Unwrap 解密逻辑已被移动至各模块内部的 local 作用域中)

