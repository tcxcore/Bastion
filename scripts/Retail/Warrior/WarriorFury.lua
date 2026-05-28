local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 12.0.5 狂怒战士战斗循环 (Fury Warrior DPS Rotation)
-- 基于 WCL 顶尖日志数据、Slayer (屠戮者) 英雄专精与激怒/顺劈机制精细设计
-- 核心机制：维持激怒与顺劈，高星斩杀/暴怒，智能姿态切换，爆发期激怒大招连携
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 核心法术与技能定义 (Spell Definitions)
-- ======================================================================
local AutoAttack        = SpellBook:GetSpell(6603)    -- 自动攻击
local Rampage           = SpellBook:GetSpell(184367)  -- 暴怒 (核心泄怒终结技)
local Bloodthirst       = SpellBook:GetSpell(23881)   -- 嗜血 / 浴血奋战 (主力攒能技)
local RagingBlow        = SpellBook:GetSpell(85288)   -- 怒击 (常规填充积星技)
local Execute           = SpellBook:GetSpell(280735)   -- 斩杀 (高伤高产生怒气技)
local OdynsFury         = SpellBook:GetSpell(385059)  -- 奥丁之怒 (核心高伤爆发技)
local Whirlwind         = SpellBook:GetSpell(190411)    -- 旋风斩 (AOE顺劈核心技能)
local Recklessness      = SpellBook:GetSpell(1719)    -- 鲁莽 (爆发大招)
local Bladestorm        = SpellBook:GetSpell(227847)  -- 剑刃风暴 (高伤引导爆发)
local Charge            = SpellBook:GetSpell(100)     -- 冲锋 (位移攒怒)
local BattleShout       = SpellBook:GetSpell(6673)    -- 战斗怒吼 (团队AP增益)

-- 自保与姿态切换
local BerserkerStance   = SpellBook:GetSpell(386196)    -- 狂暴姿态 (输出姿态)
local DefensiveStance   = SpellBook:GetSpell(386208)  -- 防御姿态 (自保减伤姿态)
local ImpendingVictory  = SpellBook:GetSpell(202168)  -- 胜利在望 (自愈回血)
local EnragedRegeneration = SpellBook:GetSpell(184364) -- 狂怒回复 (核心减伤)
local SpellReflection   = SpellBook:GetSpell(23920)   -- 法术反射 (魔法自防)
local Pummel            = SpellBook:GetSpell(6552)    -- 拳击 (单体打断)
local StormBolt         = SpellBook:GetSpell(107570)   -- 风暴之锤 (远程控制打断)

-- ======================================================================
-- 核心 Buff 与状态定义 (Buff Definitions)
-- ======================================================================
local EnrageBuff        = SpellBook:GetSpell(184362)  -- 激怒 Buff ID
local SuddenDeathBuff   = SpellBook:GetSpell(52437)   -- 猝死 Buff ID
local ImminentDemiseBuff = SpellBook:GetSpell(445606) -- 殒命在即 Buff ID
local wwBuffs = { 85739, 12950 }                      -- 旋风斩顺劈 Buff 候选 ID 表

