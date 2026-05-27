local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 恶魔学识术士战斗循环 (Demonology Warlock DPS Rotation)
-- 基于 Warcraft Logs 实战数据分析编写
-- 核心循环: 古尔丹之手(消耗碎片) -> 恶魔之箭(恶魔之核瞬发) -> 召唤恐惧猎犬 -> 暗影箭(填充)
-- 英雄天赋 (恶魔使徒): 陨灭 (极高优先级瞬发)
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义 (Spell Definitions)
-- ======================================================================

-- 基础法术
local AutoAttack       = SpellBook:GetSpell(6603)    -- 自动攻击
local ShadowBolt       = SpellBook:GetSpell(686)     -- 暗影箭 (基础填充)
local HandOfGuldan     = SpellBook:GetSpell(105174)  -- 古尔丹之手 (主力泄片)
local Demonbolt        = SpellBook:GetSpell(264178)  -- 恶魔之箭 (消耗恶魔之核)

-- 恶魔与冷却技能
local CallDreadstalkers = SpellBook:GetSpell(104316) -- 召唤恐惧猎犬 (核心CD)
local SummonDemonicTyrant = SpellBook:GetSpell(265187) -- 召唤恶魔暴君 (爆发大招)
local GrimoireFelguard = SpellBook:GetSpell(111898)  -- 魔典：小鬼领主 (天赋爆发)
local Implosion        = SpellBook:GetSpell(196277)  -- 内爆 (AOE)

-- 恶魔使徒 (Diabolist) 英雄天赋技能
local Ruin             = SpellBook:GetSpell(442750)  -- 陨灭 (瞬发高伤)

-- 防御与辅助技能
local DarkPact         = SpellBook:GetSpell(108416)  -- 黑暗契约 (护盾防暴毙)
local HealthFunnel     = SpellBook:GetSpell(755)     -- 生命通道 (治疗宠物)
local DemonicCircleTeleport = SpellBook:GetSpell(48020) -- 恶魔法阵：传送

-- ======================================================================
-- BUFF/DEBUFF ID 定义
-- ======================================================================
local DemonicCoreBuff  = SpellBook:GetSpell(264173)  -- 恶魔之核 BUFF (使恶魔之箭瞬发)
local RuinBuff         = SpellBook:GetSpell(442750)  -- 陨灭触发状态 (与技能同ID或类似，用于检测)

-- ======================================================================
-- 模块定义
-- ======================================================================

---@class WarlockDemonology : Module
local M = Bastion.Module:New("WarlockDemonology")
M:SetDisplayName("Demonology Warlock", "恶魔学识术士")

M:DefineSettings({
    { type = "header", label = "== Core Talent Requirements ==", labelZh = "== 核心推荐/必要天赋需求 ==" },
    { type = "header", label = "Required: Diabolist, Summon Demonic Tyrant", labelZh = "※ 核心必要天赋: 恶魔使徒(英雄天赋)、召唤恶魔暴君" },
    
    { type = "header", label = "== General ==", labelZh = "== 通用设置 ==" },
    {
        type = "toggle",
        key = "useCooldowns",
        label = "Use Cooldowns (Tyrant/Grimoire)",
        labelZh = "使用爆发技能 (暴君/小鬼领主)",
        default = true
    },
    {
        type = "toggle",
        key = "useAOE",
        label = "Use AOE (Implosion)",
        labelZh = "使用AOE (内爆)",
        default = true
    },
    {
        type = "slider",
        key = "aoeTargets",
        label = "AOE Target Count",
        labelZh = "AOE目标数量阈值",
        min = 2, max = 10, step = 1,
        default = 3
    },
    { type = "header", label = "== Defensive ==", labelZh = "== 防御设置 ==" },
    {
        type = "toggle",
        key = "useDarkPact",
        label = "Use Dark Pact",
        labelZh = "使用黑暗契约",
        default = true
    },
    {
        type = "slider",
        key = "darkPactHP",
        label = "Dark Pact HP (%)",
        labelZh = "黑暗契约血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 40
    },
})

-- ======================================================================
-- 辅助函数
-- ======================================================================

--- 获取恶魔之核层数
---@return number
local function GetDemonicCoreStacks()
    local aura = Player:GetAuras():FindMy(DemonicCoreBuff)
    if aura:IsUp() then
        local count = aura:GetCount()
        return count > 0 and count or 1
    end
    return 0
end

--- 检查目标附近敌人数量
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

