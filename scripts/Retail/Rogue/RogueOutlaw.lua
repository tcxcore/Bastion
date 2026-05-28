local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 12.0.5 狂徒潜行者战斗循环 (Outlaw Rogue DPS Rotation)
-- 基于 Warcraft Logs 数据、高阶天赋联动与时运继延机制精细化设计
-- 核心机制：维持切割与骰子，多目标乱舞，高星终结，爆发期消失/影舞步连击
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 核心法术与技能定义 (Spell Definitions)
-- ======================================================================
local AutoAttack        = SpellBook:GetSpell(6603)    -- 自动攻击
local SinisterStrike    = SpellBook:GetSpell(193315)  -- 影袭 (常规攒星)
local PistolShot        = SpellBook:GetSpell(185763)  -- 手枪射击 (机会触发攒星)
local Dispatch          = SpellBook:GetSpell(2098)    -- 斩击 (常规终结技)
local BetweenTheEyes    = SpellBook:GetSpell(315341)  -- 正中眉心 (爆击爆伤终结技)
local SliceAndDice      = SpellBook:GetSpell(315496)  -- 切割 (攻速增益终结技)
local RollTheBones      = SpellBook:GetSpell(1214909) -- 命运骨骰 (核心Buff重抽机制)
local KeepItRolling     = SpellBook:GetSpell(381989)  -- 时运继延 (延长多骰子时间)
local AdrenalineRush    = SpellBook:GetSpell(13750)   -- 冲动 (急速回能大招)
local BladeRush         = SpellBook:GetSpell(271877)  -- 刀锋冲刺 (位移攒星回能爆发)
local KillingSpree      = SpellBook:GetSpell(51690)   -- 影舞步 (高伤星能爆发)
local Ambush            = SpellBook:GetSpell(8676)    -- 伏击 (潜行攒星技能)
local Stealth           = SpellBook:GetSpell(1784)    -- 潜行 (脱战潜行)
local Vanish            = SpellBook:GetSpell(1856)    -- 消失 (战斗中进入潜行)
local BladeFlurry       = SpellBook:GetSpell(13877)   -- 剑刃乱舞 (AOE核心技能)
local TricksOfTheTrade  = SpellBook:GetSpell(57934)    -- 嫁祸诀窍 (给T拉仇恨)
local ThistleTea        = SpellBook:GetSpell(381623)   -- 菊花茶 (能量低于30点回能)
local Preparation       = SpellBook:GetSpell(1277933)  -- 伺机待发 (重置核心CD爆发)

-- 工具与生存自保技能
local Kick              = SpellBook:GetSpell(1766)    -- 脚踢 (单体打断)
local CrimsonVial       = SpellBook:GetSpell(185311)  -- 猩红之瓶 (百分比自愈)
local Feint             = SpellBook:GetSpell(1966)    -- 佯攻 (AOE减伤)
local Evasion           = SpellBook:GetSpell(5277)    -- 闪避 (物理免伤)
local CloakOfShadows    = SpellBook:GetSpell(31224)   -- 暗影斗篷 (魔法免伤)

-- ======================================================================
-- 命运骨骰随机 Buff ID 定义 (12.0.5 变异机制新 Buff)
-- ======================================================================
local SoloBuff           = SpellBook:GetSpell(1214933) -- 独一无二 (1骰)
local DoubleBuff         = SpellBook:GetSpell(1214934) -- 双重麻烦 (2骰)
local TripleBuff         = SpellBook:GetSpell(1214935) -- 三重威胁 (3骰)
local JackpotBuff        = SpellBook:GetSpell(1214937) -- 头奖 (额外爆击Buff)
local LoadedDiceBuff     = SpellBook:GetSpell(256171)  -- 灌铅骰子被动 Buff

local rtbBuffs = { 1214933, 1214934, 1214935, 1214937 }

