local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local DemonsBite = SpellBook:GetSpell(344859)
local ChaosStrike = SpellBook:GetSpell(344862)
local FelRush = SpellBook:GetSpell(344865)

---@class DemonHunterInitial : Module
local M = Bastion.Module:New("DemonHunterInitial")
M:SetDisplayName("DemonHunter Initial", "恶魔猎手新手(8-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    local dist = Target:GetDistance()
    if dist > 8 and dist <= 15 and FelRush:IsUsable() then
        if FelRush:Cast(Player) then return end
    end

    local fury = Player:GetPower(17) or 0
    if fury >= 40 and ChaosStrike:IsInRange(Target) then
        if ChaosStrike:Cast(Target) then return end
    end

    if DemonsBite:IsInRange(Target) and DemonsBite:Cast(Target) then return end
end)

Bastion:Register(M)
return M
