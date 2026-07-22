local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx
local C_UnitAuras = setmetatable({}, { __index = _G.C_UnitAuras })
if _G.C_UnitAuras then
    C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
        return _G.C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
    end
    C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
        return _G.C_UnitAuras.GetAuraDataByIndex(unit, index, filter)
    end
end

-- Create a new AuraTable class
---@class AuraTable
local AuraTable = {}
AuraTable.__index = AuraTable

-- Constructor
---@param unit Unit
---@return AuraTable
function AuraTable:New(unit)
    local self = setmetatable({}, AuraTable)

    self.unit = unit

    self.auras = {}
    self.playerAuras = {}

    self.guid = unit:GetGUID()
    self.instanceIDLookup = {}
    self.lastUpdate = 0

    return self
end

---@param auras UnitAuraUpdateInfo
---@return nil


---@param instanceID number
---@return nil
function AuraTable:RemoveInstanceID(instanceID)
    if not self.instanceIDLookup[instanceID] then
        return
    end

    local id = self.instanceIDLookup[instanceID]

    if self.playerAuras[id] and self.playerAuras[id][instanceID] then
        self.playerAuras[id][instanceID] = nil
        self.instanceIDLookup[instanceID] = nil
        return
    end

    if self.auras[id] and self.auras[id][instanceID] then
        self.auras[id][instanceID] = nil
        self.instanceIDLookup[instanceID] = nil
        return
    end
end

-- Update the aura table
---@param instanceID number
---@param aura Aura
---@return nil
function AuraTable:AddOrUpdateAuraInstanceID(instanceID, aura)
    local spellId = aura:GetSpell():GetID()

    self.instanceIDLookup[instanceID] = spellId

    local source = aura:GetSource()
    local isPlayer = aura:GetCastByPlayer()
    if not isPlayer and source and source:IsValid() then
        isPlayer = Bastion.UnitManager['player']:IsUnit(source)
    end

    if isPlayer then
        if not self.playerAuras[spellId] then
            self.playerAuras[spellId] = {}
        end

        self.playerAuras[spellId][instanceID] = aura
    else
        if not self.auras[spellId] then
            self.auras[spellId] = {}
        end

        self.auras[spellId][instanceID] = aura
    end
end

-- Get a units buffs
---@return nil
function AuraTable:GetUnitBuffs()
    if _G.UnitBuff or _G.UnitAura or (Bastion.Build ~= "Retail" and Bastion.Build ~= "PTR" and Bastion.Build ~= "Mop") then
        for i = 1, 40 do
            local aura = Bastion.Aura:New(self.unit, i, 'HELPFUL')

            if not aura:IsValid() then
                break
            end

            local spellId = aura:GetSpell():GetID()
            local src = aura:GetSource()

            if src and Bastion.UnitManager['player']:IsUnit(src) then
                if not self.playerAuras[spellId] then
                    self.playerAuras[spellId] = {}
                end

                table.insert(self.playerAuras[spellId], aura)
            else
                if not self.auras[spellId] then
                    self.auras[spellId] = {}
                end

                table.insert(self.auras[spellId], aura)
            end
        end
        return
    end

    local token = self.unit:GetOMToken()
    if not token then return end

    local i = 1
    while true do
        local a = C_UnitAuras.GetAuraDataByIndex(token, i, 'HELPFUL')
        if not a then break end

        local aura = Bastion.Aura:CreateFromUnitAuraInfo(a)
        if aura:IsValid() then
            self:AddOrUpdateAuraInstanceID(aura:GetAuraInstanceID(), aura)
        end
        i = i + 1
    end
end

-- Get a units debuffs
---@return nil
function AuraTable:GetUnitDebuffs()
    if _G.UnitDebuff or _G.UnitAura or (Bastion.Build ~= "Retail" and Bastion.Build ~= "PTR" and Bastion.Build ~= "Mop") then
        for i = 1, 40 do
            local aura = Bastion.Aura:New(self.unit, i, 'HARMFUL')

            if not aura:IsValid() then
                break
            end

            local spellId = aura:GetSpell():GetID()
            local src = aura:GetSource()

            if src and Bastion.UnitManager['player']:IsUnit(src) then
                if not self.playerAuras[spellId] then
                    self.playerAuras[spellId] = {}
                end

                table.insert(self.playerAuras[spellId], aura)
            else
                if not self.auras[spellId] then
                    self.auras[spellId] = {}
                end

                table.insert(self.auras[spellId], aura)
            end
        end
        return
    end

    local token = self.unit:GetOMToken()
    if not token then return end

    local i = 1
    while true do
        local a = C_UnitAuras.GetAuraDataByIndex(token, i, 'HARMFUL')
        if not a then break end

        local aura = Bastion.Aura:CreateFromUnitAuraInfo(a)
        if aura:IsValid() then
            self:AddOrUpdateAuraInstanceID(aura:GetAuraInstanceID(), aura)
        end
        i = i + 1
    end