-- ======================================================================
-- 模块注册与设置
-- ======================================================================
local M = Bastion.Module:New("RogueOutlaw")
M:SetDisplayName("Outlaw Rogue", "狂徒潜行者")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CQQAAAAAAAAAAAAAAAAAAAAAAAgx2MYmZmZmtZmZmZmxsAmZbaZw2MAAAAAAbbzMzwMzMzYmZ2GAAAAGDAGzihBGYWYhWYjBYmBzgB"
            if C_Keybindings and C_Keybindings.CopyToClipboard then
                if C_Keybindings.CopyToClipboard(talentStr) then
                    Bastion:Print("|cFF00FF00[推荐天赋]|r 天赋导出字符串已成功复制到系统剪贴板！可以直接在游戏内导入。")
                    return
                end
            end
            StaticPopupDialogs["BASTION_COPY_TALENTS"] = {
                text = "请按 Ctrl+C 复制推荐天赋配置：",
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
            StaticPopup_Show("BASTION_COPY_TALENTS")
            Bastion:Print("|cFFFFCC00[推荐天赋]|r 已拉起复制框，请按 Ctrl+C 复制天赋导入字符串。")
        end
    },

    { type = "header", label = "== General Settings ==", labelZh = "== 通用设置 ==" },
    {
        type = "toggle",
        key = "useCooldowns",
        label = "Use Cooldowns (Burst)",
        labelZh = "自动释放爆发大招 (冲动/时运)",
        default = true
    },
    {
        type = "toggle",
        key = "autoSND",
        label = "Auto Slice and Dice",
        labelZh = "自动维持切割攻速 Buff",
        default = true
    },
    {
        type = "toggle",
        key = "autoBF",
        label = "Auto Blade Flurry (AOE)",
        labelZh = "多目标智能开启剑刃乱舞",
        default = true
    },
    {
        type = "slider",
        key = "aoeTargets",
        label = "Blade Flurry Enemy Count",
        labelZh = "剑刃乱舞判定敌人数",
        min = 2, max = 8, step = 1,
        default = 2
    },
    {
        type = "toggle",
        key = "autoTricks",
        label = "Auto Tricks of the Trade to Focus",
        labelZh = "自动施放嫁祸诀窍给焦点",
        default = true
    },

    { type = "header", label = "== Defensive Settings ==", labelZh = "== 防御自保设置 ==" },
    {
        type = "toggle",
        key = "autoInterrupt",
        label = "Auto Kick (Interrupt)",
        labelZh = "自动打断 (脚踢)",
        default = true
    },
    {
        type = "slider",
        key = "crimsonVialHP",
        label = "Crimson Vial HP%",
        labelZh = "猩红之瓶自愈血量%",
        min = 10, max = 90, step = 5,
        default = 50
    },
    {
        type = "slider",
        key = "evasionHP",
        label = "Evasion HP%",
        labelZh = "闪避防猝死血量%",
        min = 10, max = 80, step = 5,
        default = 35
    },
    {
        type = "slider",
        key = "feintHP",
        label = "Feint HP%",
        labelZh = "佯攻AOE自防血量%",
        min = 10, max = 90, step = 5,
        default = 65
    }
})

-- ======================================================================
-- 内部高阶辅助函数 (Helper Functions)
-- ======================================================================

-- 1. 智能检测身上是否拥有强力的“头奖”Buff (使用精确 ID 匹配)
local function HasJackpotBuff()
    local aura = Player:GetAuras():FindMy(JackpotBuff)
    if aura and aura:IsUp() and aura:GetRemainingTime() > 1.5 then
        return true
    end
    return false
end

-- 2. 获取活跃命运骨骰 Buff 对应的实际结果数 (4选1互斥结果)
local function GetActiveRtBBuffsCount()
    local auras = Player:GetAuras()
    
    -- 头奖 = 3个骰子大爆发效果
    local jackpot = auras:FindMy(JackpotBuff)
    if jackpot and jackpot:IsUp() and jackpot:GetRemainingTime() > 1.5 then
        return 3
    end
    -- 三重威胁 = 3
    local triple = auras:FindMy(TripleBuff)
    if triple and triple:IsUp() and triple:GetRemainingTime() > 1.5 then
        return 3
    end
    -- 双重麻烦 = 2
    local double = auras:FindMy(DoubleBuff)
    if double and double:IsUp() and double:GetRemainingTime() > 1.5 then
        return 2
    end
    -- 独一无二 = 1
    local solo = auras:FindMy(SoloBuff)
    if solo and solo:IsUp() and solo:GetRemainingTime() > 1.5 then
        return 1
    end
    
    return 0
end

