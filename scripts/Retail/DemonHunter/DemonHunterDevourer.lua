local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 恶魔猎手 - 噬灭专精 (Devourer Demon Hunter DPS Rotation)
-- 适配 WoW 12.0.5 Midnight 版本全新第三专精
-- 核心机制：双资源系统（灵魂残片+恶魔之怒）。
-- 循环目标：攒够 50 灵魂残片并保持高怒气进入【虚空变形】。在形态内疯狂使用【虚空射线】续命，并穿插强化技能与【坍缩之星】。
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义 (Spell Definitions)
-- ======================================================================

-- 基础与防御技能
local AutoAttack           = SpellBook:GetSpell(6603)    -- 自动攻击
local Blur                 = SpellBook:GetSpell(198589)  -- 疾影 (防暴毙)
local ThrowGlaive          = SpellBook:GetSpell(185123)  -- 投掷利刃 (远程填充)

-- 噬灭 (Devourer) 12.0.5 核心专属技能
local Devour               = SpellBook:GetSpell(473662)  -- 吞噬
local Reap                 = SpellBook:GetSpell(1226019) -- 收割
local VoidRay              = SpellBook:GetSpell(473728)  -- 虚空射线
local SoulSacrifice        = SpellBook:GetSpell(1241937) -- 灵魂献祭 (短CD增益/产片核心)
local VoidTransformation   = SpellBook:GetSpell(1217605) -- 虚空变形 (消耗 50 残片进入爆发形态)

local VoidTransformationBuff = SpellBook:GetSpell(1217607)

-- ======================================================================
-- 模块定义
-- ======================================================================

---@class DemonHunterDevourer : Module
local M = Bastion.Module:New("DemonHunterDevourer")
M:SetDisplayName("Devourer Demon Hunter", "噬灭恶魔猎手")

M:DefineSettings({
    { type = "header", label = "== Core Talent Requirements ==", labelZh = "== 核心必要天赋需求 ==" },
    { type = "header", label = "Spec: Devourer (12.0.5)", labelZh = "※ 专精: 噬灭 (12.0.5)" },
    { type = "header", label = "Active Talents: Void Transformation, Soul Sacrifice, Void Ray", labelZh = "※ 核心主动天赋: 虚空变形、灵魂献祭、虚空射线、吞噬" },
    { type = "header", label = "Passive Talents: Collapsing Star, Eradication, Voidfall Meteor", labelZh = "※ 核心被动联动: 坍缩之星、根除、虚落流星、灭世灾星" },
    { type = "header", label = "== Offense ==", labelZh = "== 输出设置 ==" },
    {
        type = "slider",
        key = "voidFuryThreshold",
        label = "Void Form Fury Threshold",
        labelZh = "变身恶魔之怒阈值",
        min = 0, max = 100, step = 5,
        default = 70
    },

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
    -- 资源状态获取
    -- ==================================================================
    local fury = Player:GetPower(17) or 0
    -- 判断是否处于【虚空变形】形态
    local isVoidForm = false
    local voidBuff = Player:GetAuras():FindMy(VoidTransformationBuff)
    if voidBuff and voidBuff:IsUp() then
        isVoidForm = true
    end

    -- ==================================================================
    -- 噬灭 (Devourer) 双态输出循环
    -- ==================================================================

    if isVoidForm then
        -- --------------------------------------------------------------
        -- 【状态 1：虚空爆发期】
        -- 核心目标：首优释放虚空射线以减缓怒气流失，延长形态寿命；次优打出坍缩之星。
        -- --------------------------------------------------------------

        -- [优先级 1] 坍缩之星 (消耗 30 灵魂残片)
        -- 核心机制：坍缩之星消耗的是灵魂残片，而不是恶魔之怒。
        -- 只要我们在虚空形态内攒够了 30 片，技能就会亮起，第一时间砸下去！
        if VoidTransformation:IsKnownAndUsable() and Player:IsFacing(Target) then
            if VoidTransformation:Cast(Target) then return end
        end

        -- [优先级 2] 灵魂献祭 (核心产片/Buff技)
        -- 卡CD放，加速获取灵魂残片
        if SoulSacrifice:IsKnownAndUsable() and Player:IsFacing(Target) then
            if SoulSacrifice:Cast(Target) then return end
        end

        -- [优先级 3] 虚空射线 (减缓怒气流失，延长变身时间)
        -- 卡CD放，尽可能留住恶魔之怒，争取在变身结束前砸出更多的坍缩之星。
        if VoidRay:IsKnownAndUsable() and VoidRay:IsInRange(Target) and Player:IsFacing(Target) then
            if VoidRay:Cast(Target) then return end
        end

        -- [优先级 4] 收割 (强化填充)
        if Reap:IsKnownAndUsable() and Reap:IsInRange(Target) and Player:IsFacing(Target) then
            if Reap:Cast(Target) then return end
        end

        -- [优先级 4] 吞噬 (强化填充)
        if Devour:IsKnownAndUsable() and Devour:IsInRange(Target) and Player:IsFacing(Target) then
            if Devour:Cast(Target) then return end
        end

    else
        -- --------------------------------------------------------------
        -- 【状态 2：平稳攒片期】
        -- 核心目标：最快速度打满 50 残片，并在怒气充足时立刻切入虚空形态。
        -- --------------------------------------------------------------

        -- [优先级 1] 开启虚空变形！
        -- 如果系统允许释放(已满50残片)，且怒气达到了用户设定的安全阈值(默认>70)，立刻变身！
        if fury >= M:GetSetting("voidFuryThreshold") and VoidTransformation:IsKnownAndUsable() then
            -- 虚空变形通常是对自身施放的 Buff 类技能
            if VoidTransformation:Cast(Player) then return end
        end

        -- [优先级 2] 灵魂献祭 (核心Buff/产片技)
        -- 平稳期卡CD使用，极大加速残片获取。
        if SoulSacrifice:IsKnownAndUsable() and Player:IsFacing(Target) then
            if SoulSacrifice:Cast(Target) then return end
        end

        -- [优先级 3] 坍缩之星 (防溢出或瞬发)
        -- 平稳期如果有特殊触发机制导致可以打坍缩之星，同样通过变身键砸下
        if VoidTransformation:IsKnownAndUsable() and VoidTransformation:GetName() == "坍缩之星" and Player:IsFacing(Target) then
            if VoidTransformation:Cast(Target) then return end
        end

        -- [优先级 4] 虚空射线 (防怒气溢出)
        -- 平稳期射线会消耗怒气，仅在怒气即将溢出 (比如 >= 90) 时用来倾泄
        if fury >= 90 and VoidRay:IsKnownAndUsable() and VoidRay:IsInRange(Target) and Player:IsFacing(Target) then
            if VoidRay:Cast(Target) then return end
        end

        -- [优先级 4] 收割 (核心产片)
        if Reap:IsKnownAndUsable() and Reap:IsInRange(Target) and Player:IsFacing(Target) then
            if Reap:Cast(Target) then return end
        end

        -- [优先级 5] 吞噬 (核心产片)
        if Devour:IsKnownAndUsable() and Devour:IsInRange(Target) and Player:IsFacing(Target) then
            if Devour:Cast(Target) then return end
        end
    end

    -- ==================================================================
    -- 远程走位填充
    -- ==================================================================
    -- 当离开近战范围时，扔飞镖维持伤害
    if not Player:InMelee(Target) then
        if ThrowGlaive:IsKnownAndUsable() and ThrowGlaive:IsInRange(Target) and Player:IsFacing(Target) then
            if ThrowGlaive:Cast(Target) then return end
        end
    end

end)

Bastion:Register(M)
return M
