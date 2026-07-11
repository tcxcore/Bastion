local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local AutoShot = SpellBook:GetSpell(75)
local RaptorStrike = SpellBook:GetSpell(2973)
local SerpentSting = SpellBook:GetSpell(1978)
local ArcaneShot = SpellBook:GetSpell(3044)
local HuntersMark = SpellBook:GetSpell(1130)

---@class TitanHunterInitial : Module
local M = Bastion.Module:New("TitanHunterInitial")
M:SetDisplayName("Hunter Initial", "猎人新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then

    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 猎人印记
    if not Target:GetAuras():FindMy(HuntersMark):IsUp() and HuntersMark:IsInRange(Target) then
        if HuntersMark:Cast(Target) then return end
    end

    -- 距离判定
    local inMelee = Player:InMelee(Target)

    if inMelee then
        if not AutoAttack:IsCurrent() then
            AutoAttack:Cast(Target)
        end
        if RaptorStrike:IsReady() then
            if RaptorStrike:Cast(Target) then return end
        end
    else
        if not AutoShot:IsCurrent() then
            AutoShot:Cast(Target)
        end
        if not Target:GetAuras():FindMy(SerpentSting):IsUp() and SerpentSting:IsInRange(Target) then
            if SerpentSting:Cast(Target) then return end
        end
        if ArcaneShot:IsInRange(Target) then
            if ArcaneShot:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