-- ======================================================================
-- 模块注册与设置
-- ======================================================================
local M = Bastion.Module:New("WarriorFury")
M:SetDisplayName("Fury Warrior", "狂怒战士")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CgEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgGDjhZ2WmZmZmZmxMjZMzMzyMzYMzsNmHYGAAIGLLDsAGwMMBmhNAzgxAAgZGDzMzMMYA"
            if C_Keybindings and C_Keybindings.CopyToClipboard then
                if C_Keybindings.CopyToClipboard(talentStr) then
                    Bastion:Print("|cFF00FF00[推荐天赋]|r 天赋导出字符串已成功复制到系统剪贴板！可以直接在游戏内导入。")
                    return
                end
            end
            StaticPopupDialogs["BASTION_COPY_WARRIOR_TALENTS"] = {
                text = "请按 Ctrl+C 复制推荐狂怒战士天赋配置：",
                button1 = "关闭",
                hasEditBox = true,
                OnShow = function(self)
                    self.EditBox:Hide()
                    C_Timer.After(0.05, function()
                        if self:IsShown() then
                            self:SetWidth(420)
                            self:SetHeight(180)
                            self.EditBox:SetWidth(380)
                            self.EditBox:SetHeight(90)
                            if not self.CustomEditBox then
                                local bg = CreateFrame("Frame", nil, self, "BackdropTemplate")
                                bg:SetBackdrop({
                                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                                    tile = true, tileSize = 16, edgeSize = 12,
                                    insets = { left = 3, right = 3, top = 3, bottom = 3 }
                                })
                                bg:SetBackdropColor(0, 0, 0, 0.8)
                                bg:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8)
                                local edit = CreateFrame("EditBox", nil, bg)
                                edit:SetMultiLine(true)
                                edit:SetFontObject("ChatFontNormal")
                                edit:SetSize(370, 80)
                                edit:SetPoint("CENTER", bg, "CENTER", 0, 0)
                                edit:SetScript("OnEscapePressed", function() self:Hide() end)
                                self.CustomEditBox, self.CustomEditBG = edit, bg
                            end
                            self.CustomEditBG:SetAllPoints(self.EditBox)
                            self.CustomEditBG:Show()
                            self.CustomEditBox:Show()
                            self.CustomEditBox:SetText(talentStr)
                            self.CustomEditBox:HighlightText()
                            self.CustomEditBox:SetFocus()
                        end
                    end)
                end,
                OnHide = function(self)
                    self:SetWidth(320)
                    self:SetHeight(130)
                    self.EditBox:SetWidth(290)
                    self.EditBox:SetHeight(20)
                    self.EditBox:Show()
                    if self.CustomEditBox then
                        self.CustomEditBox:Hide()
                        self.CustomEditBG:Hide()
                    end
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = true,
            }
            StaticPopup_Show("BASTION_COPY_WARRIOR_TALENTS")
            Bastion:Print("|cFFFFCC00[推荐天赋]|r 已拉起复制框，请按 Ctrl+C 复制天赋导入字符串。")
        end
    },

    { type = "header", label = "== General Settings ==", labelZh = "== 通用设置 ==" },
    {
        type = "toggle",
        key = "useCooldowns",
        label = "Use Cooldowns (Burst)",
        labelZh = "自动释放爆发大招 (鲁莽/奥丁/风暴)",
        default = true
    },
    {
        type = "toggle",
        key = "autoWhirlwind",
        label = "Auto Cleave (Whirlwind)",
        labelZh = "多目标智能开启旋风斩顺劈",
        default = true
    },
    {
        type = "slider",
        key = "aoeTargets",
        label = "Cleave Enemy Count",
        labelZh = "顺劈判定敌人数",
        min = 2, max = 8, step = 1,
        default = 2
    },
    {
        type = "toggle",
        key = "autoCharge",
        label = "Auto Charge Bit",
        labelZh = "自动冲锋起手与拉近距离",
        default = true
    },

    { type = "header", label = "== Stance & Defensive Settings ==", labelZh = "== 姿态与自保设置 ==" },
    {
        type = "toggle",
        key = "autoStance",
        label = "Auto Stance Switch",
        labelZh = "智能姿态自动切换防猝死",
        default = true
    },
    {
        type = "slider",
        key = "defensiveHP",
        label = "Defensive Stance HP%",
        labelZh = "自动切防御姿态血量%",
        min = 10, max = 60, step = 5,
        default = 35
    },
    {
        type = "toggle",
        key = "autoInterrupt",
        label = "Auto Pummel (Interrupt)",
        labelZh = "自动打断 (拳击)",
        default = true
    },
    {
        type = "toggle",
        key = "autoStormBolt",
        label = "Auto Storm Bolt",
        labelZh = "自动远程控制 (风暴之锤)",
        default = false
    },
    {
        type = "slider",
        key = "victoryHP",
        label = "Impending Victory HP%",
        labelZh = "胜利在望自愈血量%",
        min = 20, max = 80, step = 5,
        default = 60
    },
    {
        type = "slider",
        key = "regenerationHP",
        label = "Enraged Regeneration HP%",
        labelZh = "狂怒回复减伤血量%",
        min = 10, max = 50, step = 5,
        default = 25
    }
})

-- ======================================================================
-- 内部高阶辅助函数 (Helper Functions)
-- ======================================================================

-- 1. 检查玩家是否处于激怒 (Enrage) 状态
local function IsEnraged()
    local enrage = Player:GetAuras():FindMy(EnrageBuff)
    return enrage and enrage:IsUp() and enrage:GetRemainingTime() > 1.0
end

