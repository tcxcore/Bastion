local _, Bastion = ...

-- 职业与专精检查：仅守护德鲁伊（专精 3）加载
local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then return end

local GuardianModule = Bastion.Module:New('GuardianDruid')
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

----------------------------------------------------------------------
-- UI 设置定义
----------------------------------------------------------------------
GuardianModule:SetDisplayName("Guardian Druid", "守护德鲁伊")
GuardianModule:DefineSettings({
    -- 防御阈值
    { type = "header", label = "Defensive Thresholds", labelZh = "防御阈值" },
    { key = "survival_hp", type = "slider", label = "Survival Instincts HP%", labelZh = "生存本能血量%", min = 10, max = 80, step = 5, default = 35 },
    { key = "frenzied_hp", type = "slider", label = "Frenzied Regeneration HP%", labelZh = "狂暴回复血量%", min = 20, max = 80, step = 5, default = 55 },
    { key = "barkskin_hp", type = "slider", label = "Barkskin HP%", labelZh = "树皮术血量%", min = 20, max = 90, step = 5, default = 65 },
    { key = "ironfur_rage", type = "slider", label = "Ironfur Min Rage", labelZh = "铁毛最低怒气", min = 20, max = 60, step = 5, default = 40 },
    -- 爆发控制
    { type = "header", label = "Burst Control", labelZh = "爆发控制" },
    { key = "auto_incarnation", type = "toggle", label = "Auto Incarnation", labelZh = "自动化身", default = true },
    { key = "auto_rage_sleeper", type = "toggle", label = "Auto Rage of the Sleeper", labelZh = "自动沉睡者之怒", default = true },
    { key = "auto_berserk", type = "toggle", label = "Auto Berserk", labelZh = "自动狂暴", default = true },
    -- AoE 设置
    { type = "header", label = "AoE Settings", labelZh = "AoE 设置" },
    { key = "aoe_count", type = "slider", label = "AoE Target Count", labelZh = "AoE 目标数量", min = 2, max = 8, step = 1, default = 3 },
    -- 打断
    { type = "header", label = "Interrupt Settings", labelZh = "打断设置" },
    { key = "auto_interrupt", type = "toggle", label = "Auto Interrupt", labelZh = "自动打断", default = true },
    { key = "auto_mass_interrupt", type = "toggle", label = "Auto Mass Interrupt (Roar)", labelZh = "自动群体打断(和谐咆哮)", default = true },
})

----------------------------------------------------------------------
-- 技能定义
----------------------------------------------------------------------
-- 核心输出
local Mangle       = SpellBook:GetSpell(33917)
local Thrash       = SpellBook:GetSpell(77758)
local Moonfire     = SpellBook:GetSpell(8921)
local Maul         = SpellBook:GetSpell(6807)
local Swipe        = SpellBook:GetSpell(213771)
local Raze         = SpellBook:GetSpell(391286)

-- 冷却技能
local LunarBeam        = SpellBook:GetSpell(204066)
local Incarnation      = SpellBook:GetSpell(102558)
local RageOfTheSleeper = SpellBook:GetSpell(200851)
local HeartOfTheWild   = SpellBook:GetSpell(319454)
local BerserkRavage    = SpellBook:GetSpell(50334)

-- 防御技能
local Ironfur               = SpellBook:GetSpell(192081)
local Barkskin              = SpellBook:GetSpell(22812)
local FrenziedRegeneration  = SpellBook:GetSpell(22842)
local SurvivalInstincts     = SpellBook:GetSpell(61336)

-- 打断 / 控制
local SkullBash         = SpellBook:GetSpell(106839)
local IncapacitatingRoar = SpellBook:GetSpell(99)

-- 形态
local BearForm   = SpellBook:GetSpell(5487)
local CatForm    = SpellBook:GetSpell(768)
local TravelForm = SpellBook:GetSpell(783)
local AutoAttack = SpellBook:GetSpell(6603)

