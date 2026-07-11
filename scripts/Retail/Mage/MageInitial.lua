local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local FireBlast = SpellBook:GetSpell(108853)
local Frostbolt = SpellBook:GetSpell(116)
local ArcaneIntellect = SpellBook:GetSpell(1459)

---@class MageInitial : Module
local M = Bastion.Module:New("MageInitial")
M:SetDisplayName("Mage Initial", "法师新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    if not Player:IsAffectingCombat() then
        if ArcaneIntellect:IsKnown() and not Player:GetAuras():FindMy(ArcaneIntellect):IsUp() then
            if ArcaneIntellect:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if FireBlast:IsInRange(Target) and FireBlast:Cast(Target) then return end
    if not Player:IsMoving() and Frostbolt:IsInRange(Target) then
        if Frostbolt:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