M:Sync(function()
    -- 正在施法或引导中跳过
    if Player:IsCasting() or Player:IsChanneling() then return end

    -- 目标验证
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- 自动攻击
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- 资源获取
    local shards = Player:GetPower(7) -- Soul Shards

    -- ==================================================================
    -- 防御/自保逻辑
    -- ==================================================================

    -- 黑暗契约 (紧急护盾)
    if M:GetSetting("useDarkPact") and Player:GetHP() <= M:GetSetting("darkPactHP") then
        if DarkPact:IsKnownAndUsable() then
            if DarkPact:Cast(Player) then return end
        end
    end

    -- ==================================================================
    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    -- 所有剩余技能（除防守外）均为对 Target 施放的远程动作，
    -- 若背对目标或卡视野，则直接拦截本次 Ticker，极大节省 CPU 射线开销
    -- ==================================================================
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    -- ==================================================================
    -- 爆发与大招 (Cooldowns)
    -- ==================================================================
    if M:GetSetting("useCooldowns") then
        -- 魔典：小鬼领主 (长CD爆发，优先于暴君放出以便被暴君延长)
        if GrimoireFelguard:IsKnownAndUsable() and GrimoireFelguard:IsInRange(Target) then
            if GrimoireFelguard:Cast(Target) then return end
        end

        -- 召唤恶魔暴君 (核心爆发)
        -- 通常在场上有足够多的野生小鬼和恐惧猎犬时使用
        if SummonDemonicTyrant:IsKnownAndUsable() then
            if SummonDemonicTyrant:Cast(Target) then return end
        end
    end

    -- ==================================================================
    -- 核心输出循环 (Diabolist Demonology)
    -- ==================================================================

    -- [优先级1] 陨灭 (Ruin) - 恶魔使徒英雄天赋高亮瞬发
    -- 只要可用且在范围内，立刻打出，不占用碎片且伤害极高
    if Ruin:IsKnownAndUsable() and Ruin:IsInRange(Target) then
        if Ruin:Cast(Target) then return end
    end

    -- [优先级2] 召唤恐惧猎犬 (核心CD)
    -- 卡CD使用，保持场上恶魔数量，并为恶魔之核提供来源
    if CallDreadstalkers:IsKnownAndUsable() and CallDreadstalkers:IsInRange(Target) then
        if shards >= 2 then
            if CallDreadstalkers:Cast(Target) then return end
        end
    end

    -- [优先级3] AOE循环: 内爆 (Implosion)
    -- 当周围敌人数量达到阈值时使用内爆消耗野生小鬼
    if M:GetSetting("useAOE") and GetEnemyCount(10) >= M:GetSetting("aoeTargets") then
        if Implosion:IsKnownAndUsable() and Implosion:IsInRange(Target) then
            -- 简单逻辑：多目标时卡CD或按节奏内爆
            if Implosion:Cast(Target) then return end
        end
    end

    -- [优先级4] 恶魔之箭 (Demonbolt) - 拥有恶魔之核时瞬发
    -- 防止碎片溢出，当碎片 <= 3 且有恶魔之核时打出，瞬间回复2块碎片
    if GetDemonicCoreStacks() > 0 then
        if shards <= 3 and Demonbolt:IsKnownAndUsable() and Demonbolt:IsInRange(Target) then
            if Demonbolt:Cast(Target) then return end
        end
    end

    -- [优先级5] 古尔丹之手 (Hand of Gul'dan) - 主力泄片
    -- 当碎片达到或超过3块时，打出满星古尔丹之手召唤最多的小鬼
    -- 如果碎片即将溢出(5片)且恶魔之核可用，也优先打出古尔丹之手
    if shards >= 3 then
        if HandOfGuldan:IsKnownAndUsable() and HandOfGuldan:IsInRange(Target) then
            if HandOfGuldan:Cast(Target) then return end
        end
    end

    -- ==================================================================
    -- 移动填充
    -- ==================================================================
    if Player:IsMoving() then
        -- 移动中如果有恶魔之核，可以使用瞬发恶魔之箭
        if GetDemonicCoreStacks() > 0 and Demonbolt:IsKnownAndUsable() and Demonbolt:IsInRange(Target) then
            if Demonbolt:Cast(Target) then return end
        end
        return
    end

    -- ==================================================================
    -- 基础填充法术
    -- ==================================================================
    
    -- 暗影箭 (Shadow Bolt) - 在没有其他高优先级技能，且需要产生碎片时搓
    if ShadowBolt:IsKnownAndUsable() and ShadowBolt:IsInRange(Target) then
        if ShadowBolt:Cast(Target) then return end
    end

end)

Bastion:Register(M)
return M
