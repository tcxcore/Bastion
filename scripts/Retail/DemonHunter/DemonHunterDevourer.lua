local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 恶魔猎手 - 噬灭专精 (Devourer Demon Hunter DPS Rotation)
-- 适配 WoW 12.0.5 Midnight 版本全新第三专精
-- 核心循环: 吞噬(积攒资源) -> 虚空射线(消耗资源) -> 坍缩之星(虚空形态/高资源终结)
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义 (Spell Definitions)
-- ======================================================================

-- 基础与防御技能
local AutoAttack       = SpellBook:GetSpell(6603)    -- 自动攻击
local Blur             = SpellBook:GetSpell(198589)  -- 疾影 (防暴毙)
local ThrowGlaive      = SpellBook:GetSpell(185123)  -- 投掷利刃 (远程填充)

-- 噬灭 (Devourer) 12.0.5 核心专属技能
local Devour           = SpellBook:GetSpell(473662)  -- 吞噬 (核心填充/生成)
local VoidRay          = SpellBook:GetSpell(473728)  -- 虚空射线 (核心消耗)
local CollapsingStar   = SpellBook:GetSpell(1221150) -- 坍缩之星 (绝对核心爆发/终结技)
local SoulSacrifice    = SpellBook:GetSpell(1241937) -- 灵魂献祭 (短CD增益/AOE)

-- ======================================================================
-- 模块定义
-- ======================================================================

---@class DemonHunterDevourer : Module
local M = Bastion.Module:New("DemonHunterDevourer")
M:SetDisplayName("Devourer Demon Hunter", "噬灭恶魔猎手")

M:DefineSettings({
    { type = "header", label = "== Core Talent Requirements ==", labelZh = "== 核心必要天赋需求 ==" },
    { type = "header", label = "Spec: Devourer (12.0.5)", labelZh = "※ 专精: 噬灭 (12.0.5)" },
    
    { type = "header", label = "== Defensive ==", labelZh = "== 防御设置 ==" },
    {
        type = "toggle",
        key = "useBlur",
        label = "Use Blur automatically",
        labelZh = "自动使用疾影",
        default = true
    },
    {
        type = "slider",
        key = "blurHP",
        label = "Blur HP Threshold (%)",
        labelZh = "疾影血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 40
    },
})

-- ======================================================================
-- 战斗循环主体
-- ======================================================================

M:Sync(function()
    -- 正在施法或引导中跳过 (防止打断射线等引导技能)
    if Player:IsCasting() or Player:IsChanneling() then return end

    -- 目标验证
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- 自动攻击
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- ==================================================================
    -- 防御/自保逻辑
    -- ==================================================================
    -- 疾影 (Blur)
    if M:GetSetting("useBlur") and Player:GetHP() <= M:GetSetting("blurHP") then
        if Blur:IsKnownAndUsable() then
            if Blur:Cast(Player) then return end
        end
    end

    -- ==================================================================
    -- 噬灭 (Devourer) 核心输出循环
    -- ==================================================================

    -- [优先级 1] 坍缩之星 (Collapsing Star)
    -- WCL 伤害占比 28.5%，是噬灭流派的绝对核心爆发/终结技。
    -- 只要技能亮起（条件满足）立刻砸出，绝不延误。
    if CollapsingStar:IsKnownAndUsable() and CollapsingStar:IsInRange(Target) then
        if CollapsingStar:Cast(Target) then return end
    end

    -- [优先级 2] 灵魂献祭 (Soul Sacrifice)
    -- 短CD技能，卡CD使用维持覆盖率或爆发。
    if SoulSacrifice:IsKnownAndUsable() then
        -- 尝试以目标为中心施放
        if SoulSacrifice:Cast(Target) then return end
    end

    -- [优先级 3] 虚空射线 (Void Ray)
    -- 核心资源倾泻技能，在没有坍缩之星时，消耗由“吞噬”积攒的资源。
    -- (IsKnownAndUsable 会自动判断能量/资源是否足够)
    if VoidRay:IsKnownAndUsable() and VoidRay:IsInRange(Target) then
        if VoidRay:Cast(Target) then return end
    end

    -- [优先级 4] 吞噬 (Devour)
    -- 高频填充法术，用于积累残片/虚空能量，疯狂按。
    if Devour:IsKnownAndUsable() and Devour:IsInRange(Target) then
        if Devour:Cast(Target) then return end
    end

    -- ==================================================================
    -- 远程走位填充
    -- ==================================================================
    -- 当离开近战范围且无法打出吞噬时，扔飞镖维持伤害
    if not Player:InMelee(Target) then
        if ThrowGlaive:IsKnownAndUsable() and ThrowGlaive:IsInRange(Target) then
            if ThrowGlaive:Cast(Target) then return end
        end
    end

end)

Bastion:Register(M)
return M
