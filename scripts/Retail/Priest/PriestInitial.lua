local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local FlashHeal = SpellBook:GetSpell(2061)
local ShadowWordPain = SpellBook:GetSpell(589)
local Smite = SpellBook:GetSpell(585)

---@class PriestInitial : Module
local M = Bastion.Module:New("PriestInitial")
M:SetDisplayName("Priest Initial", "牧师新手(1-10)")

M:DefineSettings({
    {
        type = "slider",
        key = "healThreshold",
        label = "Heal Threshold (%)", labelZh = "恢复技能血量阈值 (%)",
        min = 0,
        max = 100,
        default = 50,
        step = 5
    }
})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if Player:GetHP() < M:GetSetting("healThreshold") then
        if not Player:IsMoving() then
            if FlashHeal:Cast(Player) then return end
        end
    end

    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    if Target:IsEnemy() and not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    if not Target:GetAuras():FindMy(ShadowWordPain):IsUp() and ShadowWordPain:IsInRange(Target) then
        if ShadowWordPain:Cast(Target) then return end
    end

    if not Player:IsMoving() and Smite:IsInRange(Target) then
        if Smite:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
