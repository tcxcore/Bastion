local _, Bastion = ...

-- 职业与专精检查：仅野性德鲁伊加载
local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then return end

local FeralModule = Bastion.Module:New('FeralDruid')
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

----------------------------------------------------------------------
-- UI 设置定义
----------------------------------------------------------------------
FeralModule:SetDisplayName("Feral Druid", "野性德鲁伊")
FeralModule:DefineSettings({
    -- 防御阈值
    { type = "header", label = "Defensive Thresholds", labelZh = "防御阈值" },
    { key = "survival_hp", type = "slider", label = "Survival Instincts HP%", labelZh = "生存本能血量%", min = 10, max = 80, step = 5, default = 35 },
    { key = "barkskin_hp", type = "slider", label = "Barkskin HP%", labelZh = "树皮术血量%", min = 20, max = 90, step = 5, default = 65 },
    -- 爆发控制
    { type = "header", label = "Burst Control", labelZh = "爆发控制" },
    { key = "auto_berserk", type = "toggle", label = "Auto Berserk", labelZh = "自动狂暴", default = true },
    { key = "auto_convoke", type = "toggle", label = "Auto Convoke the Spirits", labelZh = "自动万灵之召", default = true },
    { key = "tigers_fury_energy", type = "slider", label = "Tiger's Fury Energy Threshold", labelZh = "猛虎之怒能量阈值", min = 10, max = 70, step = 5, default = 40 },
    -- AoE 设置
    { type = "header", label = "AoE Settings", labelZh = "AoE 设置" },
    { key = "aoe_count", type = "slider", label = "AoE Target Count", labelZh = "AoE 目标数量", min = 2, max = 8, step = 1, default = 3 },
    -- 打断
    { type = "header", label = "Interrupt Settings", labelZh = "打断设置" },
    { key = "auto_interrupt", type = "toggle", label = "Auto Interrupt", labelZh = "自动打断", default = true },
})

----------------------------------------------------------------------
-- 技能定义
----------------------------------------------------------------------
local AutoAttack = SpellBook:GetSpell(6603)

-- 形态
local BearForm   = SpellBook:GetSpell(5487)
local CatForm    = SpellBook:GetSpell(768)
local TravelForm = SpellBook:GetSpell(783)

-- 连击点生成技
local Rake       = SpellBook:GetSpell(1822)    -- 斜掠
local Shred      = SpellBook:GetSpell(5221)   -- 撕碎
local Thrash     = SpellBook:GetSpell(106830) -- 痛击
local Swipe      = SpellBook:GetSpell(106785) -- 横扫
local BrutalSlash= SpellBook:GetSpell(202028) -- 野蛮挥砍

-- 连击点消耗技 (终结技)
local Rip           = SpellBook:GetSpell(1079)   -- 割裂
local FerociousBite = SpellBook:GetSpell(22568)  -- 凶猛撕咬
local PrimalWrath   = SpellBook:GetSpell(285381) -- 原始之怒

-- 冷却与爆发
local TigersFury    = SpellBook:GetSpell(5217)   -- 猛虎之怒
local Berserk       = SpellBook:GetSpell(106951) -- 狂暴
local FeralFrenzy   = SpellBook:GetSpell(274837) -- 野性狂乱
local Convoke       = SpellBook:GetSpell(391528) -- 万灵之召

-- 防御与打断
local SkullBash         = SpellBook:GetSpell(106839) -- 头骨猛击
local SurvivalInstincts = SpellBook:GetSpell(61336)  -- 生存本能
local Barkskin          = SpellBook:GetSpell(22812)  -- 树皮术

----------------------------------------------------------------------
-- Buff / Debuff 引用
----------------------------------------------------------------------
local RakeDot       = SpellBook:GetSpell(155722)
local RipDot        = SpellBook:GetSpell(1079)
local ThrashDot     = SpellBook:GetSpell(106830)
local Clearcasting  = SpellBook:GetSpell(135700) -- 清晰预兆

----------------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------------
-- 判断 DOT 是否需要刷新（Pandemic < 30% 基础时间）
local function NeedsRefresh(aura, baseDuration)
    if not aura or not aura:IsUp() then return true end
    return aura:GetRemainingTime() < (baseDuration * 0.3)
