local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Charge = SpellBook:GetSpell(100)
local Execute = SpellBook:GetSpell(163201)
local VictoryRush = SpellBook:GetSpell(34428)
local Slam = SpellBook:GetSpell(1464)

---@class WarriorInitial : Module
local M = Bastion.Module:New("WarriorInitial")
M:SetDisplayName("Warrior Initial", "战士新手(1-10)")

M:DefineSettings({
    {
        type = "slider",
        key = "healThreshold",
        label = "Heal Threshold (%)", labelZh = "恢复技能血量阈值 (%)",
        min = 0,
        max = 100,
        default = 80,
        step = 5
    }
})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if Player:GetHP() < M:GetSetting("healThreshold") and VictoryRush:IsInRange(Target) then
        if VictoryRush:Cast(Target) then return end
    end

    local dist = Target:GetDistance()
    if dist > 8 and dist <= 25 and Charge:IsInRange(Target) then
        if Charge:Cast(Target) then return end
    end

    local targetHP = Target:GetHP() or 100
    if targetHP <= 20 and Execute:IsInRange(Target) then
        if Execute:Cast(Target) then return end
    end

    if Slam:IsInRange(Target) and Slam:Cast(Target) then return end
end)

Bastion:Register(M)
return M
