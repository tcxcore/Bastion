local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local AzureStrike = SpellBook:GetSpell(362969)
local LivingFlame = SpellBook:GetSpell(361469)

---@class EvokerInitial : Module
local M = Bastion.Module:New("EvokerInitial")
M:SetDisplayName("Evoker Initial", "唤魔师新手(10+)")

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
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if Player:GetHP() < M:GetSetting("healThreshold") then
        if not Player:IsMoving() then
            if LivingFlame:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() then return end

    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    if Player:IsMoving() and AzureStrike:IsInRange(Target) then
        if AzureStrike:Cast(Target) then return end
    end

    if not Player:IsMoving() and LivingFlame:IsInRange(Target) then
        if LivingFlame:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
