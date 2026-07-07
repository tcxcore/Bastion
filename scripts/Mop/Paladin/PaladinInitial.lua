local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local HolyLight = SpellBook:GetSpell(2060)
local DevotionAura = SpellBook:GetSpell(465)
local SealOfRighteousness = SpellBook:GetSpell(20154)
local Judgement = SpellBook:GetSpell(20271)
local BlessingOfMight = SpellBook:GetSpell(19740)

---@class TitanPaladinInitial : Module
local M = Bastion.Module:New("TitanPaladinInitial")
M:SetDisplayName("Paladin Initial", "圣骑士新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(BlessingOfMight):IsUp() then
            if BlessingOfMight:Cast(Player) then return end
        end
        if not Player:GetAuras():FindMy(DevotionAura):IsUp() then
            if DevotionAura:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 加血保护
    if Player:GetHealthPercent() < 40 then
        if HolyLight:Cast(Player) then return end
    end

    -- 近战平砍
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 圣印与审判
    if not Player:GetAuras():FindMy(SealOfRighteousness):IsUp() then
        if SealOfRighteousness:Cast(Player) then return end
    end

    if Judgement:IsInRange(Target) and Player:GetAuras():FindMy(SealOfRighteousness):IsUp() then
        if Judgement:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