-- 3. 智能判定是否需要使用命运骨骰重滚 (重ROLL逻辑)
local function ShouldRollTheBones()
    if not RollTheBones:IsKnownAndUsable() then return false end
    
    -- A. 没有任意一个骰子结果时，使用命运骨骰
    local activeCount = GetActiveRtBBuffsCount()
    if activeCount == 0 then
        return true
    end
    
    -- B. 如果有灌铅骰子并且当前不是头奖，就重新使用命运骨骰
    local loadedDice = Player:GetAuras():FindMy(LoadedDiceBuff)
    local hasLoadedDice = loadedDice and loadedDice:IsUp()
    local isJackpot = HasJackpotBuff()
    if hasLoadedDice and not isJackpot then
        return true
    end
    
    return false
end

-- 3. 判断切割攻速 Buff 是否需要补充
local function NeedsSliceAndDice()
    if not SliceAndDice:IsKnownAndUsable() then return false end
    local snd = Player:GetAuras():FindMy(SliceAndDice)
    return not snd or not snd:IsUp() or snd:GetRemainingTime() < 2
end

-- 4. 判断是否触发了【机会 (Opportunity)】手枪强化
local function HasOpportunity()
    local opp = Player:GetAuras():FindMy(SpellBook:GetSpell(195627))
    return opp and opp:IsUp()
end

-- 5. 检查剑刃乱舞 (AOE) 状态
local function IsBladeFlurryActive()
    local bf = Player:GetAuras():FindMy(BladeFlurry)
    return bf and bf:IsUp()
end

-- 6. 判断潜行/消失状态（用于高优伏击和眉心判定）
local function IsStealthed()
    local stealth = Player:GetAuras():FindMy(Stealth)
    if stealth and stealth:IsUp() then return true end
    
    local vanishBuff = Player:GetAuras():FindMy(Vanish)
    if vanishBuff and vanishBuff:IsUp() then return true end

    -- 支持诡诈 (Subterfuge) 状态，将其视作潜行状态
    local subterfuge = Player:GetAuras():FindMy(SpellBook:GetSpell(115191))
    if subterfuge and subterfuge:IsUp() then return true end
    
    if _G.IsStealthed and _G.IsStealthed() then return true end
    
    return false
end

-- 7. 判断身上是否有冲动 (Adrenaline Rush) Buff
local function HasAdrenalineRush()
    local ar = Player:GetAuras():FindMy(AdrenalineRush)
    return ar and ar:IsUp() and ar:GetRemainingTime() > 1.5
end

-- 7. 敌对指向安全墙 (面向与 LoS 视野统一拦截)
local function CanCastHostile(spell, unit)
    if not unit or not unit:IsValid() then return false end
    if not Player:IsFacing(unit) or not Player:CanSee(unit) then
        return false
    end
    return true
end

-- 8. 高级打断 (脚踢)
local function HandleInterrupts()
    if not M:GetSetting("autoInterrupt") then return false end
    if not Kick:IsKnownAndUsable() then return false end

    -- 优先打断当前目标
    if Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() then
        if Kick:IsInRange(Target) and CanCastHostile(Kick, Target) then
            if Kick:Cast(Target) then
                Bastion:Print("|cFF00FF00[打断]|r 成功施放脚踢打断 -> " .. Target:GetName())
                return true
            end
        end
    end

    -- 焦点目标打断
    local focus = Bastion.UnitManager:Get('focus')
    if focus and focus:IsValid() and focus:IsEnemy() and focus:IsInterruptible() then
        if Kick:IsInRange(focus) and CanCastHostile(Kick, focus) then
            if Kick:Cast(focus) then
                Bastion:Print("|cFF00FF00[焦点打断]|r 成功施放脚踢打断 -> " .. focus:GetName())
                return true
            end
        end
    end

    -- 鼠标指向打断
    local mouseover = Bastion.UnitManager:Get('mouseover')
    if mouseover and mouseover:IsValid() and mouseover:IsEnemy() and mouseover:IsInterruptible() then
        if Kick:IsInRange(mouseover) and CanCastHostile(Kick, mouseover) then
            if Kick:Cast(mouseover) then
                Bastion:Print("|cFF00FF00[鼠标打断]|r 成功施放脚踢打断 -> " .. mouseover:GetName())
                return true
            end
        end
    end

    return false
end

