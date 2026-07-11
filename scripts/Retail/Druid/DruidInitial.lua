local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local MoonfireDebuff = SpellBook:GetSpell(164812)
local Moonfire = SpellBook:GetSpell(8921)
local Regrowth = SpellBook:GetSpell(8936)
local Wrath = SpellBook:GetSpell(5176)

---@class DruidInitial : Module
local M = Bastion.Module:New("DruidInitial")
M:SetDisplayName("Druid Initial", "德鲁伊新手(1-10)")

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
            if Regrowth:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if not Target:GetAuras():FindMy(MoonfireDebuff):IsUp() and Moonfire:IsInRange(Target) then
        if Moonfire:Cast(Target) then return end
    end

    if not Player:IsMoving() and Wrath:IsInRange(Target) then
        if Wrath:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