----------------------------------------------------------------------
-- Buff / Debuff 引用
----------------------------------------------------------------------
local MoonfireDot          = SpellBook:GetSpell(164812)
local ThrashDot            = SpellBook:GetSpell(192090)
local IronfurBuff          = SpellBook:GetSpell(192081)
local ToothAndClawBuff     = SpellBook:GetSpell(135286)
local GalacticGuardianBuff = SpellBook:GetSpell(213708)
local DreamOfCenariusBuff  = SpellBook:GetSpell(372119)

----------------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------------

-- 获取周围敌人中最低的痛击层数和剩余时间
local function GetLowestThrashInfo()
    local lowestStack = 5
    local lowestDuration = 100
    local enemyCount = 0

    Bastion.UnitManager:EnumEnemies(function(unit)
        if not unit:GetOMToken() then return false end
        if unit:IsAffectingCombat() and unit:GetDistance(Player) <= 8 then
            enemyCount = enemyCount + 1
            local aura = unit:GetAuras():FindMy(ThrashDot)
            local stacks = aura:GetCount()
            local remaining = aura:GetRemainingTime()
            if stacks < lowestStack then
                lowestStack = stacks
                lowestDuration = remaining
            elseif stacks == lowestStack and remaining < lowestDuration then
                lowestDuration = remaining
            end
        end
    end)

    return lowestStack, enemyCount, lowestDuration
end

-- 铁毛当前层数
local function GetIronfurStacks()
    return Player:GetAuras():FindMy(IronfurBuff):GetCount()
end

-- 铁毛剩余时间
local function GetIronfurRemaining()
    return Player:GetAuras():FindMy(IronfurBuff):GetRemainingTime()
end

-- 是否在熊形态
local function IsInBearForm()
    return Player:GetAuras():FindMy(BearForm):IsUp()
end

