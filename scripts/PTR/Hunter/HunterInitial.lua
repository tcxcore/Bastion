local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoShot = SpellBook:GetSpell(75)
local KillCommand = SpellBook:GetSpell(34026)
local MendPet = SpellBook:GetSpell(136)
local ArcaneShot = SpellBook:GetSpell(185358)
local SteadyShot = SpellBook:GetSpell(56641)

---@class HunterInitial : Module
local M = Bastion.Module:New("HunterInitial")
M:SetDisplayName("Hunter Initial", "猎人新手(1-10)")

M:DefineSettings({
    {
        type = "slider",
        key = "healThreshold",
        label = "Heal Threshold (%)", labelZh = "恢复技能血量阈值 (%)",
        min = 0,
        max = 100,
        default = 70,
        step = 5
    }
})

M:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    if not AutoShot:IsCurrent() then
        AutoShot:Cast(Target)
    end

    local Pet = Bastion.UnitManager:Get('pet')
    if Pet and Pet:IsValid() and not Pet:IsDead() then
        if Pet:GetHP() < M:GetSetting("healThreshold") then
            if not Pet:GetAuras():FindMy(MendPet):IsUp() then
                if MendPet:Cast(Player) then return end
            end
        end
    end

    if not Target:IsValid() or Target:IsDead() then return end

    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    if KillCommand:IsInRange(Target) then
        if KillCommand:Cast(Target) then return end
    end
    
    local power = Player:GetPower(2) or 0
    if power > 40 and ArcaneShot:IsInRange(Target) then
        if ArcaneShot:Cast(Target) then return end
    end

    if not Player:IsMoving() and SteadyShot:IsInRange(Target) then
        if SteadyShot:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
