local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local HeroicStrike = SpellBook:GetSpell(78)
local Charge = SpellBook:GetSpell(100)
local Rend = SpellBook:GetSpell(772)
local BattleShout = SpellBook:GetSpell(6673)
local Execute = SpellBook:GetSpell(5308)

---@class TitanWarriorInitial : Module
local M = Bastion.Module:New("TitanWarriorInitial")
M:SetDisplayName("Warrior Initial", "战士新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(BattleShout):IsUp() then
            if BattleShout:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 冲锋
    if Charge:IsInRange(Target) and not Player:IsAffectingCombat() then
        if Charge:Cast(Target) then return end
    end

    -- 近战平砍
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    if Target:GetHealthPercent() <= 20 and Execute:IsInRange(Target) then
        if Execute:Cast(Target) then return end
    end

    if not Target:GetAuras():FindMy(Rend):IsUp() and Rend:IsInRange(Target) then
        if Rend:Cast(Target) then return end
    end

    if HeroicStrike:IsInRange(Target) then
        if HeroicStrike:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
