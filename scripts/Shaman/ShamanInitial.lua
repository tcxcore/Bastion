local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local HealingSurge = SpellBook:GetSpell(8004)
local LightningBolt = SpellBook:GetSpell(188196)
local FlameShock = SpellBook:GetSpell(188389)

---@class ShamanInitial : Module
local M = Bastion.Module:New("ShamanInitial")
M:SetDisplayName("Shaman Initial", "萨满祭司新手(1-10)")

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
            if HealingSurge:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:IsFacing(Target) then Player:Face(Target) end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if not Target:GetAuras():FindMy(FlameShock):IsUp() and FlameShock:IsInRange(Target) then
        if FlameShock:Cast(Target) then return end
    end

    if not Player:IsMoving() and LightningBolt:IsInRange(Target) then
        if LightningBolt:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
