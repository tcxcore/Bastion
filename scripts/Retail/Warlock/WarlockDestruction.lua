--- 毁灭术 (Destruction)
--- 核心流派：恶魔使徒 (Diabolist)

local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

local M = Bastion.Module:New("WarlockDestruction")
M:SetDisplayName("Destruction Warlock", "毁灭术")

-- ======================================================================
-- 技能定义
-- ======================================================================

local AutoAttack      = SpellBook:GetSpell(6603)    -- 自动攻击
local Incinerate      = SpellBook:GetSpell(29722)   -- 烧尽 (填充)
local Immolate        = SpellBook:GetSpell(348)     -- 献祭 (DoT)
local Conflagrate     = SpellBook:GetSpell(17962)   -- 燃烧 (攒片/爆燃)
local ChaosBolt       = SpellBook:GetSpell(116858)  -- 混乱之箭 (单体泄片)
local RainOfFire      = SpellBook:GetSpell(104220)  -- 火焰之雨 (AOE泄片)

-- 天赋技能
local SoulFire        = SpellBook:GetSpell(6353)    -- 灵魂之火
local Shadowburn      = SpellBook:GetSpell(17877)   -- 暗影灼烧 (斩杀/移动)
local Cataclysm       = SpellBook:GetSpell(152108)  -- 大灾变 (AOE/铺献祭)
local ChannelDemonfire= SpellBook:GetSpell(196406)  -- 引导恶魔之火

-- 爆发技能
local SummonInfernal  = SpellBook:GetSpell(1122)    -- 召唤地狱火
local Havoc           = SpellBook:GetSpell(80240)   -- 浩劫

-- 英雄天赋 (恶魔使徒 Diabolist)
local Ruin            = SpellBook:GetSpell(442750)  -- 陨灭 (高优泄片)

-- Buff / Debuff
local ImmolateDebuff  = SpellBook:GetSpell(157736)  -- 献祭 DEBUFF
local BackdraftBuff   = SpellBook:GetSpell(117828)  -- 爆燃 BUFF

-- ======================================================================
-- 模块设置
-- ======================================================================

M:DefineSettings({
    { type = "header", label = "== Core Talent Requirements ==", labelZh = "== 核心推荐/必要天赋需求 ==" },
    { type = "header", label = "Required: Diabolist, Cataclysm, Soul Fire, Shadowburn", labelZh = "※ 核心必要天赋: 恶魔使徒(英雄天赋)、大灾变、灵魂之火、暗影灼烧" },
    { type = "header", label = "Note: Hellcaller is NOT supported.", labelZh = "※ 注意: 本脚本不支持唤魔者(枯萎)流派" },

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
})

-- ======================================================================
-- 辅助函数
-- ======================================================================

--- 获取当前灵魂碎片数量 (由于原生为0-50，换算为0-5)
---@return number
local function GetSoulShards()
    local power = Player:GetPower(7) -- Enum.PowerType.SoulShards = 7
    return power / 10
end

--- 检查目标身上的献祭状态 (剩余时间小于30%即可补)
---@return boolean, number (isUp, remainTime)
local function GetImmolateStatus()
    local aura = Target:GetAuras():FindMy(ImmolateDebuff)
    if aura:IsUp() then
        return true, aura:GetRemain()
    end
    return false, 0
end

--- 检查是否有爆燃Buff
---@return boolean
local function HasBackdraft()
    return Player:GetAuras():FindMy(BackdraftBuff):IsUp()
end

--- 检查目标附近敌人数量 (以目标为中心, AOE 落点判断)
---@return number
local function GetEnemiesCount()
    local count = 0
    Bastion.UnitManager:EnumUnits(function(unit)
        if unit:IsEnemy() and unit:IsAlive() and Target:GetDistance(unit) <= 8 then
            count = count + 1
        end
        return false
    end)
    return count
end

-- ======================================================================
-- 主循环
-- ======================================================================

