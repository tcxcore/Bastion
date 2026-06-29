local _, Bastion = ...
local TCX = Bastion.TCX
local C_Spell = setmetatable({}, { __index = _G.C_Spell })
if _G.C_Spell then
    C_Spell.GetSpellCooldown = function(spellId)
        return TCX.Unlock("C_Spell.GetSpellCooldown", spellId)
    end
    C_Spell.GetSpellCharges = function(spellId)
        return TCX.Unlock("C_Spell.GetSpellCharges", spellId)
    end
end

local function GetSpellCooldown(spellId)
    if not _G.GetSpellCooldown then return end
    return TCX.Unlock("GetSpellCooldown", spellId)
end

local function GetSpellCharges(spellId)
    if not _G.GetSpellCharges then return end
    return TCX.Unlock("GetSpellCharges", spellId)
end

-- Create a new Spell class
---@class Spell
local Spell = {
    CastableIfFunc = false,
    PreCastFunc = false,
    OnCastFunc = false,
    PostCastFunc = false,
    lastCastAttempt = false,
    mRightButton = false,
    mLeftButton = false,
    lastCastAt = false,
    conditions = {},
    target = false,
    release_at = false
}

local usableExcludes = {
    [18562] = true
}

function Spell:__index(k)
    local response = Bastion.ClassMagic:Resolve(Spell, k)

    if response == nil then
        response = rawget(self, k)
    end

    -- 移除强制报错，允许外部探测（如 obj.ToDebugString）返回 nil
    -- if response == nil then
    --     error("Spell:__index: " .. k .. " does not exist")
    -- end

    return response
end

-- Equals
---@param other Spell
---@return boolean
function Spell:__eq(other)
    return self:GetID() == other:GetID()
end

-- tostring
---@return string
function Spell:__tostring()
    return "Bastion.__Spell(" .. self:GetID() .. ")" .. " - " .. self:GetName()
end

-- Constructor
---@param id number
---@return Spell
function Spell:New(id)
    local self = setmetatable({}, Spell)

    self.spellID = id

    return self
end

-- Duplicator
---@return Spell
function Spell:Fresh()
    return Spell:New(self:GetID())
end

-- Get the spells id
---@return number
function Spell:GetID()
    return self.spellID
end

-- Add post cast func
---@param func fun(self:Spell)
---@return Spell
function Spell:PostCast(func)
    self.PostCastFunc = func
    return self
end

-- Get the spells name
---@return string
function Spell:GetName()
    if C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(self:GetID())
        return info and info.name or nil
    end
    return GetSpellInfo(self:GetID())
end

-- Get the spells icon
---@return number
function Spell:GetIcon()
    if C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(self:GetID())
        return info and info.iconID or nil
    end
    return select(3, GetSpellInfo(self:GetID()))
end

-- Get the spells cooldown
---@return number
function Spell:GetCooldown()
    if C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(self:GetID())
        return info and info.duration or nil
    end
    return select(2, GetSpellCooldown(self:GetID()))
end

-- Get the full cooldown (time until all charges are available)
---@return number
function Spell:GetFullRechargeTime()
    if C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(self:GetID())
        if info.isEnabled == 0 then
            return 0
        end

        local chargeInfo = C_Spell.GetSpellCharges(self:GetID())
        if chargeInfo.currentCharges == chargeInfo.maxCharges then
            return 0
        end

        if chargeInfo.currentCharges == 0 then
            return info.startTime + info.duration - GetTime()
        end

        return chargeInfo.cooldownStartTime + chargeInfo.cooldownDuration - GetTime()
    end
    local start, duration, enabled = GetSpellCooldown(self:GetID())
    if enabled == 0 then
        return 0
    end

    local charges, maxCharges, chargeStart, chargeDuration = GetSpellCharges(self:GetID())
    if charges == maxCharges then
        return 0
    end

    if charges == 0 then
        return start + duration - GetTime()
    end

    return chargeStart + chargeDuration - GetTime()
end

-- Return the castable function
---@return fun(self:Spell):boolean
function Spell:GetCastableFunction()
    return self.CastableIfFunc
end

-- Return the precast function
---@return fun(self:Spell)
function Spell:GetPreCastFunction()
    return self.PreCastFunc
end

-- Get the on cast func
---@return fun(self:Spell)
function Spell:GetOnCastFunction()
    return self.OnCastFunc
end

