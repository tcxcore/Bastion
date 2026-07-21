local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx

local Unit = Bastion.Unit

-- 获取缓存 Key 的统一辅助函数，优先保持传入参数的最简形态
local function GetCacheKey(param)
    if not param then return nil end
    local t = type(param)
    if t == "userdata" then
        return TCX.ObjectGUID(param) or tostring(param)
    end
    return param
end

-- Create a new UnitManager class
---@class UnitManager
local UnitManager = {
    units = {},
    customUnits = {},
    objects = {},
    cache = {}
}

function UnitManager:__index(k)
    if k == 'none' then
        return self:Get('none')
    end

    if UnitManager[k] then
        return UnitManager[k]
    end

    local k = k or 'none'

    -- if custom unit exists, return it it's cache expired return a new one
    if self.customUnits[k] then
        if not self.cache:IsCached(k) then
            self.customUnits[k].unit:Update()
            self.cache:Set(k, self.customUnits[k].unit, 0.5)
        end

        return self.customUnits[k].unit
    end

    local key = GetCacheKey(k)

    if key and self.objects[key] then
        return self.objects[key]
    end

    if key and self.objects[key] == nil then
        -- 仅当该对象能在游戏内被正确检索出时才进行创建
        if type(k) == "userdata" or TCX.Object(k) then
            local unit = Unit:New(k) -- 直接用 k 实例创建，不进行二次转换
            self:SetObject(unit)
            return unit
        end
    end

    return self.objects['none']
end

-- Constructor
---@return UnitManager
function UnitManager:New()
    local self = setmetatable({}, UnitManager)
    self.units = {}
    self.customUnits = {}
    self.cache = Bastion.Cache:New()
    return self
end

-- Get or create a unit
---@param token string | userdata
---@return Unit
function UnitManager:Get(token)
    if token == 'none' or not token then
        if not self.objects['none'] then
            self.objects['none'] = Unit:New()
        end
        return self.objects['none']
    end

    local key = GetCacheKey(token)

    if key and self.objects[key] == nil then
        -- 创建对象时直接用原始参数创建，不转换
        self.objects[key] = Unit:New(token)
    end

    return Bastion.Refreshable:New(self.objects[key], function()
        local curKey = GetCacheKey(token) or "none"

        if self.objects[curKey] == nil then
            self.objects[curKey] = Unit:New(token)
        end
        return self.objects[curKey]
    end)
end

-- Get a unit by guid
---@param guid string
---@return Unit
function UnitManager:GetObject(guid)
    return self.objects[guid]
end

-- Set a unit by guid
---@param unit Unit
---@return nil
function UnitManager:SetObject(unit)
    local guid = unit:GetGUID()
    if guid then
        self.objects[guid] = unit
    end
end

-- Create a custom unit and cache it for .5 seconds
---@param token string
---@param cb fun():Unit
---@return Unit
function UnitManager:CreateCustomUnit(token, cb)
    local unit = cb()
    local cachedUnit = Bastion.Cacheable:New(unit, cb)

    if unit == nil then
        error("UnitManager:CreateCustomUnit - Invalid unit: " .. token)
    end

    if self.customUnits[token] == nil then
        self.customUnits[token] = {
            unit = cachedUnit,
            cb = cb
        }
    end

    self.cache:Set(token, cachedUnit, 0.5)

    return cachedUnit
end