-- ======================================================================
-- 主战斗循环 (Ticker Sync Loop)
-- ======================================================================
M:Sync(function()
    -- ==================== 施法状态保护 ====================
    if Player:IsCastingOrChanneling() then return end

    -- ==================== 1. 自保与减伤逻辑 (高优先放行，不受安全墙限制) ====================
    local hp = Player:GetHP()
    
    -- 猩红之瓶自愈
    if hp <= M:GetSetting("crimsonVialHP") and CrimsonVial:IsKnownAndUsable() then
        if CrimsonVial:Cast(Player) then return end
    end

    -- 闪避防猝死
    if hp <= M:GetSetting("evasionHP") and Evasion:IsKnownAndUsable() and Player:IsAffectingCombat() then
        if Evasion:Cast(Player) then return end
    end

    -- 佯攻AOE自保
    if hp <= M:GetSetting("feintHP") and Feint:IsKnownAndUsable() and Player:IsAffectingCombat() then
        if Feint:Cast(Player) then return end
    end

    -- 脱战自保 / 补潜行 / 起手进战与消失防发呆逻辑
    if not Player:IsAffectingCombat() then
        -- 无有效敌对目标时：纯脱战跑路挂机状态，补潜行并直接拦截返回
        if not (Target:IsValid() and Target:IsEnemy() and not Target:IsDead()) then
            if not IsStealthed() and Stealth:IsKnownAndUsable() then
                -- 骑乘/使用坐骑状态下不要施放潜行 (使用框架原生 Unit:IsMounted 校验)
                if not Player:IsMounted() then
                    if Stealth:Cast(Player) then return end
                end
            end
            return
        end
        -- 有有效敌对目标时：放行拦截，允许起手或战斗中中途消失后打出伏击/影袭，瞬间重新破隐进战！
    end

    -- 菊花茶智能回能 (能量低于 30 点时自动饮用，放行，不受安全墙限制)
    if Player:GetPower() < 30 and ThistleTea:IsKnownAndUsable() then
        if ThistleTea:Cast(Player) then
            Bastion:Print("|cFF00FF00[能量自燃]|r 能量低于 30 点，成功喝下一杯 菊花茶！")
            return
        end
    end

    -- ==================== 2. 目标有效性与打断检查 ====================
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 执行脚踢打断
    if HandleInterrupts() then return end

    -- 开启自动攻击 (潜行或消失状态下禁止主动普攻起手，以防止破隐)
    if not IsStealthed() then
        if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
            AutoAttack:Cast(Target)
        end
    end

    -- ==================== 3. 自身Buff与爆发准备 (放行，不受面向安全墙限制) ====================
    
    -- 多目标下智能自动开启【剑刃乱舞 (Blade Flurry)】 (进战后才开启)
    if M:GetSetting("autoBF") and BladeFlurry:IsKnownAndUsable() and Player:IsAffectingCombat() then
        local enemiesNearby = Player:GetEnemies(8)
        if enemiesNearby >= M:GetSetting("aoeTargets") and not IsBladeFlurryActive() then
            if BladeFlurry:Cast(Player) then return end
        end
    end

    -- 智能重ROLL【命运骨骰 (Roll the Bones)】
    if ShouldRollTheBones() then
        if RollTheBones:Cast(Player) then return end
    end

    -- 爆发大招连携 (冲动 & 时运继延 & 伺机待发) (进战后才开启)
    if M:GetSetting("useCooldowns") and Player:IsAffectingCombat() then
        -- 冲动 (只有在身上没有冲动 Buff 时才使用，防止误刷新或浪费)
        if AdrenalineRush:IsKnownAndUsable() and not HasAdrenalineRush() then
            if AdrenalineRush:Cast(Player) then return end
        end
        
        -- 时运继延 (只有当获得强力的头奖 Buff 时，才施放时运延长 30 秒)
        if KeepItRolling:IsKnownAndUsable() then
            if HasJackpotBuff() then
                if KeepItRolling:Cast(Player) then return end
            end
        end

        -- 伺机待发 (只有在冲动处于 CD 且身上已没有冲动 Buff 时才重置爆发)
        if Preparation:IsKnownAndUsable() and not HasAdrenalineRush() then
            if AdrenalineRush:GetCooldown() > 10 then
                if Preparation:Cast(Player) then
                    Bastion:Print("|cFF00FF00[大招]|r 冲动已结束且正处于 CD 中，成功施放 伺机待发 重置核心爆发 CD！")
                    return
                end
            end
        end
    end

    -- 智能嫁祸诀窍 (焦点友好坦克拉仇恨，放行，不受面向安全墙限制)
    if M:GetSetting("autoTricks") and TricksOfTheTrade:IsKnownAndUsable() then
        local focus = Bastion.UnitManager:Get('focus')
        if focus and focus:IsValid() and focus:IsFriendly() and not focus:IsDead() then
            if TricksOfTheTrade:IsInRange(focus) then
                if TricksOfTheTrade:Cast(focus) then
                    Bastion:Print("|cFF00FF00[辅助]|r 成功施放 嫁祸诀窍 -> " .. focus:GetName())
                end
            end
        end
    end

    -- ==================== 4. 指向性动作 (强制拦截面向与 3D 视野安全墙) ====================
    if not CanCastHostile(SinisterStrike, Target) then return end

    -- 获取当前连击点数
    local cp = Player:GetComboPoints() or 0

    -- ------------------------------------------------------------------
    -- A. 【终结技 (Finishers)】判定 (高优先，>= 5 个连击点)
    -- ------------------------------------------------------------------
    if cp >= 5 then
        -- 1. 自动补充【切割 (Slice and Dice)】 (进战后才开启)
        if M:GetSetting("autoSND") and NeedsSliceAndDice() and Player:IsAffectingCombat() then
            if SliceAndDice:Cast(Player) then return end
        end

        -- 2. 高优先级终结技：【正中眉心 (Between the Eyes)】 (带距离判定)
        if BetweenTheEyes:IsKnownAndUsable() and BetweenTheEyes:IsInRange(Target) then
            if BetweenTheEyes:Cast(Target) then return end
        end

        -- 3. 常规倾泻终结技：【斩击 (Dispatch)】 (带距离判定)
        if Dispatch:IsKnownAndUsable() and Dispatch:IsInRange(Target) then
            if Dispatch:Cast(Target) then return end
        end
    end

    -- ------------------------------------------------------------------
    -- B. 【爆发补充技 (Burst Generators)】判定
    -- ------------------------------------------------------------------
    if M:GetSetting("useCooldowns") and cp <= 4 then
        -- 1. 【消失 (Vanish)】作为爆发潜行期：当能量充足且冲动开启时，打出潜行加成伏击
        if Vanish:IsKnownAndUsable() and not IsStealthed() then
            if Vanish:Cast(Player) then return end
        end

        -- 2. 【影舞步 (Killing Spree)】：在连击点 <= 3 且能量处于中低水平（防止回能溢出）时卡 CD 释放 (带距离判定)
        if KillingSpree:IsKnownAndUsable() and KillingSpree:IsInRange(Target) and cp <= 3 and Player:GetPower() <= 60 then
            if KillingSpree:Cast(Target) then return end
        end
    end

    -- ------------------------------------------------------------------
    -- C. 【常规攒星技 (Generators)】判定 (连击点 < 5 时)
    -- ------------------------------------------------------------------
    if cp <= 4 then
        -- 1. 潜行状态优先且绝对只打出【伏击 (Ambush)】 (带距离判定)
        if IsStealthed() then
            if Ambush:IsKnownAndUsable() and Ambush:IsInRange(Target) then
                Ambush:Cast(Target)
            end
            -- 只要在潜行中，哪怕伏击因射程或其他原因未施放成功，也绝对直接 return 拦截，不流向后续攒星技能！
            return
        end

        -- 2. 触发【机会】手枪强化：连击点较低 (<= 4) 时高优打出手枪射击，伤害最高且积星快 (带距离判定)
        if HasOpportunity() and PistolShot:IsKnownAndUsable() and PistolShot:IsInRange(Target) then
            if PistolShot:Cast(Target) then return end
        end

        -- 3. 【刀锋冲刺 (Blade Rush)】：连击点 <= 4 且能量较低（恢复能量）时释放 (带距离判定)
        if BladeRush:IsKnownAndUsable() and BladeRush:IsInRange(Target) and Player:GetPower() <= 65 then
            if BladeRush:Cast(Target) then return end
        end

        -- 4. 最基础的攒星填充技能：【影袭 (Sinister Strike)】 (带距离判定)
        if SinisterStrike:IsKnownAndUsable() and SinisterStrike:IsInRange(Target) then
            if SinisterStrike:Cast(Target) then return end
        end
    end

end)

Bastion:Register(M)
return M
