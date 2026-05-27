local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 冰霜法师战斗循环 (Frost Mage DPS Rotation)
-- 基于 Warcraft Logs 冰法输出手法分析编写
-- 核心循环: 寒冰箭填充 -> 冰枪术消耗触发 -> 冰霜射线引导 -> 冰风暴AOE
--           冰川尖刺大招 -> 寒冰宝珠CD技能 -> 冰冷血脉爆发
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义 (Spell Definitions)
-- ======================================================================

-- 基础法术
local AutoAttack    = SpellBook:GetSpell(6603)    -- 自动攻击
local Frostbolt     = SpellBook:GetSpell(116)     -- 寒冰箭 (填充法术)
local IceLance      = SpellBook:GetSpell(30455)   -- 冰枪术 (即时/冰手指消耗)
local Flurry        = SpellBook:GetSpell(44614)   -- 冰风暴/冰霜碎裂 (消耗碎裂BUFF)

-- 引导/AOE 法术
local RayOfFrost    = SpellBook:GetSpell(205021)  -- 冰霜射线 (引导法术)
local FrozenOrb     = SpellBook:GetSpell(84714)   -- 寒冰宝珠
local Blizzard      = SpellBook:GetSpell(190356)  -- 暴风雪
local CometStorm    = SpellBook:GetSpell(153595)  -- 冰风暴 (天赋)
local GlacialSpike  = SpellBook:GetSpell(199786)  -- 冰川尖刺 (天赋, 5层寒冰箭)
local IceNova       = SpellBook:GetSpell(157997)  -- 冰霜新星 (预留: 天赋可选)
local ConeOfCold    = SpellBook:GetSpell(120)     -- 冰锥术

-- 爆发/冷却技能
local IcyVeins      = SpellBook:GetSpell(12472)   -- 冰冷血脉 (主要爆发CD)
local SummonWaterElemental = SpellBook:GetSpell(31687)  -- 召唤水元素 (预留: 水元素天赋)
local Freeze         = SpellBook:GetSpell(33395)   -- 冰冻 (水元素技能, 预留)

-- 防御/工具技能
local IceBarrier    = SpellBook:GetSpell(11426)   -- 冰霜护体
local IceBlock      = SpellBook:GetSpell(45438)   -- 寒冰屏障
local MirrorImage   = SpellBook:GetSpell(55342)   -- 镜像
local ShiftingPower = SpellBook:GetSpell(382440)  -- 变换之力 (引导, 减CD)

-- 工具/控制技能 (来自施法CSV补充)
local Counterspell  = SpellBook:GetSpell(2139)    -- 法术反制 (打断)
local AlterTime     = SpellBook:GetSpell(342245)  -- 操控时间 (位置/血量回溯)
local TimeWarp      = SpellBook:GetSpell(80353)   -- 时间扭曲 (嗜血/英勇)
local IceCold       = SpellBook:GetSpell(378760)  -- 深寒凝冰 (被动天赋，修改寒冰屏障)
local Supernova     = SpellBook:GetSpell(157980)  -- 超级新星 (控制/AOE)
local Blink         = SpellBook:GetSpell(1953)    -- 闪光术 (预留: 位移技能手动使用)
local IceFloes      = SpellBook:GetSpell(108839)  -- 寒冰流 (移动施法, 天赋)

-- ======================================================================
-- BUFF/DEBUFF ID 定义
-- ======================================================================
local FingersOfFrostBuff = SpellBook:GetSpell(44544)   -- 冰手指 BUFF
local BrainFreezeBuff    = SpellBook:GetSpell(190446)  -- 碎裂 / 急冻大脑 BUFF
local IciclesBuff        = SpellBook:GetSpell(205473)  -- 冰锥层数 BUFF (冰川尖刺前置)
local IcyVeinsBuff       = IcyVeins                   -- 冰冷血脉 BUFF (与技能共享SpellID)
local GlacialSpikebuff   = SpellBook:GetSpell(1222865) -- 冰川尖刺 BUFF (自定义)
local WintersChillDebuff = SpellBook:GetSpell(228358)  -- 凛冬之寒 DEBUFF (碎裂后目标上)
local FreezingDebuff     = SpellBook:GetSpell(1221389) -- 冻结 DEBUFF (碎裂被动产生)
local FreezingWindsBuff  = SpellBook:GetSpell(382106)  -- 凝冻之风 BUFF (预留: 天赋追踪)
local DeathsChillBuff    = SpellBook:GetSpell(454391)  -- 死亡之寒 BUFF (预留: 天赋追踪)
local AlterTimeBuff      = SpellBook:GetSpell(342246)  -- 操控时间激活 BUFF
local IceFloesBuff       = SpellBook:GetSpell(108839)  -- 寒冰流 BUFF
local TemporalDisplacement = SpellBook:GetSpell(80354) -- 时间位移 (时间扭曲疲劳DEBUFF)