---@return Unit[]
function UnitManager:GetGroupUnits()
    local list = {}
    local addedGuids = {}

    -- 1. 首先收集 ObjectManager 中的 3D 友方单位
    if Bastion.ObjectManager and Bastion.ObjectManager.friends then
        Bastion.ObjectManager.friends:each(function(unit)
            if unit and unit:IsValid() then
                local guid = unit:GetGUID()
                if guid then
                    addedGuids[guid] = true
                end
                table.insert(list, unit)
            end
        end)
    end

    -- 2. 检查原生 party/raid Token 确保不漏队友（尤其是远距离超视距队友）
    local isRaid = IsInRaid and IsInRaid()
    local isGroup = IsInGroup and IsInGroup()

    if isRaid then
        for i = 1, 40 do
            local token = "raid" .. i
            if UnitExists(token) then
                local guid = UnitGUID(token)
                if guid and not addedGuids[guid] then
                    addedGuids[guid] = true
                    table.insert(list, self:Get(token))
                end
            end
        end
    elseif isGroup then
        local pGuid = UnitGUID("player")
        if pGuid and not addedGuids[pGuid] then
            addedGuids[pGuid] = true
            table.insert(list, self:Get("player"))
        end
        for i = 1, 4 do
            local token = "party" .. i
            if UnitExists(token) then
                local guid = UnitGUID(token)
                if guid and not addedGuids[guid] then
                    addedGuids[guid] = true
                    table.insert(list, self:Get(token))
                end
            end
        end
    end

    -- 若单人无队伍且 3D 列表中未发现自己，补全 Player
    if #list == 0 then
        table.insert(list, self:Get("player"))
    end

    return list
end

---@param selector? string "lowest_hp" | "most_deficit" | "highest_hp"
---@param includeOffline? boolean 是否包含离线/跨副本/不可见单位，默认 false
---@return Unit[]
function UnitManager:GetSortedFriends(selector, includeOffline)
    selector = selector or "lowest_hp"
    local now = GetTime()

    -- 帧内缓存：同一帧 (GetTime) 内重复请求相同的排序选择器时，直接复用快照数组，避免反复排序
    self._sortCache = self._sortCache or {}
    local cacheKey = selector .. "_" .. tostring(includeOffline or false)
    if self._sortCacheTime == now and self._sortCache[cacheKey] then
        return self._sortCache[cacheKey]
    end

    if self._sortCacheTime ~= now then
        self._sortCache = {}
        self._sortCacheTime = now
    end

    local rawUnits = self:GetGroupUnits()
    local units = {}
    local player = self:Get("player")

    for i = 1, #rawUnits do
        local u = rawUnits[i]
        if u and u:IsValid() and u.IsAlive then
            local isConnected = u:IsConnected()
            local isVisible = u:IsVisible()
            local canSee = (not player) or player:IsUnit(u) or player:CanSee(u)
            if includeOffline or (isConnected and isVisible and canSee) then
                table.insert(units, u)
            end
        end
    end

    selector = selector or "lowest_hp"

    table.sort(units, function(a, b)
        if not a then return false end
        if not b then return true end

        local aliveA = a:IsAlive()
        local aliveB = b:IsAlive()
        if aliveA ~= aliveB then
            return aliveA and not aliveB
        end

        if selector == "lowest_hp" then
            local hpA = a:GetHealthPercent() or 100
            local hpB = b:GetHealthPercent() or 100
            if hpA ~= hpB then
                return hpA < hpB
            end
        elseif selector == "most_deficit" then
            local defA = (a:GetMaxHealth() or 0) - (a:GetHealth() or 0)
            local defB = (b:GetMaxHealth() or 0) - (b:GetHealth() or 0)
            if defA ~= defB then
                return defA > defB
            end
        elseif selector == "highest_hp" then
            local hpA = a:GetHealthPercent() or 0
            local hpB = b:GetHealthPercent() or 0
            if hpA ~= hpB then
                return hpA > hpB
            end
        end

        local guidA = a:GetGUID() or ""
        local guidB = b:GetGUID() or ""
        return guidA < guidB
    end)

    self._sortCache[cacheKey] = units
    return units
end

---@description Enumerates all friendly units in the battlefield
---@param cb fun(unit: Unit):boolean
---@return nil
function UnitManager:EnumFriends(cb)
    Bastion.ObjectManager.friends:each(function(unit)
        if cb(unit) then
            return true
        end
    end)
end

-- Enum Enemies (object manager)
---@param cb fun(unit: Unit):boolean
---@return nil
function UnitManager:EnumEnemies(cb)
    Bastion.ObjectManager.activeEnemies:each(function(unit)
        if cb(unit) then
            return true
        end
    end)
end

-- Enum Units (object manager)
---@param cb fun(unit: Unit):boolean
---@return nil
function UnitManager:EnumUnits(cb)
    Bastion.ObjectManager.enemies:each(function(unit)
        if cb(unit) then
            return true
        end
    end)
