local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local AutoAttack = SpellBook:GetSpell(6603)
local LightningBolt = SpellBook:GetSpell(403)
local EarthShock = SpellBook:GetSpell(8042)
local HealingWave = SpellBook:GetSpell(331)
local RockbiterWeapon = SpellBook:GetSpell(8017)
local LightningShield = SpellBook:GetSpell(324)

---@class TitanShamanInitial : Module
local M = Bastion.Module:New("TitanShamanInitial")
M:SetDisplayName("Shaman Initial", "萨满祭司新手(1-10)")

M:DefineSettings({})

M:Sync(function()
    if Player:IsDead() then return end

    -- 自身 Buff 维护 (战斗外)
    if not Player:IsAffectingCombat() then
        if not Player:GetAuras():FindMy(LightningShield):IsUp() then
            if LightningShield:Cast(Player) then return end
        end
        if RockbiterWeapon:IsKnown() then
            local hasMainHandEnchant = GetWeaponEnchantInfo()
            if not hasMainHandEnchant then
                if RockbiterWeapon:Cast(Player) then return end
            end
        end
    end

    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end
    if not Player:CanSee(Target) then return end

    -- 治疗保护
    if Player:GetHealthPercent() < 40 then
        if HealingWave:Cast(Player) then return end
    end

    -- 近战平砍
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 战斗循环
    if EarthShock:IsInRange(Target) then
        if EarthShock:Cast(Target) then return end
    end

    if not Player:IsMoving() then
        if LightningBolt:IsInRange(Target) then
            if LightningBolt:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