-- ======================================================================
-- 模块定义
-- ======================================================================

---@class MageFrost : Module
local M = Bastion.Module:New("MageFrost")
M:SetDisplayName("Frost Mage", "冰霜法师")

M:DefineSettings({
    { type = "header", label = "== Core Talent Requirements ==", labelZh = "== 核心推荐/必要天赋需求 ==" },
    { type = "header", label = "Required: Spellslinger, Ray of Frost, Glacial Spike", labelZh = "※ 核心必要天赋: 疾咒师(英雄天赋)、冰霜射线、冰川尖刺" },
    { type = "header", label = "Optional: Ice Cold, Supernova", labelZh = "※ 可选辅助天赋: 深寒凝冰、超级新星" },

    { type = "header", label = "== General ==", labelZh = "== 通用设置 ==" },
    {
        type = "toggle",
        key = "useCooldowns",
        label = "Use Cooldowns",
        labelZh = "使用爆发技能",
        default = true
    },
    {
        type = "toggle",
        key = "useAOE",
        label = "Use AOE",
        labelZh = "使用AOE技能",
        default = true
    },
    {
        type = "slider",
        key = "aoeTargets",
        label = "AOE Target Count",
        labelZh = "AOE目标数量",
        min = 2, max = 10, step = 1,
        default = 3
    },
    { type = "header", label = "== Defensive ==", labelZh = "== 防御设置 ==" },
    {
        type = "toggle",
        key = "useIceBarrier",
        label = "Use Ice Barrier",
        labelZh = "使用冰霜护体",
        default = true
    },
    {
        type = "slider",
        key = "iceBarrierHP",
        label = "Ice Barrier HP (%)",
        labelZh = "冰霜护体血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 80
    },
    {
        type = "toggle",
        key = "useIceBlock",
        label = "Use Ice Block / Ice Cold",
        labelZh = "使用寒冰屏障 / 深寒凝冰",
        default = true
    },
    {
        type = "slider",
        key = "iceBlockHP",
        label = "Ice Block/Cold HP (%)",
        labelZh = "冰箱/深寒血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 25
    },
    {
        type = "toggle",
        key = "useSupernova",
        label = "Use Supernova (AOE)",
        labelZh = "使用超级新星(控制/AOE)",
        default = true
    },
    { type = "header", label = "== Interrupt ==", labelZh = "== 打断设置 ==" },
    {
        type = "toggle",
        key = "useInterrupt",
        label = "Use Counterspell",
        labelZh = "使用法术反制(打断)",
        default = true
    },
    {
        type = "slider",
        key = "interruptPercent",
        label = "Interrupt at Cast (%)",
        labelZh = "打断施法进度 (%)",
        min = 10, max = 90, step = 5,
        default = 50
    },
    { type = "header", label = "== Utility ==", labelZh = "== 工具设置 ==" },
    {
        type = "toggle",
        key = "useTimeWarp",
        label = "Use Time Warp",
        labelZh = "使用时间扭曲(嗜血)",
        default = false
    },
    {
        type = "toggle",
        key = "useAlterTime",
        label = "Use Alter Time",
        labelZh = "使用操控时间(自保)",
        default = false
    },
    {
        type = "slider",
        key = "alterTimeHP",
        label = "Alter Time HP (%)",
        labelZh = "操控时间血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 30
    },
    {
        type = "toggle",
        key = "useIceFloes",
        label = "Use Ice Floes",
        labelZh = "使用寒冰流(移动施法)",
        default = true
    },
})

-- ======================================================================
-- 辅助函数
-- ======================================================================

--- 获取冰手指层数
---@return number
local function GetFingersOfFrostStacks()
    local aura = Player:GetAuras():FindMy(FingersOfFrostBuff)
    if aura:IsUp() then
        local count = aura:GetCount()
        return count > 0 and count or 1
    end
    return 0
end

--- 检查是否有碎裂(急冻大脑) BUFF
---@return boolean
local function HasBrainFreeze()
    return Player:GetAuras():FindMy(BrainFreezeBuff):IsUp()
end

--- 获取冰锥层数 (冰川尖刺前置)
---@return number
local function GetIciclesCount()
    local aura = Player:GetAuras():FindMy(IciclesBuff)
    if aura:IsUp() then
        return aura:GetCount()
    end
    return 0