end


---@return nil
function AuraTable:Update()
    self:Clear()
    self.lastUpdate = GetTime()

    if not self.unit or not self.unit:IsValid() then return end

    -- 彻底改用魔兽世界原生 API 获取 BUFF 和 DEBUFF 列表
    self:GetUnitBuffs()
    self:GetUnitDebuffs()
end

-- Get a units auras
---@return table
function AuraTable:GetUnitAuras()
    local now = GetTime()

    -- GUID 变动判定，必须强制全量刷新
    if self.unit:GetGUID() ~= self.guid then
        self.guid = self.unit:GetGUID()
        self:Update()
    elseif not self.lastUpdate or (now - self.lastUpdate) > (Bastion.UpdateInterval or 0.5) then
        self:Update()
    end

    return self.auras
end

-- Get a units auras
---@return table
function AuraTable:GetMyUnitAuras()
    local now = GetTime()

    if self.unit:GetGUID() ~= self.guid then
        self.guid = self.unit:GetGUID()
        self:Update()
    elseif not self.lastUpdate or (now - self.lastUpdate) > (Bastion.UpdateInterval or 0.5) then
        self:Update()
    end

    return self.playerAuras
end

-- Clear the aura table
---@return nil
function AuraTable:Clear()
    self.auras = {}
    self.playerAuras = {}
    self.instanceIDLookup = {}
end

-- Check if the unit has a specific aura
---@param spell Spell
---@return Aura
function AuraTable:Find(spell)
    if not spell then return Bastion.Aura:New() end
    local spellId = spell:GetID()

    local auras = self:GetUnitAuras()
    local aurasub = auras[spellId]

    if not aurasub or next(aurasub) == nil then
        local nameToFind = spell:GetName()
        if nameToFind then
            for id, list in pairs(auras) do
                for _, a in pairs(list) do
                    if a ~= nil and a:IsUp() and a:GetName() == nameToFind then
                        return a
                    end
                end
            end
        end
        return Bastion.Aura:New()
    end

    for k, a in pairs(aurasub) do
        if a ~= nil then
            if a:IsUp() then -- Handle expired and non refreshed dropoffs not coming in UNIT_AURA
                return a
            else
                local instanceID = a:GetAuraInstanceID()
                if instanceID then
                    self:RemoveInstanceID(instanceID)
                end
            end
        end
    end

    return Bastion.Aura:New()
end

-- Check if the unit has a specific aura
---@param spell Spell
---@return Aura
function AuraTable:FindMy(spell)
    if not spell then return Bastion.Aura:New() end
    local spellId = spell:GetID()

    local auras = self:GetMyUnitAuras()
    local aurasub = auras[spellId]

    if not aurasub or next(aurasub) == nil then
        local nameToFind = spell:GetName()
        if nameToFind then
            for id, list in pairs(auras) do
                for _, a in pairs(list) do
                    if a ~= nil and a:IsUp() and a:GetName() == nameToFind then
                        return a
                    end
                end
            end
        end
        return Bastion.Aura:New()
    end

    for k, a in pairs(aurasub) do
        if a ~= nil then
            if a:IsUp() then -- Handle expired and non refreshed dropoffs not coming in UNIT_AURA
                return a
            else
                local instanceID = a:GetAuraInstanceID()
                if instanceID then
                    self:RemoveInstanceID(instanceID)
                end
            end
        end
    end

    return Bastion.Aura:New()
end

-- Check if the unit has a specific aura
---@param spell Spell
---@param source Unit
---@return Aura
function AuraTable:FindFrom(spell, source)
    local auras = self:GetUnitAuras()
    local aurasub = auras[spell:GetID()]

    if not aurasub then
        return Bastion.Aura:New()
    end

    for k, a in pairs(aurasub) do
        if a ~= nil then
            if a:IsUp() then -- Handle expired and non refreshed dropoffs not coming in UNIT_AURA
                if a:GetSource() == source then
                    return a
                end
            else
                local instanceID = a:GetAuraInstanceID()
                if instanceID then
                    self:RemoveInstanceID(instanceID)
                end
            end
        end
    end

    return Bastion.Aura:New()
end

-- Find the aura from the current unit
---@param spell Spell
---@return Aura
function AuraTable:FindTheirs(spell)
    local auras = self:GetUnitAuras()
    local aurasub = auras[spell:GetID()]

    if not aurasub then
        return Bastion.Aura:New()
    end

    for k, a in pairs(aurasub) do
        if a ~= nil then
            if a:IsUp() then -- Handle expired and non refreshed dropoffs not coming in UNIT_AURA
                if self.unit:IsUnit(a:GetSource()) then
                    return a
                end
            else
                local instanceID = a:GetAuraInstanceID()
                if instanceID then
                    self:RemoveInstanceID(instanceID)
                end
            end
        end
    end

    return Bastion.Aura:New()
end