end

-- 获取最低痛击层数及是否需要刷新
local function GetThrashInfo()
    local needsThrash = false
    local enemyCount = 0

    Bastion.UnitManager:EnumEnemies(function(unit)
        if not unit:GetOMToken() then return false end
        -- 使用 8 码距离判断 AOE 范围
        if unit:IsAffectingCombat() and Player:GetDistance(unit) <= 8 then
            enemyCount = enemyCount + 1
            local aura = unit:GetAuras():FindMy(ThrashDot)
            if NeedsRefresh(aura, 15) then
                needsThrash = true
            end
        end
    end)
    return needsThrash, enemyCount
end

-- 获取是否需要群体割裂 (原始之怒)
local function NeedsPrimalWrath()
    local needsPW = false
    local enemyCount = 0

    Bastion.UnitManager:EnumEnemies(function(unit)
        if not unit:GetOMToken() then return false end
        if unit:IsAffectingCombat() and Player:GetDistance(unit) <= 8 then
            enemyCount = enemyCount + 1
            local aura = unit:GetAuras():FindMy(RipDot)
            if NeedsRefresh(aura, 24) then
                needsPW = true
            end
        end
    end)
    return needsPW, enemyCount
end

-- 是否在猫形态
local function IsInCatForm()
    return Player:GetAuras():FindMy(CatForm):IsUp()
end