M:Sync(function()
    -- 正在施法或引导中跳过
    if Player:IsCasting() or Player:IsChanneling() then return end

    -- 检查是否可以进行攻击
    if not Target:IsEnemy() or not Target:IsAlive() then return end

    -- 自动攻击
    if AutoAttack:IsKnownAndUsable() and not Player:IsAttacking() then
        AutoAttack:Cast(Target)
    end

    local shards = GetSoulShards()
    local immolateUp, immolateRemain = GetImmolateStatus()
    local isMoving = Player:IsMoving()
    local targetHp = Target:GetHealthPercent()
    local enemyCount = GetEnemiesCount()
    local isAoe = M:GetSetting("useAOE") and enemyCount >= 3
    local useCDs = M:GetSetting("useCooldowns")

    -- [优先级0] 召唤地狱火 (长CD爆发)
    if SummonInfernal:IsKnownAndUsable() and SummonInfernal:IsInRange(Target) and Player:IsFacing(Target) then
        if useCDs then
            if SummonInfernal:Cast(Target) then return end
        end
    end

    -- [优先级1] 大灾变 (AOE并铺设献祭)
    if Cataclysm:IsKnownAndUsable() and Cataclysm:IsInRange(Target) and Player:IsFacing(Target) then
        if not isMoving then
            if Cataclysm:Cast(Target) then return end
        end
    end

    -- [优先级2] 引导恶魔之火 (前提：目标有献祭)
    if immolateUp and ChannelDemonfire:IsKnownAndUsable() and ChannelDemonfire:IsInRange(Target) and Player:IsFacing(Target) then
        if not isMoving then
            if ChannelDemonfire:Cast(Target) then return end
        end
    end

    -- [优先级3] 陨灭 (Ruin) - 恶魔使徒触发的瞬发核弹
    if Ruin:IsKnownAndUsable() and Ruin:IsInRange(Target) and Player:IsFacing(Target) then
        if Ruin:Cast(Target) then return end
    end

    -- [优先级4] 保持献祭 (Immolate)
    -- 如果没有大灾变，且献祭快断了 (< 5.4秒)
    if Immolate:IsKnownAndUsable() and Immolate:IsInRange(Target) and Player:IsFacing(Target) then
        if not isMoving and immolateRemain < 5.4 then
            if Immolate:Cast(Target) then return end
        end
    end

    -- [优先级5] 灵魂之火 (卡CD用)
    if SoulFire:IsKnownAndUsable() and SoulFire:IsInRange(Target) and Player:IsFacing(Target) then
        if not isMoving then
            if SoulFire:Cast(Target) then return end
        end
    end

    -- [优先级6] 燃烧 (控制层数，打出爆燃)
    -- 如果有2层，或者碎片较少，优先打燃烧
    if Conflagrate:IsKnownAndUsable() and Conflagrate:IsInRange(Target) and Player:IsFacing(Target) then
        local charges = Conflagrate:GetCharges()
        if charges == 2 or shards < 2 or not HasBackdraft() then
            if Conflagrate:Cast(Target) then return end
        end
    end

    -- [优先级7] 斩杀或移动战：暗影灼烧
    -- 严格控制在目标血量<20% 或 玩家正在移动时使用
    if Shadowburn:IsKnownAndUsable() and Shadowburn:IsInRange(Target) and Player:IsFacing(Target) then
        if targetHp < 20 or isMoving then
            if Shadowburn:Cast(Target) then return end
        end
    end

    -- [优先级8] 核心泄片 (AOE: 火焰之雨, 单体: 混乱之箭)
    if shards >= 2 then
        if isAoe then
            -- AOE 优先级：火焰之雨 (3个碎片)
            if shards >= 3 and RainOfFire:IsKnownAndUsable() and RainOfFire:IsInRange(Target) and Player:IsFacing(Target) then
                if RainOfFire:Cast(Target) then return end
            end
        else
            -- 单体 优先级：混乱之箭
            -- 当碎片溢出(>=4) 或者 有爆燃Buff时打混乱之箭
            if ChaosBolt:IsKnownAndUsable() and ChaosBolt:IsInRange(Target) and Player:IsFacing(Target) then
                if not isMoving and (shards >= 4 or HasBackdraft()) then
                    if ChaosBolt:Cast(Target) then return end
                end
            end
        end
    end

    -- [优先级9] 填充：烧尽
    if Incinerate:IsKnownAndUsable() and Incinerate:IsInRange(Target) and Player:IsFacing(Target) then
        if not isMoving then
            if Incinerate:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