-- Get the spells cooldown remaining
---@return number
function Spell:GetCooldownRemaining()
    if C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(self:GetID())
        return info and info.startTime + info.duration - GetTime() or nil
    end
    local start, duration = GetSpellCooldown(self:GetID())
    return start + duration - GetTime()
end

-- Get the spell count
---@return number
function Spell:GetCount()
    if C_Spell.GetSpellCastCount then
        return C_Spell.GetSpellCastCount(self:GetID())
    end
    return GetSpellCount(self:GetID())
end

-- On cooldown
---@return boolean
function Spell:OnCooldown()
    return self:GetCooldownRemaining() > 0
end

-- Clear castable function
---@return Spell
function Spell:ClearCastableFunction()
    self.CastableIfFunc = false
    return self
end

-- Cast the spell
---@param unit Unit
---@param condition? string|function
---@return boolean
function Spell:Cast(unit, condition)
    if condition then
        if type(condition) == "string" and not self:EvaluateCondition(condition) then
            return false
        elseif type(condition) == "function" and not condition(self) then
            return false
        end
    end

    if not self:Castable() then
        return false
    end

    if unit and unit:IsValid() then
        local player = Bastion.UnitManager:Get("player")
        if not self:IsInRange(unit) then
            return false
        end
        -- 自己对自己施法不需要判定视野
        if not player:IsUnit(unit) and not player:CanSee(unit) then
            return false
        end
    end

    -- Call pre cast function
    if self:GetPreCastFunction() then
        self:GetPreCastFunction()(self)
    end

    -- 记录施法前真实的鼠标物理按键状态
    self.mRightButton = IsMouseButtonDown("RightButton")
    self.mLeftButton = IsMouseButtonDown("LeftButton")

    -- 施放法术（默认使用名字施放，个别无法用名字的法术在脚本层用 ID 单独处理）
    local token = unit and unit:IsValid() and type(unit.GetOMToken) == "function" and unit:GetOMToken() or nil
    TCX.Unlock("CastSpellByName", self:GetName(), token)
    TCX.Unlock("SpellCancelQueuedSpell")

    Bastion:Debug("Casting", self)

    -- Set the last cast time
    self.lastCastAttempt = GetTime()

    -- Call post cast function
    if self:GetOnCastFunction() then
        self:GetOnCastFunction()(self)
    end

    return true
end

-- ForceCast the spell
---@param unit Unit
---@param condition string
---@return boolean
function Spell:ForceCast(unit)
    -- Call pre cast function
    -- if self:GetPreCastFunction() then
    --     self:GetPreCastFunction()(self)
    -- end

    -- 记录施法前真实的鼠标物理按键状态
    self.mRightButton = IsMouseButtonDown("RightButton")
    self.mLeftButton = IsMouseButtonDown("LeftButton")

    -- 施放法术（默认使用名字施放，个别无法用名字的法术在脚本层用 ID 单独处理）
    local token = unit and unit:IsValid() and type(unit.GetOMToken) == "function" and unit:GetOMToken() or nil
    TCX.Unlock("CastSpellByName", self:GetName(), token)
    TCX.Unlock("SpellCancelQueuedSpell")

    Bastion:Debug("Casting", self)

    -- Set the last cast time
    self.lastCastAttempt = GetTime()

    -- -- Call post cast function
    -- if self:GetOnCastFunction() then
    --     self:GetOnCastFunction()(self)
    -- end

    return true
end

-- Get post cast func
---@return fun(self:Spell)
function Spell:GetPostCastFunction()
    return self.PostCastFunc
end

-- Check if the spell is known
---@return boolean
function Spell:IsKnown()
    local IsSpellKnown = C_Spell.IsSpellKnown and C_Spell.IsSpellKnown or IsSpellKnown
    local IsPlayerSpell = C_Spell.IsPlayerSpell and C_Spell.IsPlayerSpell or IsPlayerSpell
    local isKnown = IsSpellKnown(self:GetID())
    local isPlayerSpell = IsPlayerSpell(self:GetID())
    return isKnown or isPlayerSpell
end

-- Check if the spell is on cooldown
---@return boolean
function Spell:IsOnCooldown()
    if C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(self:GetID())
        return info and info.duration > 0
    end
    return select(2, GetSpellCooldown(self:GetID())) > 0
end