----------------------------------------------------------------------
-- 主循环
----------------------------------------------------------------------
FeralModule:Sync(function()
    -- ==================== 形态管理 ====================
    if Player:IsAffectingCombat() then
        if not IsInCatForm() then
            if CatForm:Castable() then
                CatForm:Cast(Player)
                return
            end
        end
        -- 在战斗中，如果仍未切成猫形态（比如卡GCD），则不执行任何攻击动作
        if not IsInCatForm() then return end
    else
        -- 脱战形态：户外旅行 / 室内猫
        if Player:IsOutdoors() then
            if not Player:GetAuras():FindMy(TravelForm):IsUp() then
                if TravelForm:Castable() then
                    TravelForm:Cast(Player)
                    return
                end
            end
        else
            if not IsInCatForm() then
                if CatForm:Castable() then
                    CatForm:Cast(Player)
                    return
                end
            end
        end
        return -- 脱战不执行后续战斗逻辑
    end

    -- ==================== 目标有效性检查 ====================
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 确保自动攻击开启
    if not AutoAttack:IsCurrent() then
        AutoAttack:Cast(Target)
    end

    local energy = Player:GetPower(3) -- 3 = 能量
    local cp = Player:GetComboPoints()
    local hp = Player:GetHP()
    local enemiesNearby = Player:GetEnemies(8)

    -- ==================== 防御与打断 ====================
    if FeralModule:GetSetting("auto_interrupt") then
        if Target:IsInterruptible() and SkullBash:IsInRange(Target) then
            if SkullBash:Castable() then
                if SkullBash:Cast(Target) then return end
            end
        end
    end

    if hp <= FeralModule:GetSetting("survival_hp") and SurvivalInstincts:Castable() then
        SurvivalInstincts:Cast(Player)
    end
    if hp <= FeralModule:GetSetting("barkskin_hp") and Barkskin:Castable() then
        Barkskin:Cast(Player)
    end

    -- ==================== 爆发与冷却 ====================
    if energy < FeralModule:GetSetting("tigers_fury_energy") and TigersFury:IsUsable() then
        TigersFury:Cast(Player)
    end

    if FeralModule:GetSetting("auto_berserk") and Berserk:IsUsable() and Target:GetDistance() <= 8 then
        Berserk:Cast(Player)
    end

    if cp <= 1 and FeralFrenzy:IsUsable() and Target:GetDistance() <= 8 then
        if Player:GetAuras():FindMy(TigersFury):IsUp() then
            if FeralFrenzy:Cast(Target) then return end
        end
    end

    if FeralModule:GetSetting("auto_convoke") and energy < FeralModule:GetSetting("tigers_fury_energy") and cp <= 3 and Convoke:IsUsable() and Target:GetDistance() <= 8 then
        if Convoke:Cast(Player) then return end
    end

    -- ==================== 输出循环 ====================
    local isClearcasting = Player:GetAuras():FindMy(Clearcasting):IsUp()

    if enemiesNearby >= FeralModule:GetSetting("aoe_count") then
        -- =============== AoE 循环 ===============
        local needsPW, _ = NeedsPrimalWrath()
        local needsThrash, _ = GetThrashInfo()

        if cp >= 5 then
            if needsPW and PrimalWrath:IsKnown() and PrimalWrath:IsUsable() and Target:GetDistance() <= 8 then
                if PrimalWrath:Cast(Player) then return end
            end
            
            -- AOE 兜底终结技（没学原始之怒时）
            local ripAura = Target:GetAuras():FindMy(RipDot)
            local targetHP = Target:GetHP() or 100
            if targetHP > 25 and NeedsRefresh(ripAura, 24) and Rip:IsUsable() and Rip:IsInRange(Target) then
                if Rip:Cast(Target) then return end
            end
            
            if FerociousBite:IsUsable() and FerociousBite:IsInRange(Target) and energy >= 50 then
                if FerociousBite:Cast(Target) then return end
            end
            
            if energy < 50 and not isClearcasting then
                return
            end
            return 
        end

        if needsThrash and Thrash:IsUsable() and Target:GetDistance() <= 8 then
            if Thrash:Cast(Player) then return end
        end

        local rakeAura = Target:GetAuras():FindMy(RakeDot)
        if NeedsRefresh(rakeAura, 15) and Rake:IsUsable() and Rake:IsInRange(Target) then
            if Rake:Cast(Target) then return end
        end

        if BrutalSlash:IsKnown() and BrutalSlash:IsUsable() and (BrutalSlash:GetCharges() or 0) > 0 and Target:GetDistance() <= 8 then
            if BrutalSlash:Cast(Player) then return end
        end
        if Swipe:IsKnown() and Swipe:IsUsable() and Target:GetDistance() <= 8 then
            if Swipe:Cast(Player) then return end
        end
        
        -- AOE 兜底填充技：如果连横扫都没学，就老老实实打撕碎
        if Shred:IsUsable() and Shred:IsInRange(Target) then
            if Shred:Cast(Target) then return end
        end

    else
        -- =============== 单体循环 ===============
        -- 最高优先级：终结技（满星）
        if cp >= 5 then
            local ripAura = Target:GetAuras():FindMy(RipDot)
            local targetHP = Target:GetHP() or 100
            
            if targetHP > 25 and NeedsRefresh(ripAura, 24) and Rip:IsUsable() and Rip:IsInRange(Target) then
                if Rip:Cast(Target) then return end
            end
            
            if FerociousBite:IsUsable() and FerociousBite:IsInRange(Target) and energy >= 50 then
                if FerociousBite:Cast(Target) then return end
            end
            if energy < 50 and not isClearcasting then
                return
            end
        end

        -- 次优先级：维持斜掠 DOT
        local rakeAura = Target:GetAuras():FindMy(RakeDot)
        if NeedsRefresh(rakeAura, 15) and Rake:IsUsable() and Rake:IsInRange(Target) then
            if Rake:Cast(Target) then return end
        end

        local thrashAura = Target:GetAuras():FindMy(ThrashDot)
        if NeedsRefresh(thrashAura, 15) and isClearcasting and Thrash:IsUsable() and Target:GetDistance() <= 8 then
            if Thrash:Cast(Player) then return end
        end

        if isClearcasting and Shred:IsUsable() and Shred:IsInRange(Target) then
            if Shred:Cast(Target) then return end
        end

        if BrutalSlash:IsKnown() and BrutalSlash:IsUsable() and (BrutalSlash:GetCharges() or 0) > 0 and Target:GetDistance() <= 8 then
            if BrutalSlash:Cast(Player) then return end
        end

        if Shred:IsUsable() and Shred:IsInRange(Target) then
            if Shred:Cast(Target) then return end
        end
    end

end)

Bastion:Register(FeralModule)
