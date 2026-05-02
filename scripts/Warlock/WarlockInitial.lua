local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local SummonImp = SpellBook:GetSpell(688)
local ShadowBolt = SpellBook:GetSpell(686)
local CorruptionDebuff = SpellBook:GetSpell(146739)
local Corruption = SpellBook:GetSpell(172)

---@class WarlockInitial : Module
local M = Bastion.Module:New("WarlockInitial")
M:SetDisplayName("Warlock Initial", "术士新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:IsFacing(Target) then Player:Face(Target) end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    local Pet = Bastion.UnitManager:Get('pet')
    if not Pet or not Pet:IsValid() then
        if not Player:IsMoving() then
            if SummonImp:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() then return end

    if not Target:GetAuras():FindMy(CorruptionDebuff):IsUp() and Corruption:IsInRange(Target) then
        if Corruption:Cast(Target) then return end
    end

    if not Player:IsMoving() and ShadowBolt:IsInRange(Target) then
        if ShadowBolt:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