-- 2. 检查玩家身上是否有顺劈 (Whirlwind) Buff
local function HasWhirlwindBuff()
    local auras = Player:GetAuras()
    for _, id in ipairs(wwBuffs) do
        local buff = auras:FindMy(SpellBook:GetSpell(id))
        if buff and buff:IsUp() and (buff:GetCount() or 0) > 0 then
            return true
        end
    end
    return false
end

-- 3. 判断是否需要施放旋风斩补顺劈 (多目标下无顺劈Buff)
local function ShouldCastWhirlwind()
    if not M:GetSetting("autoWhirlwind") then return false end
    if not Whirlwind:IsKnownAndUsable() then return false end

    local enemiesNearby = Player:GetEnemies(8)
    if enemiesNearby >= M:GetSetting("aoeTargets") then
        return not HasWhirlwindBuff()
    end
    return false
end

-- 4. 检查当前姿态 (通过 IsUp 确保状态切换的绝对精准)
local function GetCurrentStance()
    local def = Player:GetAuras():FindMy(DefensiveStance)
    if def and def:IsUp() then
        return "defensive"
    end
    return "berserker"
end

-- 4.5. 判断是否触发了【猝死 (Sudden Death)】无视血量斩杀
local function HasSuddenDeath()
    -- 1. 标准 FindMy 方式检索 (只查找 playerAuras，代表玩家自己触发)
    local sd = Player:GetAuras():FindMy(SuddenDeathBuff)
    if sd and sd:IsUp() then
        return true
    end
    
    -- 2. 扩充 Find 方式检索 (查找 auras 表，应对系统判定 source 非 player 的被动触发情况)
    -- local sd2 = Player:GetAuras():Find(SuddenDeathBuff)
    -- if sd2 and sd2:IsUp() then
    --     return true
    -- end
    return false
end

-- 4.6. 判断是否触发了【殒命在即 (Imminent Demise)】3层剑刃风暴强化
local lastImminentDemiseCount = 0
local function HasImminentDemise()
    -- 双表融合检索：同时查询玩家专属表 (FindMy) 与全局表 (Find)，应对游戏底层对被动 Buff 归类的五花八门划分
    local auras = Player:GetAuras()
    local id = auras:FindMy(ImminentDemiseBuff)
    if not id or not id:IsUp() then
        id = auras:Find(ImminentDemiseBuff)
    end
    
    local isUp = id and id:IsUp()
    local count = isUp and (id:GetCount() or 0) or 0
    
    return isUp and count >= 3
end

-- 4.7. 检查玩家是否正处于剑刃风暴旋转引导状态中
local function IsBladestorming()
    -- 剑刃风暴旋转时身上会带有 446035 或 227847 Buff
    local auras = Player:GetAuras()
    local bs1 = auras:FindMy(SpellBook:GetSpell(446035))
    if bs1 and bs1:IsUp() then return true end
    
    local bs2 = auras:Find(SpellBook:GetSpell(446035))
    if bs2 and bs2:IsUp() then return true end
    
    local bs3 = auras:FindMy(SpellBook:GetSpell(227847))
    if bs3 and bs3:IsUp() then return true end
    
    local bs4 = auras:Find(SpellBook:GetSpell(227847))
    if bs4 and bs4:IsUp() then return true end
    
    return false
end

-- 5. 敌对指向安全墙 (面向与 LoS 视野统一拦截)
local function CanCastHostile(spell, unit)
    if not unit or not unit:IsValid() then return false end
    if not Player:IsFacing(unit) or not Player:CanSee(unit) then
        return false
    end
    return true
end

-- 6. 高级智能打断 (拳击 & 风暴之锤)
local function HandleInterrupts()
    if not M:GetSetting("autoInterrupt") then return false end

    -- 1. 优先打断当前目标 (拳击)
    if Pummel:IsKnownAndUsable() and Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() then
        if Pummel:IsInRange(Target) and CanCastHostile(Pummel, Target) then
            if Pummel:Cast(Target) then
                Bastion:Print("|cFF00FF00[打断]|r 成功施放拳击打断 -> " .. Target:GetName())
                return true
            end
        end
    end

    -- 2. 焦点目标打断 (拳击)
    local focus = Bastion.UnitManager:Get('focus')
    if Pummel:IsKnownAndUsable() and focus and focus:IsValid() and focus:IsEnemy() and focus:IsInterruptible() then
        if Pummel:IsInRange(focus) and CanCastHostile(Pummel, focus) then
            if Pummel:Cast(focus) then
                Bastion:Print("|cFF00FF00[焦点打断]|r 成功施放拳击打断 -> " .. focus:GetName())
                return true
            end
        end
    end

    -- 3. 辅助控制打断 (风暴之锤，仅在开启且常规打断CD时启用)
    if M:GetSetting("autoStormBolt") and StormBolt:IsKnownAndUsable() then
        if Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() and not Pummel:IsReady() then
            if StormBolt:IsInRange(Target) and CanCastHostile(StormBolt, Target) then
                if StormBolt:Cast(Target) then
                    Bastion:Print("|cFF00FF00[控制打断]|r 施放风暴之锤击晕打断 -> " .. Target:GetName())
                    return true
                end
            end
        end
    end

    return false