end

-- Get the number of friends with a buff (party/raid members)
---@param spell Spell
---@return number
function UnitManager:GetNumFriendsWithBuff(spell)
    local count = 0
    self:EnumFriends(function(unit)
        if unit:GetAuras():FindMy(spell):IsUp() then
            count = count + 1
        end
        return false
    end)
    return count
end

-- Get the number of friends alive (party/raid members)
---@return number
function UnitManager:GetNumFriendsAlive()
    local count = 0
    self:EnumFriends(function(unit)
        if unit:IsAlive() then
            count = count + 1
        end
        return false
    end)
    return count
end

-- Get the friend with the most friends within a given radius (party/raid members)
---@param radius number
---@return Unit
---@return table
function UnitManager:GetFriendWithMostFriends(radius)
    local unit = nil
    local count = 0
    local friends = {}
    self:EnumFriends(function(u)
        if u:IsAlive() then
            local c = 0
            self:EnumFriends(function(other)
                if other:IsAlive() and u:GetDistance(other) <= radius then
                    c = c + 1
                end
                return false
            end)
            if c > count then
                unit = u
                count = c
                friends = {}
                self:EnumFriends(function(other)
                    if other:IsAlive() and u:GetDistance(other) <= radius then
                        table.insert(friends, other)
                    end
                    return false
                end)
            end
        end
        return false
    end)
    return unit, friends
end

-- Get the enemy with the most enemies within a given radius
function UnitManager:GetEnemiesWithMostEnemies(radius)
    local unit = nil
    local count = 0
    local enemies = {}
    self:EnumEnemies(function(u)
        if u:IsAlive() then
            local c = 0
            self:EnumEnemies(function(other)
                if other:IsAlive() and u:GetDistance(other) <= radius then
                    c = c + 1
                end
                return false
            end)
            if c > count then
                unit = u
                count = c
                enemies = {}
                self:EnumEnemies(function(other)
                    if other:IsAlive() and u:GetDistance(other) <= radius then
                        table.insert(enemies, other)
                    end
                    return false
                end)
            end
        end
        return false
    end)
    return unit, enemies
end

-- Find the centroid of the most dense area of friends (party/raid members) of a given radius within a given range
---@param radius number
---@param range number
---@return Vector3 | nil
function UnitManager:FindFriendsCentroid(radius, range)
    local unit, friends = self:GetFriendWithMostFriends(radius)
    if unit == nil then
        return nil
    end

    local centroid = Bastion.Vector3:New(0, 0, 0)
    local zstart = -math.huge
    for i = 1, #friends do
        local p = friends[i]:GetPosition()
        centroid = centroid + p
        zstart = p.z > zstart and p.z or zstart
    end

    centroid = centroid / #friends

    if unit:GetPosition():Distance(centroid) > range then
        return unit:GetPosition()
    end

    local _, _, z = TCX.TraceLine(
        centroid.x,
        centroid.y,
        centroid.z + 5,
        centroid.x,
        centroid.y,
        centroid.z - 5,
        0x100151
    )

    centroid.z = z + 0.01

    return centroid
end

-- Find the centroid of the most dense area of enemies of a given radius within a given range
---@param radius number
---@param range number
---@return Vector3 | nil
function UnitManager:FindEnemiesCentroid(radius, range)
    local unit, enemies = self:GetEnemiesWithMostEnemies(radius)
    if unit == nil then
        return nil
    end

    local centroid = Bastion.Vector3:New(0, 0, 0)
    local zstart = -math.huge
    for i = 1, #enemies do
        local p = enemies[i]:GetPosition()
        centroid = centroid + p
        zstart = p.z > zstart and p.z or zstart
    end

    centroid = centroid / #enemies

    if unit:GetPosition():Distance(centroid) > range then
        return unit:GetPosition()
    end

    local _, _, z = TCX.TraceLine(
        centroid.x,
        centroid.y,
        centroid.z + 5,
        centroid.x,
        centroid.y,
        centroid.z - 5,
        0x100151
    )

    centroid.z = z + 0.01

    return centroid
end

Bastion.UnitManager = UnitManager
return UnitManager
