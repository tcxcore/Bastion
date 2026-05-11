local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Shoot = SpellBook:GetSpell(5019)
local ShadowBolt = SpellBook:GetSpell(686)
local Immolate = SpellBook:GetSpell(348)
local Corruption = SpellBook:GetSpell(172)
local DemonSkin = SpellBook:GetSpell(687)
local SummonImp = SpellBook:GetSpell(688)

---@class TitanWarlockInitial : Module
local M = Bastion.Module:New("TitanWarlockInitial")
M:SetDisplayName("Warlock Initial", "术士新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(DemonSkin):IsUp() then
            if DemonSkin:Cast(Player) then return end
        end
        if not UnitExists('pet') and not Player:IsMoving() then
            if SummonImp:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 魔杖或平砍自动攻击
    if not Shoot:IsCurrent() and Shoot:IsInRange(Target) then
        Shoot:Cast(Target)
    elseif not Shoot:IsKnown() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    if not Target:GetAuras():FindMy(Immolate):IsUp() and Immolate:IsInRange(Target) then
        if not Player:IsMoving() then
            if Immolate:Cast(Target) then return end
        end
    end

    if not Target:GetAuras():FindMy(Corruption):IsUp() and Corruption:IsInRange(Target) then
        if Corruption:Cast(Target) then return end
    end

    if not Player:IsMoving() then
        if ShadowBolt:IsInRange(Target) then
            if ShadowBolt:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
