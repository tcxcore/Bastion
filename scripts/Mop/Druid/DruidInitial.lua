local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Wrath = SpellBook:GetSpell(5176)
local Moonfire = SpellBook:GetSpell(8921)
local MarkOfTheWild = SpellBook:GetSpell(1126)
local HealingTouch = SpellBook:GetSpell(5185)
local Rejuvenation = SpellBook:GetSpell(774)

---@class TitanDruidInitial : Module
local M = Bastion.Module:New("TitanDruidInitial")
M:SetDisplayName("Druid Initial", "德鲁伊新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(MarkOfTheWild):IsUp() then
            if MarkOfTheWild:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 治疗保护
    if Player:GetHealthPercent() < 50 and not Player:GetAuras():FindMy(Rejuvenation):IsUp() then
        if Rejuvenation:Cast(Player) then return end
    end
    if Player:GetHealthPercent() < 30 and not Player:IsMoving() then
        if HealingTouch:Cast(Player) then return end
    end

    -- 近战平砍
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    if not Target:GetAuras():FindMy(Moonfire):IsUp() and Moonfire:IsInRange(Target) then
        if Moonfire:Cast(Target) then return end
    end

    if not Player:IsMoving() then
        if Wrath:IsInRange(Target) then
            if Wrath:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