----------------------------------------------------------------------
-- 主循环
----------------------------------------------------------------------
GuardianModule:Sync(function()
    -- ==================== 形态管理 ====================
    if Player:IsAffectingCombat() then
        -- 战斗中：必须熊形态
        if not IsInBearForm() then
            if BearForm:IsUsable() then
                BearForm:Cast(Player)
                return
            end
        end
    else
        -- 脱战：户外旅行形态 / 室内猫形态
        if Player:IsOutdoors() then
            if not Player:GetAuras():FindMy(TravelForm):IsUp() then
                if TravelForm:IsUsable() then
                    TravelForm:Cast(Player)
                    return
                end
            end
        else
            -- 室内：切猫形态（如果当前是旅行形态或无形态）
            if not Player:GetAuras():FindMy(CatForm):IsUp() then
                if CatForm:IsUsable() then
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

    local rage = Player:GetPower()
    local hp = Player:GetHP()
    local enemiesNearby = Player:GetEnemies(8)

    -- Bastion:Debug("Guardian", "战斗中 怒气=" .. tostring(rage) .. " 血量=" .. tostring(hp) .. " 敌人=" .. tostring(enemiesNearby) .. " 距离=" .. tostring(Target:GetDistance()))

    -- ==================== 打断 ====================
    if GuardianModule:GetSetting("auto_interrupt") then
        if Target:IsInterruptible() and Target:GetDistance() <= 13 then
            if SkullBash:IsUsable() then
                SkullBash:Cast(Target)
                return
            end
        end
    end

    -- 群体打断（仅当头骨猛击不可用时）
    if GuardianModule:GetSetting("auto_mass_interrupt") then
        if enemiesNearby > 1 and not SkullBash:IsUsable() then
            if IncapacitatingRoar:IsUsable() and Target:IsCastingOrChanneling() then
                IncapacitatingRoar:Cast(Player)
                return
            end
        end
    end

    -- ==================== 防御 ====================
    -- 生存本能：血量极低时使用
    if hp <= GuardianModule:GetSetting("survival_hp") then
        if SurvivalInstincts:IsUsable() then
            SurvivalInstincts:Cast(Player)
        end
    end

    -- 狂暴回复：中等血量时使用
    if hp <= GuardianModule:GetSetting("frenzied_hp") then
        if FrenziedRegeneration:IsUsable() then
            FrenziedRegeneration:Cast(Player)
        end
    end

    -- 树皮术：血量较低时使用
    if hp <= GuardianModule:GetSetting("barkskin_hp") then
        if Barkskin:IsUsable() then
            Barkskin:Cast(Player)
        end
    end

    -- 铁毛：保持至少 1 层，高怒气时叠层
    if rage >= GuardianModule:GetSetting("ironfur_rage") and GetIronfurStacks() < 3 then
        if Ironfur:IsUsable() then
            Ironfur:Cast(Player)
        end
    elseif rage >= 25 and GetIronfurRemaining() < 2 then
        -- 快过期时刷新，即使怒气不充裕
        if Ironfur:IsUsable() then
            Ironfur:Cast(Player)
        end
    end

    -- ==================== 爆发冷却 ====================
    if GuardianModule:GetSetting("auto_incarnation") and Incarnation:IsUsable() then
        Incarnation:Cast(Player)
    end

    if GuardianModule:GetSetting("auto_rage_sleeper") and RageOfTheSleeper:IsUsable() then
        RageOfTheSleeper:Cast(Player)
    end

    if GuardianModule:GetSetting("auto_berserk") and BerserkRavage:IsUsable() then
        BerserkRavage:Cast(Player)
    end

    if LunarBeam:IsUsable() and enemiesNearby >= 1 then
        LunarBeam:Cast(Target)
    end

    if HeartOfTheWild:IsUsable() then
        HeartOfTheWild:Cast(Player)
    end

    -- ==================== 输出循环 ====================
    local thrashStacks, _, thrashRemaining = GetLowestThrashInfo()

    if enemiesNearby >= GuardianModule:GetSetting("aoe_count") then
        -- =============== AoE 循环 ===============
        -- 1. 痛击：维持满层
        if thrashStacks < 5 or thrashRemaining < 4 then
            if Thrash:IsUsable() then
                Thrash:Cast(Player)
                return
            end
        end

        -- 2. 裂伤（Raze）：齿爪触发时
        if Player:GetAuras():FindMy(ToothAndClawBuff):IsUp() then
            if Raze:IsUsable() and Target:GetDistance() <= 8 then
                Raze:Cast(Target)
                return
            end
        end

        -- 3. 月火：银河守护者触发 或 DOT 即将消失
        if Player:GetAuras():FindMy(GalacticGuardianBuff):IsUp()
            or not Target:GetAuras():FindMy(MoonfireDot):IsUp()
            or Target:GetAuras():FindMy(MoonfireDot):GetRemainingTime() < 3 then
            if Moonfire:IsUsable() and Target:GetDistance() <= 40 then
                Moonfire:Cast(Target)
                return
            end
        end

        -- 4. 裂伤
        if Mangle:IsUsable() and Target:GetDistance() <= 5 then
            Mangle:Cast(Target)
            return
        end

        -- 5. 横扫填充
        if Swipe:IsUsable() and Target:GetDistance() <= 8 then
            Swipe:Cast(Target)
            return
        end
    else
        -- =============== 单体循环 ===============
        -- 1. 裂伤（最高优先级生成怒气）
        if Mangle:IsUsable() and Target:GetDistance() <= 5 then
            Mangle:Cast(Target)
            return
        end

        -- 2. 痛击：维持满层
        if thrashStacks < 5 or thrashRemaining < 4 then
            if Thrash:IsUsable() then
                Thrash:Cast(Player)
                return
            end
        end

        -- 3. 月火：银河守护者触发 或 DOT 维持
        if Player:GetAuras():FindMy(GalacticGuardianBuff):IsUp()
            or not Target:GetAuras():FindMy(MoonfireDot):IsUp()
            or Target:GetAuras():FindMy(MoonfireDot):GetRemainingTime() < 3 then
            if Moonfire:IsUsable() and Target:GetDistance() <= 40 then
                Moonfire:Cast(Target)
                return
            end
        end

        -- 4. 重殴：齿爪触发 或 怒气溢出
        if Player:GetAuras():FindMy(ToothAndClawBuff):IsUp() or rage >= 90 then
            if Maul:IsUsable() and Target:GetDistance() <= 5 then
                Maul:Cast(Target)
                return
            end
        end

        -- 5. 横扫填充
        if Swipe:IsUsable() and Target:GetDistance() <= 8 then
            Swipe:Cast(Target)
            return
        end
    end
end)

Bastion:Register(GuardianModule)