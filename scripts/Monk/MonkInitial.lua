local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local Vivify = SpellBook:GetSpell(116670)
local BlackoutKick = SpellBook:GetSpell(100784)
local TigerPalm = SpellBook:GetSpell(100780)

---@class MonkInitial : Module
local M = Bastion.Module:New("MonkInitial")
M:SetDisplayName("Monk Initial", "武僧新手(1-10)")

M:DefineSettings({
    {
        type = "slider",
        key = "healThreshold",
        label = "Heal Threshold (%)", labelZh = "恢复技能血量阈值 (%)",
        min = 0,
        max = 100,
        default = 40,
        step = 5
    }
})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if Player:GetHP() < M:GetSetting("healThreshold") then
        if not Player:IsMoving() then
            if Vivify:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:IsFacing(Target) then Player:Face(Target) end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    local chi = Player:GetPower(12) or 0
    if chi >= 1 and BlackoutKick:IsInRange(Target) then
        if BlackoutKick:Cast(Target) then return end
    end

    if TigerPalm:IsInRange(Target) and TigerPalm:Cast(Target) then return end
end)

Bastion:Register(M)
return M
