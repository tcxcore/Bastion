local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Shoot = SpellBook:GetSpell(5019)
local Smite = SpellBook:GetSpell(585)
local ShadowWordPain = SpellBook:GetSpell(589)
local PowerWordFortitude = SpellBook:GetSpell(1243)
local LesserHeal = SpellBook:GetSpell(2050)

---@class TitanPriestInitial : Module
local M = Bastion.Module:New("TitanPriestInitial")
M:SetDisplayName("Priest Initial", "牧师新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(PowerWordFortitude):IsUp() then
            if PowerWordFortitude:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 治疗保护
    if Player:GetHealthPercent() < 50 then
        if LesserHeal:Cast(Player) then return end
    end

    -- 魔杖或平砍自动攻击
    if not Shoot:IsCurrent() and Shoot:IsInRange(Target) then
        Shoot:Cast(Target)
    elseif not Shoot:IsKnown() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    if not Target:GetAuras():FindMy(ShadowWordPain):IsUp() and ShadowWordPain:IsInRange(Target) then
        if ShadowWordPain:Cast(Target) then return end
    end

    if not Player:IsMoving() then
        if Smite:IsInRange(Target) then
            if Smite:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
