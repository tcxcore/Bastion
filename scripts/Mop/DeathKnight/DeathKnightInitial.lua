local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local IcyTouch = SpellBook:GetSpell(45477)
local PlagueStrike = SpellBook:GetSpell(45462)
local BloodStrike = SpellBook:GetSpell(45902)
local DeathCoil = SpellBook:GetSpell(47541)
local DeathGrip = SpellBook:GetSpell(49576)

---@class TitanDeathKnightInitial : Module
local M = Bastion.Module:New("TitanDeathKnightInitial")
M:SetDisplayName("DeathKnight Initial", "死亡骑士新手(55-58)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then

    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 近战平砍
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    if DeathGrip:IsInRange(Target) and not Player:InMelee(Target) then
        if DeathGrip:Cast(Target) then return end
    end

    if not Target:GetAuras():FindMy(IcyTouch):IsUp() and IcyTouch:IsInRange(Target) then
        if IcyTouch:Cast(Target) then return end
    end

    if not Target:GetAuras():FindMy(PlagueStrike):IsUp() and PlagueStrike:IsInRange(Target) then
        if PlagueStrike:Cast(Target) then return end
    end

    if BloodStrike:IsInRange(Target) then
        if BloodStrike:Cast(Target) then return end
    end

    if DeathCoil:IsInRange(Target) then
        if DeathCoil:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