end

--- 检查是否在冰冷血脉中
---@return boolean
local function HasIcyVeins()
    return Player:GetAuras():FindMy(IcyVeinsBuff):IsUp()
end

--- 获取冻结(1221389)剩余层数
---@return number
local function GetFreezingStacks()
    local aura = Target:GetAuras():FindAny(FreezingDebuff)
    if aura:IsUp() then
        return aura:GetCount()
    end
    return 0
end

--- 检查目标附近敌人数量 (以目标为中心, AOE 落点判断)
--- 使用 EnumUnits (遍历所有敌方单位) 而非 EnumEnemies (仅遍历 activeEnemies)
--- activeEnemies 需要 InCombatOdds>80, 可能漏掉大量怪物
---@param range number
---@return number
local function GetEnemyCount(range)
    range = range or 10
    local count = 0
    Bastion.UnitManager:EnumUnits(function(unit)
        if unit:IsAlive() and unit:IsEnemy() and Target:GetDistance(unit) <= range then
            count = count + 1
        end
        return false
    end)
    return count
end

-- ======================================================================
-- 战斗循环主体
-- ======================================================================

    -- ==================================================================
    -- 1. 自身防御与自保逻辑 (无需任何目标，最高优先级自救)
    -- ==================================================================

    -- 寒冰屏障 / 深寒凝冰 (紧急保命)
    if M:GetSetting("useIceBlock") and Player:GetHP() <= M:GetSetting("iceBlockHP") then
        if IceBlock:IsKnownAndUsable() then
            if IceBlock:Cast(Player) then return end
        end
    end

    -- 操控时间 (血量低于阈值时自动回溯)
    if M:GetSetting("useAlterTime") then
        local alterTimeAura = Player:GetAuras():FindMy(AlterTimeBuff)
        if alterTimeAura:IsUp() and Player:GetHP() <= M:GetSetting("alterTimeHP") then
            if AlterTime:IsKnownAndUsable() then
                if AlterTime:Cast(Player) then return end
            end
        end
    end

    -- 冰霜护体 (主动减伤)
    if M:GetSetting("useIceBarrier") and Player:GetHP() <= M:GetSetting("iceBarrierHP") then
        local iceBarrierAura = Player:GetAuras():FindMy(IceBarrier)
        if not iceBarrierAura:IsUp() and IceBarrier:IsKnownAndUsable() then
            if IceBarrier:Cast(Player) then return end
        end
    end

    -- 目标验证
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- ==================================================================
    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    -- 目标无效、不在视野或背对目标时直接返回，节省后续所有 CPU 射线开销
    -- ==================================================================
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    -- 自动攻击
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- ==================================================================
    -- 打断逻辑 (法术反制)
    -- ==================================================================
    if M:GetSetting("useInterrupt") and Counterspell:IsKnownAndUsable() then
        if Target:IsInterruptibleAt(M:GetSetting("interruptPercent"), false) then
            if Counterspell:IsInRange(Target) then
                if Counterspell:Cast(Target) then return end
            end
        end
    end

    -- ==================================================================
    -- 爆发冷却技能 (Cooldowns)
    -- ==================================================================
    local useCDs = M:GetSetting("useCooldowns")
    local useAOE = M:GetSetting("useAOE")
    local enemyCount = GetEnemyCount(10)

    -- 冰冷血脉 (主爆发)
    if useCDs and IcyVeins:IsKnownAndUsable() then
        if IcyVeins:Cast(Player) then return end
    end

    -- 时间扭曲 (嗜血, 施法CSV中使用1次, 通常开场配合冰冷血脉)
    if useCDs and M:GetSetting("useTimeWarp") and TimeWarp:IsKnownAndUsable() then
        -- 检查是否已有时间位移疲劳DEBUFF (避免重复使用)
        local temporalDebuff = Player:GetAuras():FindAny(TemporalDisplacement)
        if not temporalDebuff:IsUp() then
            if TimeWarp:Cast(Player) then return end
        end
    end

    -- 镜像 (跟随爆发使用)
    if useCDs and MirrorImage:IsKnownAndUsable() then
        if MirrorImage:Cast(Player) then return end
    end

    -- ==================================================================
    -- 核心输出循环
    -- ==================================================================

    -- [优先级1] 冰川尖刺 - 必须拥有大冰刺高亮Buff(5层冰锥)时才释放
    if GetIciclesCount() >= 5 then
        if not Player:IsMoving() and GlacialSpike:IsKnownAndUsable() and GlacialSpike:IsInRange(Target) then
            if GlacialSpike:Cast(Target) then return end
        end
    end

    -- [优先级2] 碎裂(Flurry) - 有急冻大脑时消耗
    -- 碎裂是最高伤害来源(40%)，急冻大脑BUFF必须尽快消耗
    -- (注意：在当前版本中不再施加深冬之寒，而是叠加冻结层数)
    if HasBrainFreeze() and Flurry:IsKnownAndUsable() then
        if Flurry:IsInRange(Target) then
            if Flurry:Cast(Target) then return end
        end
    end

    -- [优先级3] 冰霜射线 - 卡CD引导
    -- 法术降生流派的核心输出技能，由于会提供可观的裂片和伤害，优先级极高
    if not Player:IsMoving() and RayOfFrost:IsKnownAndUsable() and RayOfFrost:IsInRange(Target) then
        if RayOfFrost:Cast(Target) then return end
    end

    -- [优先级4] 冰枪术 - 核心输出条件
    -- 触发条件: 玩家有冰手指 / 目标有5层及以上冻结(1221389)
    if GetFingersOfFrostStacks() > 0 or GetFreezingStacks() >= 5 then
        if IceLance:IsKnownAndUsable() and IceLance:IsInRange(Target) then
            if IceLance:Cast(Target) then return end
        end
    end

    -- [优先级5] 寒冰宝珠 - CD好了就放
    -- 寒冰宝珠滚过去会持续触发冰手指和碎裂
    if FrozenOrb:IsKnownAndUsable() and FrozenOrb:IsInRange(Target) then
        if FrozenOrb:Cast(Target) then return end
    end

    -- [优先级6] 冰风暴 - CD好了就放 (单体和AOE都用)
    -- 冰风暴是高伤害天赋技能，单体也有不错收益
    if CometStorm:IsKnownAndUsable() and CometStorm:IsInRange(Target) then
        if CometStorm:Cast(Target) then return end
    end

    -- [优先级7] 变换之力 - 用于减少技能CD
    if not Player:IsMoving() and ShiftingPower:IsKnown() then
        if ShiftingPower:IsKnownAndUsable() then
            -- 仅在主要CD都在冷却中时使用
            local orbOnCD = FrozenOrb:IsOnCooldown()
            local cometOnCD = not CometStorm:IsKnown() or CometStorm:IsOnCooldown()
            local rayOnCD = not RayOfFrost:IsKnown() or RayOfFrost:IsOnCooldown()
            if orbOnCD and cometOnCD and rayOnCD then
                if ShiftingPower:Cast(Player) then return end
            end
        end
    end

    -- ==================================================================
    -- AOE 循环 (多目标 >= N 个敌人时, 提前到单体填充之前)
    -- ==================================================================
    if useAOE and enemyCount >= M:GetSetting("aoeTargets") then
        -- 暴风雪 (大面积AOE, 多目标时优先级最高)
        if not Player:IsMoving() and Blizzard:IsKnownAndUsable() then
            if Blizzard:Cast(Target) then
                -- 暴风雪是AOE落点技能，需要点击地面
                Blizzard:Click(Target:GetPosition())
                return
            end
        end

        -- 冰锥术 (近战范围AOE)
        if ConeOfCold:IsKnownAndUsable() and Player:InMelee(Target) then
            if ConeOfCold:Cast(Target) then return end
        end

        -- 超级新星 (AOE/打断补足)
        if M:GetSetting("useSupernova") and Supernova:IsKnownAndUsable() and Supernova:IsInRange(Target) then
            if Supernova:Cast(Target) then return end
        end
    end

    -- ==================================================================
    -- 移动填充
    -- ==================================================================

    -- 移动时先尝试激活寒冰流 (移动中施法BUFF)
    if Player:IsMoving() then
        -- 寒冰流: 允许移动中施放下一个法术 (天赋技能)
        if M:GetSetting("useIceFloes") and IceFloes:IsKnown() then
            local iceFloesAura = Player:GetAuras():FindMy(IceFloesBuff)
            if not iceFloesAura:IsUp() and IceFloes:IsKnownAndUsable() then
                if IceFloes:Cast(Player) then return end
            end
        end

        -- 移动时使用冰枪术填充 (即使没有BUFF)
        if IceLance:IsKnownAndUsable() and IceLance:IsInRange(Target) then
            if IceLance:Cast(Target) then return end
        end
        return
    end

    -- ==================================================================
    -- 基础填充法术，没有其他更高优先级操作时使用
    if not Player:IsMoving() then
        if Frostbolt:IsKnownAndUsable() and Frostbolt:IsInRange(Target) then
            if Frostbolt:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