-- Check if the spell is currently active (e.g. auto-attack)
---@return boolean
function Spell:IsCurrent()
    -- 1. 标准当前施法状态检测 (针对近战自动攻击等)
    local isCurrent = false
    if C_Spell.IsCurrentSpell then
        isCurrent = TCX.Unlock("C_Spell.IsCurrentSpell", self:GetID())
    end
    if isCurrent then return true end

    -- 2. 针对远程开关型自动循环物理法术 (如猎人自动射击 75, 丢魔杖等) 进行智能加固检测
    local isAutoRepeat = false
    if C_Spell.IsAutoRepeatSpell then
        isAutoRepeat = TCX.Unlock("C_Spell.IsAutoRepeatSpell", self:GetID())
    elseif IsAutoRepeatSpell then
        isAutoRepeat = TCX.Unlock("IsAutoRepeatSpell", self:GetID())
    end

    return isAutoRepeat or false
end

-- Check if the spell is usable
---@return boolean
function Spell:IsUsable()
    if C_Spell.IsSpellUsable then
        local usable, noMana = C_Spell.IsSpellUsable(self:GetID())
        return usable or usableExcludes[self:GetID()] and not noMana
    end
    local usable, noMana = IsUsableSpell(self:GetID())
    return usable or usableExcludes[self:GetID()] and not noMana
end

-- Check if the spell is castable
---@return boolean
function Spell:IsKnownAndUsable()
    return self:IsKnown() and not self:IsOnCooldown() and self:IsUsable()
end

-- Check if the spell is castable
---@return boolean
function Spell:Castable()
    if self:GetCastableFunction() then
        return self:GetCastableFunction()(self)
    end

    return self:IsKnownAndUsable()
end

-- Set a script to check if the spell is castable
---@param func fun(spell:Spell):boolean
---@return Spell
function Spell:CastableIf(func)
    self.CastableIfFunc = func
    return self
end

-- Set a script to run before the spell has been cast
---@param func fun(spell:Spell)
---@return Spell
function Spell:PreCast(func)
    self.PreCastFunc = func
    return self
end

-- Set a script to run after the spell has been cast
---@param func fun(spell:Spell)
---@return Spell
function Spell:OnCast(func)
    self.OnCastFunc = func
    return self
end


-- Click the spell
---@param x number|Vector3
---@param y? number
---@param z? number
---@return boolean
function Spell:Click(x, y, z)
    if type(x) == 'table' then
        x, y, z = x.x, x.y, x.z
    end
    -- SpellIsTargeting() 返回 true 表示法术处于 AOE 等待鼠标选点状态
    if SpellIsTargeting() then
        -- 实时读取当前鼠标物理按键状态（而非 Cast() 时的快照）
        -- 解决读条地面技能期间用户改变鼠标按键状态导致恢复错误的问题
        local rightNow = IsMouseButtonDown("RightButton")
        local leftNow = IsMouseButtonDown("LeftButton")
        -- TCX 使用 ClickPosition 进行 AOE 落点点击
        TCX.ClickPosition(x, y, z)
        -- 基于当前时刻的真实鼠标状态恢复锁定
        if rightNow then
            TCX.Unlock("TurnOrActionStart")
        elseif leftNow then
            TCX.Unlock("CameraOrSelectOrMoveStart")
        end
        return true
    end
    return false
end

-- Check if the spell is castable and cast it
---@param unit Unit
---@return boolean
function Spell:Call(unit)
    if self:Castable() then
        self:Cast(unit)
        return true
    end
    return false
end

-- Check if the spell is castable and cast it
---@return boolean
function Spell:HasRange()
    if C_Spell.SpellHasRange then
        return C_Spell.SpellHasRange(self:GetID())
    end
    return SpellHasRange(self:GetName())
end

-- Get the range of the spell
---@return number
---@return number
function Spell:GetRange()
    if C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(self:GetID())
        return info and info.maxRange or nil, info and info.minRange or nil
    end
    local name, rank, icon, castTime, minRange, maxRange, spellID, originalIcon = GetSpellInfo(self:GetID())
    return maxRange, minRange
end

-- Check if the spell is in range of the unit
---@param unit Unit
---@return boolean
function Spell:IsInRange(unit)
    local IsSpellInRange = C_Spell.IsSpellInRange and C_Spell.IsSpellInRange or IsSpellInRange
    local hasRange = self:HasRange()

    if hasRange == false then
        return true
    end

    local inRange
    if C_Spell.IsSpellInRange then
        inRange = IsSpellInRange(self:GetID(), unit:GetOMToken())
    else
        local name = self:GetName()
        if name then
            inRange = IsSpellInRange(name, unit:GetOMToken())
        end
    end

    if inRange == 1 or inRange == true then
        return true
    end
    
    if inRange == 0 or inRange == false then
        return false
    end

    return Bastion.UnitManager['player']:InMelee(unit)
