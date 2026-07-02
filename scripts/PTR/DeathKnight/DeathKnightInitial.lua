local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local BloodBoil = SpellBook:GetSpell(50842)
local DeathStrike = SpellBook:GetSpell(49998)
local DeathCoil = SpellBook:GetSpell(47541)
local RuneStrike = SpellBook:GetSpell(316239)

---@class DeathKnightInitial : Module
local M = Bastion.Module:New("DeathKnightInitial")
M:SetDisplayName("DeathKnight Initial", "死亡骑士新手(8-10)")

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

    if Player:GetHP() < M:GetSetting("healThreshold") and DeathStrike:IsInRange(Target) then
        if DeathStrike:Cast(Target) then return end
    end

    local rp = Player:GetPower(6) or 0
    if rp >= 40 and DeathCoil:IsInRange(Target) then
        if DeathCoil:Cast(Target) then return end
    end

    if BloodBoil:Cast(Player) then return end
    if DeathStrike:IsInRange(Target) and DeathStrike:Cast(Target) then return end
    
    local runes = Player:GetPower(5) or 0
    if runes >= 1 and RuneStrike:IsInRange(Target) then
        if RuneStrike:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
