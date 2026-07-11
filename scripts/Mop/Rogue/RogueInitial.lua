local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local SinisterStrike = SpellBook:GetSpell(1752)
local Eviscerate = SpellBook:GetSpell(2098)
local Stealth = SpellBook:GetSpell(1784)

---@class TitanRogueInitial : Module
local M = Bastion.Module:New("TitanRogueInitial")
M:SetDisplayName("Rogue Initial", "潜行者新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        -- if not Player:GetAuras():FindMy(Stealth):IsUp() then
        --     if Stealth:Cast(Player) then return end
        -- end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 近战平砍
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    local comboPoints = Player:GetComboPoints(Target) or 0
    if comboPoints >= 3 and Eviscerate:IsInRange(Target) then
        if Eviscerate:Cast(Target) then return end
    end

    if SinisterStrike:IsInRange(Target) then
        if SinisterStrike:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