-- Find any
---@param spell Spell
---@return Aura
function AuraTable:FindAny(spell)
    local a = self:Find(spell)
    if a:IsValid() then
        return a
    end

    return self:FindMy(spell)
end

-- FindAnyOf
---@param spells List
---@return Aura
function AuraTable:FindAnyOf(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindAny(cur)
        if aura:IsValid() then
            return aura, true
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindAnyOfMy
---@param spells List
---@return Aura
function AuraTable:FindAnyOfMy(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindMy(cur)
        if aura:IsValid() then
            return aura, true
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindAnyOfTheirs
---@param spells List
---@return Aura
function AuraTable:FindAnyOfTheirs(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindTheirs(cur)
        if aura:IsValid() then
            return aura, true
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindAnyFrom
---@param spells List
---@param source Unit
---@return Aura
function AuraTable:FindAnyFrom(spells, source)
    return spells:reduce(function(acc, cur)
        local aura = self:FindFrom(cur, source)
        if aura:IsValid() then
            return aura, true
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLongestOf
---@param spells List
---@return Aura
function AuraTable:FindLongestOf(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:Find(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() > acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLongestOfMy
---@param spells List
---@return Aura
function AuraTable:FindLongestOfMy(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindMy(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() > acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLongestOfTheirs
---@param spells List
---@return Aura
function AuraTable:FindLongestOfTheirs(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindTheirs(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() > acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLongestOfFrom
---@param spells List
---@param source Unit
---@return Aura
function AuraTable:FindLongestOfFrom(spells, source)
    return spells:reduce(function(acc, cur)
        local aura = self:FindFrom(cur, source)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() > acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindShortestOf
---@param spells List
---@return Aura
function AuraTable:FindShortestOf(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:Find(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() < acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindShortestOfMy
---@param spells List
---@return Aura
function AuraTable:FindShortestOfMy(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindMy(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() < acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindShortestOfTheirs
---@param spells List
---@return Aura
function AuraTable:FindShortestOfTheirs(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindTheirs(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() < acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindShortestOfFrom
---@param spells List
---@param source Unit
---@return Aura
function AuraTable:FindShortestOfFrom(spells, source)
    return spells:reduce(function(acc, cur)
        local aura = self:FindFrom(cur, source)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetRemainingTime() < acc:GetRemainingTime() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindMostOf
---@param spells List
---@return Aura
function AuraTable:FindMostOf(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:Find(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() > acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindMostOfMy
---@param spells List
---@return Aura
function AuraTable:FindMostOfMy(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindMy(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() > acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindMostOfTheirs
---@param spells List
---@return Aura
function AuraTable:FindMostOfTheirs(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindTheirs(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() > acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindMostOfFrom
---@param spells List
---@param source Unit
---@return Aura
function AuraTable:FindMostOfFrom(spells, source)
    return spells:reduce(function(acc, cur)
        local aura = self:FindFrom(cur, source)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() > acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLeastOf
---@param spells List
---@return Aura
function AuraTable:FindLeastOf(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:Find(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() < acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLeastOfMy
---@param spells List
---@return Aura
function AuraTable:FindLeastOfMy(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindMy(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() < acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLeastOfTheirs
---@param spells List
---@return Aura
function AuraTable:FindLeastOfTheirs(spells)
    return spells:reduce(function(acc, cur)
        local aura = self:FindTheirs(cur)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() < acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- FindLeastOfFrom
---@param spells List
---@param source Unit
---@return Aura
function AuraTable:FindLeastOfFrom(spells, source)
    return spells:reduce(function(acc, cur)
        local aura = self:FindFrom(cur, source)
        if aura:IsValid() then
            if not acc:IsValid() then
                return aura
            end
            if aura:GetCount() < acc:GetCount() then
                return aura
            end
        end
        return acc
    end, Bastion.Aura:New())
end

-- Has any stealable aura
---@return boolean
function AuraTable:HasAnyStealableAura()
    for _, auras in pairs(self:GetUnitAuras()) do
        for _, aura in pairs(auras) do
            if aura:IsUp() then -- Handle expired and non refreshed dropoffs not coming in UNIT_AURA
                if aura:GetIsStealable() then
                    return true
                end
            else
                self:RemoveInstanceID(aura:GetAuraInstanceID())
            end
        end
    end

    return false
end

-- Has any dispelable aura
---@param spell Spell
---@return boolean
function AuraTable:HasAnyDispelableAura(spell)
    for _, auras in pairs(self:GetUnitAuras()) do
        for _, aura in pairs(auras) do
            if aura:IsUp() then -- Handle expired and non refreshed dropoffs not coming in UNIT_AURA
                if aura:IsDebuff() and aura:IsDispelableBySpell(spell) then
                    return true
                end
            else
                self:RemoveInstanceID(aura:GetAuraInstanceID())
            end
        end
    end

    return false
end

Bastion.AuraTable = AuraTable
return AuraTable