end

-- ======================================================================
-- 主战斗循环 (Ticker Sync Loop)
-- ======================================================================
M:Sync(function()
    -- 动态自适应修正剑刃风暴的法术 ID (应对专精版 446035 与通用版 227847 在法术书中的混淆)
    if not Bladestorm:IsKnown() then
        Bladestorm = SpellBook:GetSpell(227847)
    end

    -- ==================== 施法状态与剑刃风暴引导旋转保护 ====================
    if Player:IsCastingOrChanneling() or IsBladestorming() then return end

    -- ==================== 1. 极其优先的防御姿态切换 (不受安全墙限制) ====================
    if M:GetSetting("autoStance") and Player:IsAffectingCombat() then
        local hp = Player:GetHP()
        local currentStance = GetCurrentStance()
        
        -- A. 血量极低且在战斗中，智能切入防御姿态自保
        if hp <= M:GetSetting("defensiveHP") and currentStance ~= "defensive" then
            if DefensiveStance:Cast(Player) then
                Bastion:Print("|cFFFF0000[姿态自保]|r 血量过低，紧急切入 防御姿态 减伤！")
                return
            end
        end

        -- B. 血线安全后，智能切换回狂暴姿态，最大化输出
        if hp > (M:GetSetting("defensiveHP") + 15) and currentStance == "defensive" then
            if BerserkerStance:Cast(Player) then
                Bastion:Print("|cFF00FF00[姿态复原]|r 血线已安全，重新切回 狂暴姿态 强力输出！")
                return
            end
        end
    end

    -- ==================== 2. 防御自保技能 (高优先，不受安全墙限制) ====================
    local hp = Player:GetHP()

    -- 狂怒回复 (核心生死大减伤)
    if hp <= M:GetSetting("regenerationHP") and EnragedRegeneration:IsKnownAndUsable() and Player:IsAffectingCombat() then
        if EnragedRegeneration:Cast(Player) then return end
    end

    -- 胜利在望 (高回血自疗，需要有敌对目标且在射程内，故放于此处)
    if hp <= M:GetSetting("victoryHP") and ImpendingVictory:IsKnownAndUsable() then
        if Target:IsValid() and Target:IsEnemy() and not Target:IsDead() then
            if ImpendingVictory:IsInRange(Target) and CanCastHostile(ImpendingVictory, Target) then
                if ImpendingVictory:Cast(Target) then return end
            end
        end
    end



    -- 脱战且不骑马时，自动补全【战斗怒吼】Buff
    if not Player:IsAffectingCombat() and not Player:IsMounted() and BattleShout:IsKnownAndUsable() then
        local shout = Player:GetAuras():FindMy(BattleShout)
        if not shout or not shout:IsUp() or shout:GetRemainingTime() < 60 then
            if BattleShout:Cast(Player) then return end
        end
    end

    -- ==================== 3. 目标有效性与打断检查 ====================
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 执行脚踢/控制打断
    if HandleInterrupts() then return end

    -- 开启自动攻击 (骑马状态下禁止，防下马)
    if not Player:IsMounted() then
        if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
            AutoAttack:Cast(Target)
        end
    end

    -- ==================== 4. 自身大招与爆发准备 (非指向性，进战才放) ====================
    if M:GetSetting("useCooldowns") and Player:IsAffectingCombat() then
        -- 鲁莽 (Recklessness) 卡 CD 开启
        if Recklessness:IsKnownAndUsable() then
            if Recklessness:Cast(Player) then return end
        end
    end

    -- ==================== 5. 指向性攻击动作 (强制拦截面向与 3D 视野安全墙) ====================
    if not CanCastHostile(Bloodthirst, Target) then return end

    -- 冲锋 (Charge) 智能位移 (融入 UI 开关，使用 IsInRange 自动自适应大体型怪，防太近卡死)
    if M:GetSetting("autoCharge") and Charge:IsKnownAndUsable() and Charge:IsInRange(Target) then
        if Charge:Cast(Target) then return end
    end

    -- 获取当前怒气 (Rage)
    local rage = Player:GetPower() or 0

    -- ------------------------------------------------------------------
    -- A. 【核心泄怒/终结技】判定 (高优先级)
    -- ------------------------------------------------------------------
    
    -- 1. 暴怒 (Rampage)：主力泄怒终结技 (消耗 80 怒气，只要 >= 80 立即打出，防嗜血抢GCD与怒气溢出)
    if Rampage:IsKnownAndUsable() and Rampage:IsInRange(Target) then
        if rage >= 80 then
            if Rampage:Cast(Target) then return end
        end
    end

    -- 2. 斩击 (Execute)：斩杀线内 (<= 35%) 或触发猝死 Buff 时卡 CD 施放
    -- 注意：在非斩杀线且有猝死 Buff 时，Execute 可能会在技能栏高亮，但底层 IsUsable 或 IsInRange 往往会有延迟或判定异常。
    -- 故此处我们手写了严密的判定，并使用 ForceCast 绕过框架内置的 Castable/IsUsable 校验，保证高亮时 100% 施放！
    local hp = Target:GetHP()
    local hasSD = HasSuddenDeath()
    if (hp <= 35 or hasSD) then
        if Player:InMelee(Target) or (Target:GetDistance(Player) <= 8) then
            if Execute:GetCooldown() == 0 then
                if Execute:ForceCast(Target) then return end
            end
        end
    end

    -- 3. 触发“殒命在即 (Imminent Demise)” Buff 达到 3 层时，高优施放剑刃风暴
    if HasImminentDemise() and Bladestorm:IsKnownAndUsable() then
        if Player:InMelee(Target) or (Target:GetDistance(Player) <= 8) then
            Bastion:Print("|cFF00FF00[狂怒战士]|r 触发3层殒命在即 Buff，施放剑刃风暴！")
            if Bladestorm:Cast(Target) then return end
        end
    end

    -- ------------------------------------------------------------------
    -- B. 【多目标顺劈前置】判定
    -- ------------------------------------------------------------------
    -- 多目标下，如果身上没有【旋风斩】顺劈 Buff，必须高优打出旋风斩补顺劈！
    if ShouldCastWhirlwind() and Whirlwind:IsInRange(Target) then
        if Whirlwind:Cast(Target) then return end
    end

    -- ------------------------------------------------------------------
    -- C. 【爆发大招】判定 (要求在激怒状态下施放，吃满急速和伤害增益)
    -- ------------------------------------------------------------------
    if M:GetSetting("useCooldowns") and Player:IsAffectingCombat() and IsEnraged() then
        -- 1. 奥丁之怒 (Odyn's Fury) - 优化距离校验与自我施法
        if OdynsFury:IsKnownAndUsable() then
            if Player:InMelee(Target) or (Target:GetDistance(Player) <= 8) then
                if OdynsFury:Cast(Target) then return end
            end
        end

        -- 2. 剑刃风暴 (Bladestorm) - 优化距离校验与对自身施法 (自我AOE技能)
        if Bladestorm:IsKnownAndUsable() then
            if Player:InMelee(Target) or (Target:GetDistance(Player) <= 8) then
                if Bladestorm:Cast(Player) then return end
            end
        end
    end

    -- ------------------------------------------------------------------
    -- D. 【常规攒能与填充技】判定 (怒气未满且没有顺劈断档时)
    -- ------------------------------------------------------------------
    
    -- 1. 嗜血 / 浴血奋战 (Bloodthirst/Bloodbath)：主力攒能技能，有就打
    if Bloodthirst:IsKnownAndUsable() and Bloodthirst:IsInRange(Target) then
        if Bloodthirst:Cast(Target) then return end
    end

    -- 2. 怒击 (Raging Blow)：冷却填充攒能技能
    if RagingBlow:IsKnownAndUsable() and RagingBlow:IsInRange(Target) then
        if RagingBlow:Cast(Target) then return end
    end

    -- 3. 旋风斩 (Whirlwind) 作为最后的单体垃圾填充技能 (没有任何技能可打时)
    if Whirlwind:IsKnownAndUsable() and Whirlwind:IsInRange(Target) then
        if Whirlwind:Cast(Target) then return end
    end

end)

Bastion:Register(M)
return M
