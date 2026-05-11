local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local CrusaderStrike = SpellBook:GetSpell(35395)
local WordOfGlory = SpellBook:GetSpell(85673)
local Judgment = SpellBook:GetSpell(20271)

---@class PaladinInitial : Module
local M = Bastion.Module:New("PaladinInitial")
M:SetDisplayName("Paladin Initial", "圣骑士新手(1-10)")

M:DefineSettings({
    {
        type = "slider",
        key = "healThreshold",
        label = "Heal Threshold (%)", labelZh = "恢复技能血量阈值 (%)",
        min = 0,
        max = 100,
        default = 60,
        step = 5
    }
})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    local holyPower = Player:GetPower(9) or 0
    if holyPower >= 3 and Player:GetHP() < M:GetSetting("healThreshold") then
        if WordOfGlory:Cast(Player) then return end
    end

    if not Target:IsValid() or Target:IsDead() then return end

    if Judgment:IsInRange(Target) and Judgment:Cast(Target) then return end
    if CrusaderStrike:IsInRange(Target) and CrusaderStrike:Cast(Target) then return end
end)

Bastion:Register(M)
return M