end

-- Get the last cast time
---@return number
function Spell:GetLastCastTime()
    return self.lastCastAt
end

-- Get time since last cast
---@return number
function Spell:GetTimeSinceLastCast()
    if not self:GetLastCastTime() then
        return math.huge
    end
    return GetTime() - self:GetLastCastTime()
end

-- Get the time since the last cast attempt
---@return number
function Spell:GetTimeSinceLastCastAttempt()
    if not self.lastCastAttempt then
        return math.huge
    end
    return GetTime() - self.lastCastAttempt
end

-- Get the spells charges
---@return number
function Spell:GetCharges()
    if C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(self:GetID())
        return info and info.currentCharges or nil
    end
    return GetSpellCharges(self:GetID())
end

function Spell:GetMaxCharges()
    if C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(self:GetID())
        return info and info.maxCharges or nil
    end
    return select(2, GetSpellCharges(self:GetID()))
end

function Spell:GetCastLength()
    if C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(self:GetID())
        return info and info.castTime or nil
    end
    return select(4, GetSpellInfo(self:GetID()))
end

-- Get the spells charges
---@return number
function Spell:GetChargesFractional()
    if C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(self:GetID())
        if not info then return 0 end

        if info.currentCharges == info.maxCharges then
            return info.maxCharges
        end

        local timeSinceStart = GetTime() - info.cooldownStartTime
        timeSinceStart = math.max(0, math.min(info.cooldownDuration, timeSinceStart))
        local progress = timeSinceStart / info.cooldownDuration

        return info.currentCharges + progress
    end
    local charges, maxCharges, start, duration = GetSpellCharges(self:GetID())
    if not charges then return 0 end

    if charges == maxCharges then
        return maxCharges
    end

    local timeSinceStart = GetTime() - start
    timeSinceStart = math.max(0, math.min(duration, timeSinceStart))
    local progress = timeSinceStart / duration

    return charges + progress
end

-- Get the spells charges remaining
---@return number
function Spell:GetChargesRemaining()
    if C_Spell.GetSpellCharges then
        local info = C_Spell.GetSpellCharges(self:GetID())
        return info and info.currentCharges or nil
    end
    local charges, maxCharges, start, duration = GetSpellCharges(self:GetID())
    return charges
end

-- Create a condition for the spell
---@param name string
---@param func fun(self:Spell):boolean
---@return Spell
function Spell:Condition(name, func)
    self.conditions[name] = {
        func = func
    }
    return self
end

-- Get a condition for the spell
---@param name string
---@return function | nil
function Spell:GetCondition(name)
    local condition = self.conditions[name]
    if condition then
        return condition
    end

    return nil
end

-- Evaluate a condition for the spell
---@param name string
---@return boolean
function Spell:EvaluateCondition(name)
    local condition = self:GetCondition(name)
    if condition then
        return condition.func(self)
    end

    return false
end

-- Check if the spell has a condition
---@param name string
---@return boolean
function Spell:HasCondition(name)
    local condition = self:GetCondition(name)
    if condition then
        return true
    end

    return false
end

-- Set the spells target
---@param unit Unit
---@return Spell
function Spell:SetTarget(unit)
    self.target = unit
    return self
end

-- Get the spells target
---@return Unit
function Spell:GetTarget()
    return self.target
end

-- IsMagicDispel
---@return boolean
function Spell:IsMagicDispel()
    return ({
        [88423] = true
    })[self:GetID()]
end

-- IsCurseDispel
---@return boolean
function Spell:IsCurseDispel()
    return ({
        [88423] = true
    })[self:GetID()]
end

-- IsPoisonDispel
---@return boolean
function Spell:IsPoisonDispel()
    return ({
        [88423] = true
    })[self:GetID()]
end

-- IsDiseaseDispel
---@return boolean
function Spell:IsDiseaseDispel()
    return ({})[self:GetID()]
end

-- IsSpell
---@param spell Spell
---@return boolean
function Spell:IsSpell(spell)
    return self:GetID() == spell:GetID()
end

-- GetCost
---@return number
function Spell:GetCost()
    if C_Spell.GetSpellPowerCost then
        local info = C_Spell.GetSpellPowerCost(self:GetID())
        return info and info.cost or 0
    end
    local cost = GetSpellPowerCost(self:GetID())
    return cost and cost.cost or 0
end

-- IsFree
---@return boolean
function Spell:IsFree()
    return self:GetCost() == 0
end

return Spell
