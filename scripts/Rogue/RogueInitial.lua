local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Eviscerate = SpellBook:GetSpell(196819)
local SinisterStrike = SpellBook:GetSpell(193315)
local Stealth = SpellBook:GetSpell(1784)

---@class RogueInitial : Module
local M = Bastion.Module:New("RogueInitial")
M:SetDisplayName("Rogue Initial", "潜行者新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:IsFacing(Target) then Player:Face(Target) end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(Stealth):IsUp() then
            if Stealth:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() then return end

    local cp = Player:GetComboPoints() or 0
    if cp >= 5 and Eviscerate:IsInRange(Target) then
        if Eviscerate:Cast(Target) then return end
    end

    if SinisterStrike:IsInRange(Target) and SinisterStrike:Cast(Target) then return end
end)

Bastion:Register(M)
return M
