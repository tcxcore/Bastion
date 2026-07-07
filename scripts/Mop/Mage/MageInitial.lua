local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Shoot = SpellBook:GetSpell(5019)
local Fireball = SpellBook:GetSpell(133)
local Frostbolt = SpellBook:GetSpell(116)
local FireBlast = SpellBook:GetSpell(2136)
local FrostArmor = SpellBook:GetSpell(168)
local ArcaneIntellect = SpellBook:GetSpell(1459)

---@class TitanMageInitial : Module
local M = Bastion.Module:New("TitanMageInitial")
M:SetDisplayName("Mage Initial", "法师新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(FrostArmor):IsUp() then
            if FrostArmor:Cast(Player) then return end
        end
        if not Player:GetAuras():FindMy(ArcaneIntellect):IsUp() then
            if ArcaneIntellect:Cast(Player) then return end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 魔杖或平砍自动攻击
    if Target:IsEnemy() then
        if not Shoot:IsCurrent() and Shoot:IsInRange(Target) then
            Shoot:Cast(Target)
        elseif not Shoot:IsKnown() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
            AutoAttack:Cast(Target)
        end
    end

    -- 战斗循环
    if FireBlast:IsInRange(Target) then
        if FireBlast:Cast(Target) then return end
    end

    if not Player:IsMoving() then
        if Frostbolt:IsInRange(Target) then
            if Frostbolt:Cast(Target) then return end
        elseif Fireball:IsInRange(Target) then
            if Fireball:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
