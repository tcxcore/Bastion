local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 冰霜死亡骑士战斗循环 (Frost Death Knight DPS Rotation)
-- 基于 Warcraft Logs 冰DK输出手法与死神使者英雄天赋设计
-- 核心流派: 冰龙吐息流 (Breath of Sindragosa)
-- 核心机制: 全力维持吐息, 平稳期触发杀戮机器打爆击湮灭, 白霜打凛风
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义 (Spell Definitions)
-- ======================================================================

-- 基础法术
local AutoAttack        = SpellBook:GetSpell(6603)    -- 自动攻击
local Obliterate        = SpellBook:GetSpell(49020)   -- 湮灭 (核心符文消耗)
local FrostStrike       = SpellBook:GetSpell(49143)   -- 冰霜打击 (单体能量倾泄)
local HowlingBlast      = SpellBook:GetSpell(49184)   -- 凛风冲击 (白霜消耗/施加疫病)
local Frostscythe       = SpellBook:GetSpell(207230)  -- 冰霜之镰 (AOE符文消耗)
local GlacialAdvance    = SpellBook:GetSpell(194913)  -- 冰川突进 (AOE能量倾泄)

-- 爆发/冷却技能
local PillarOfFrost     = SpellBook:GetSpell(51271)   -- 冰霜之柱 (1分钟主要力量爆发)
local ReapersMark       = SpellBook:GetSpell(439843)  -- 死神印记 (1分钟英雄天赋大招)
local BreathOfSindragosa= SpellBook:GetSpell(1249658)  -- 冰龙吐息 (2分钟持续能消耗大爆发)
local EmpowerRuneWeapon = SpellBook:GetSpell(47568)   -- 符文武器增效 (资源恢复CD)
local RaiseDead         = SpellBook:GetSpell(46585)   -- 亡者复生 (召唤食尸鬼协助)

-- 防御/打断/工具技能
local MindFreeze        = SpellBook:GetSpell(47528)   -- 心灵冰冻 (打断)
local DeathStrike       = SpellBook:GetSpell(49998)   -- 灵界打击 (回血技能)
local AntiMagicShield   = SpellBook:GetSpell(48707)   -- 反魔法护罩 (魔法吸收)
local IceboundFortitude = SpellBook:GetSpell(48792)   -- 冰封之韧 (大减伤/解控)
local Lichborne         = SpellBook:GetSpell(49039)   -- 巫妖之躯 (吸血/减伤/解控)

-- ======================================================================
-- BUFF/DEBUFF ID 定义
-- ======================================================================
local KillingMachineBuff = SpellBook:GetSpell(51124)   -- 杀戮机器 BUFF (湮灭必爆)
local RimeBuff           = SpellBook:GetSpell(59052)   -- 白霜 BUFF (凛风冲击免费且伤害提升)
local ExterminateBuff    = SpellBook:GetSpell(441416)  -- 破灭 BUFF (印记终结后下一次湮灭强化)
local FrostFeverDebuff   = SpellBook:GetSpell(55095)   -- 冰霜疫病 DEBUFF (目标疾病Dot)
local BreathOfSindragosaBuff = BreathOfSindragosa      -- 冰龙吐息激活中BUFF

-- ======================================================================
-- 模块定义
-- ======================================================================

---@class DeathKnightFrost : Module
local M = Bastion.Module:New("DeathKnightFrost")
M:SetDisplayName("Frost DeathKnight", "冰霜死亡骑士")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CsPAAAAAAAAAAAAAAAAAAAAAAMDYmZMzMDY2mZmZmZxMjMjxYYGGMzMzMzMzMDAAAAAAAAAjZbgBsAWGmAjFMzYmZgBghZGgZgB"
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
        label = "Use Cooldowns",
        labelZh = "使用爆发技能(冰柱/印记)",
        default = true
    },
    {
        type = "toggle",
        key = "useBreath",
        label = "Use Breath of Sindragosa",
        labelZh = "自动释放冰龙吐息",
        default = true
    },
    {
        type = "toggle",
        key = "useAOE",
        label = "Use AOE Spells",
        labelZh = "使用AOE技能(冰镰/突进)",
        default = true
    },
    {
        type = "slider",
        key = "aoeTargets",
        label = "AOE Target Count",
        labelZh = "AOE 目标数量阈值",
        min = 2, max = 10, step = 1,
        default = 3
    },

    { type = "header", label = "== Defensive Settings ==", labelZh = "== 自保与减伤设置 ==" },
    {
        type = "slider",
        key = "deathStrikeHP",
        label = "Death Strike HP (%)",
        labelZh = "灵界打击血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 50
    },
    {
        type = "toggle",
        key = "useAMS",
        label = "Use Anti-Magic Shield",
        labelZh = "使用反魔法护罩",
        default = true
    },
    {
        type = "slider",
        key = "amsHP",
        label = "Anti-Magic Shield HP (%)",
        labelZh = "反魔法护罩血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 80
    },
    {
        type = "toggle",
        key = "useIBF",
        label = "Use Icebound Fortitude",
        labelZh = "使用冰封之韧",
        default = true
    },
    {
        type = "slider",
        key = "ibfHP",
        label = "Icebound Fortitude HP (%)",
        labelZh = "冰封之韧血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 35
    },
    {
        type = "toggle",
        key = "useLichborne",
        label = "Use Lichborne",
        labelZh = "使用巫妖之躯",
        default = true
    },
    {
        type = "slider",
        key = "lichborneHP",
        label = "Lichborne HP (%)",
        labelZh = "巫妖之躯血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 20
    },

    { type = "header", label = "== Interrupt Settings ==", labelZh = "== 打断设置 ==" },
    {
        type = "toggle",
        key = "useInterrupt",
        label = "Use Mind Freeze (Interrupt)",
        labelZh = "使用心灵冰冻(自动打断)",
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
})

-- ======================================================================
-- 辅助函数
-- ======================================================================

--- 检查玩家是否拥有杀戮机器 BUFF
---@return boolean
local function HasKillingMachine()
    return Player:GetAuras():FindMy(KillingMachineBuff):IsUp()
end

--- 检查玩家是否拥有白霜 BUFF
---@return boolean
local function HasRime()
    return Player:GetAuras():FindMy(RimeBuff):IsUp()
end

--- 检查玩家是否拥有破灭 BUFF
---@return boolean
local function HasExterminate()
    return Player:GetAuras():FindMy(ExterminateBuff):IsUp()
end

--- 检查玩家是否正在维持冰龙吐息
---@return boolean
local function IsBreathing()
    if Player:GetAuras():FindMy(BreathOfSindragosaBuff):IsUp() then
        return true
    end
    -- 延迟双重保护：若1.5秒内刚施放过吐息，也认为正在吐息中，防止底层Buff延迟挂上导致瞬间泄能
    if BreathOfSindragosa.lastCastAt and (GetTime() - BreathOfSindragosa.lastCastAt) < 1.5 then
        return true
    end
    return false
end

--- 检查目标身上是否有冰霜疫病
---@return boolean
local function HasFrostFever()
    return Target:GetAuras():FindMy(FrostFeverDebuff):IsUp()
end

--- 获取玩家自身周围的敌人数量 (近战AOE以玩家为中心)
---@param range number
---@return number
local function GetEnemyCount(range)
    range = range or 8
    local count = 0
    Bastion.UnitManager:EnumUnits(function(unit)
        if unit:IsAlive() and unit:IsEnemy() and Player:IsWithinCombatDistance(unit, range) then
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
    -- 正在施法中则跳过
    if Player:IsCastingOrChanneling() then return end

    -- 目标验证
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- 自动攻击
    if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
        AutoAttack:Cast(Target)
    end

    -- ==================================================================
    -- ==================================================================
    -- 打断逻辑 (心灵冰冻)
    -- ==================================================================
    if M:GetSetting("useInterrupt") and MindFreeze:IsKnownAndUsable() then
        if Target:IsInterruptibleAt(M:GetSetting("interruptPercent"), false) then
            if MindFreeze:IsInRange(Target) and Player:IsFacing(Target) then
                if MindFreeze:Cast(Target) then return end
            end
        end
    end

    -- ==================================================================
    -- 防御/自保逻辑
    -- ==================================================================
    local currentHP = Player:GetHP()

    -- 冰封之韧 (大减伤)
    if M:GetSetting("useIBF") and currentHP <= M:GetSetting("ibfHP") then
        if IceboundFortitude:IsKnownAndUsable() then
            if IceboundFortitude:Cast(Player) then return end
        end
    end

    -- 巫妖之躯 (吸血/免控)
    if M:GetSetting("useLichborne") and currentHP <= M:GetSetting("lichborneHP") then
        if Lichborne:IsKnownAndUsable() then
            if Lichborne:Cast(Player) then return end
        end
    end

    -- 反魔法护罩 (魔法吸收)
    if M:GetSetting("useAMS") and currentHP <= M:GetSetting("amsHP") then
        if AntiMagicShield:IsKnownAndUsable() then
            -- 也可以在承受魔法伤害时施放，此处以血量为基础自保
            if AntiMagicShield:Cast(Player) then return end
        end
    end

    -- 灵界打击 (核心回血, 危急时在非吐息期间或者还有富余能量时使用)
    if currentHP <= M:GetSetting("deathStrikeHP") and DeathStrike:IsKnownAndUsable() then
        local runicPower = Player:GetPower(6) or 0
        -- 灵界打击消耗45符能。吐息期间如非生命垂危(低于30%血)则避免使用以维持吐息，这里做了兼顾
        if runicPower >= 45 and (not IsBreathing() or currentHP < 30) then
            if DeathStrike:IsInRange(Target) and Player:IsFacing(Target) then
                if DeathStrike:Cast(Target) then return end
            end
        end
    end

    -- ==================================================================
    -- 资源状态获取
    -- ==================================================================
    local runes = Player:GetPower(5) or 0         -- 当前可用符文数
    local runicPower = Player:GetPower(6) or 0     -- 当前符文能量
    local enemyCount = GetEnemyCount(8)           -- 8码内敌人数量
    local useCDs = M:GetSetting("useCooldowns")
    local useAOE = M:GetSetting("useAOE")
    local aoeThreshold = M:GetSetting("aoeTargets")
    local isAOEMode = useAOE and enemyCount >= aoeThreshold



    -- ==================================================================
    -- 爆发与大招判定 (开启冰龙吐息/死神印记/冰柱)
    -- ==================================================================
    if useCDs then
        -- 召唤亡者复生 (常驻增益CD)
        if RaiseDead:IsKnownAndUsable() then
            if RaiseDead:Cast(Player) then return end
        end

        -- 冰龙吐息激活判定：
        -- 如果开启了自动吐息，且吐息可用，且能量较为充沛（建议 >= 70点能量），则施放开启吐息！
        if M:GetSetting("useBreath") and BreathOfSindragosa:IsKnown() and not BreathOfSindragosa:IsOnCooldown() and not IsBreathing() then
            if runicPower >= 70 and (Player:InMelee(Target) or Player:IsWithinCombatDistance(Target, 8)) then
                if BreathOfSindragosa:Cast(Player) then return end
            end
        end

        -- 死神印记与冰霜之柱爆发逻辑：
        -- 1. 优先施放死神印记（核心爆发前置技能，消耗1个符文且占GCD，需要面向）
        if runes >= 1 and ReapersMark:IsKnownAndUsable() and ReapersMark:IsInRange(Target) and Player:IsFacing(Target) then
            if ReapersMark:Cast(Target) then return end
        end

        -- 2. 接着施放冰霜之柱（核心爆击增益，不占GCD，移除距离限制以对齐死神印记）
        if PillarOfFrost:IsKnownAndUsable() then
            if PillarOfFrost:Cast(Player) then return end
        end

        -- 3. 在平稳期如果资源匮乏，也积极使用符文武器增效 (WCL显示其使用频率极高)
        if not IsBreathing() and EmpowerRuneWeapon:IsKnownAndUsable() then
            if runes < 2 and runicPower < 40 then
                if EmpowerRuneWeapon:Cast(Player) then return end
            end
        end
    end

    -- ==================================================================
    -- 冰龙吐息持续期间 the 优先级逻辑 (IsBreathing() == true)
    -- ==================================================================
    if IsBreathing() then
        -- 此时我们的第一要务是：【绝不能断能量，同时尽可能高伤害】

        -- [资源补充] 当符文和符能都不充足时（符文 < 3 且 能量 < 60），积极使用符文武器增效补资源
        if useCDs and EmpowerRuneWeapon:IsKnownAndUsable() then
            if runes < 3 and runicPower < 60 then
                if EmpowerRuneWeapon:Cast(Player) then return end
            end
        end

        -- [优先级1] 泄符文换能量：当符文充足且符能相对安全（符能 < 75 避免溢出）时：
        -- 打湮灭/冰霜之镰消耗符文以产出大量符能
        if runes >= 1 and runicPower < 75 then
            if isAOEMode and HasKillingMachine() and Frostscythe:IsKnownAndUsable() then
                if runes >= 1 and Frostscythe:IsInRange(Target) and Player:IsFacing(Target) and Frostscythe:Cast(Target) then return end
            end
            if runes >= 2 and Obliterate:IsInRange(Target) and Player:IsFacing(Target) and Obliterate:Cast(Target) then return end
        end

        -- [优先级2] 破灭触发：若身上有破灭BUFF（伤害极高且省符文），在不溢出符能的情况下使用湮灭消耗
        if HasExterminate() and runicPower < 85 then
            if Obliterate:IsInRange(Target) and Player:IsFacing(Target) and Obliterate:Cast(Target) then return end
        end

        -- [优先级3] 白霜触发：有白霜BUFF时打免费的凛风冲击
        -- 注意：如果能量极其危险（<35），应该优先打湮灭生能，此时暂不打白霜。
        if HasRime() and runicPower >= 35 and HowlingBlast:IsKnownAndUsable() then
            if HowlingBlast:IsInRange(Target) and Player:IsFacing(Target) and HowlingBlast:Cast(Target) then return end
        end

        -- [优先级4] 刷新疫病：如果目标身上没有冰霜疫病，在能量安全时用凛风冲击补
        if not HasFrostFever() and runicPower >= 40 and HowlingBlast:IsKnownAndUsable() then
            if HowlingBlast:IsInRange(Target) and Player:IsFacing(Target) and HowlingBlast:Cast(Target) then return end
        end

        -- [优先级5] 符文富余但溢出防范：如果符能很高且符文全满，即使溢出也打一个湮灭防止符文闲置
        if runes >= 5 and Obliterate:IsInRange(Target) and Player:IsFacing(Target) then
            if Obliterate:Cast(Target) then return end
        end

        -- 吐息期间绝不在非溢出时打其他耗能技能（如冰打、冰川），能量被吐息自动消耗
        return
    end

    -- ==================================================================
    -- 非吐息平稳期的优先级逻辑
    -- ==================================================================

    -- [优先级1] 破灭触发：破灭BUFF可用时打强化湮灭 (破灭不消耗符文，核心伤害)
    if HasExterminate() and Obliterate:IsInRange(Target) and Player:IsFacing(Target) then
        if Obliterate:Cast(Target) then return end
    end

    -- [优先级2] 保持疫病：若目标没有冰霜疫病，优先打凛风冲击施加
    if not HasFrostFever() and HowlingBlast:IsKnownAndUsable() and HowlingBlast:IsInRange(Target) and Player:IsFacing(Target) then
        if HowlingBlast:Cast(Target) then return end
    end

    -- [优先级3] 杀戮机器触发：杀戮机器使湮灭必爆
    if HasKillingMachine() then
        -- AOE 模式下，有杀戮机器且点了冰镰，打冰霜之镰 (消耗1个符文)
        if isAOEMode and runes >= 1 and Frostscythe:IsKnownAndUsable() and Frostscythe:IsInRange(Target) and Player:IsFacing(Target) then
            if Frostscythe:Cast(Target) then return end
        end
        -- 否则，打湮灭 (常规消耗2个符文)
        if runes >= 2 and Obliterate:IsInRange(Target) and Player:IsFacing(Target) and Obliterate:Cast(Target) then return end
    end

    -- [优先级4] 白霜触发：触发白霜BUFF打免费的高伤凛风冲击
    if HasRime() and HowlingBlast:IsKnownAndUsable() and HowlingBlast:IsInRange(Target) and Player:IsFacing(Target) then
        if HowlingBlast:Cast(Target) then return end
    end

    -- [优先级5] 能量倾泄：当符能较高（>= 75点），或者符文全部冷却完时进行泄能，获取符文强化被动
    -- 核心防守：若吐息准备就绪且未开启，系统进入蓄能阶段（Pooling），此时绝对禁止提前倾泄符能，全力积攒至 70 能量以开启吐息！
    local isPoolingForBreath = M:GetSetting("useCooldowns") and M:GetSetting("useBreath") and BreathOfSindragosa:IsKnown() and not BreathOfSindragosa:IsOnCooldown() and not IsBreathing()
    if not isPoolingForBreath and (runicPower >= 75 or (runes < 2 and runicPower >= 40)) then
        -- AOE 模式下使用冰川突进 (严格限制：只有目标数量明显较多时才打，防止误判导致单体丢失伤害)
        if isAOEMode and enemyCount >= 3 and GlacialAdvance:IsKnownAndUsable() and GlacialAdvance:IsInRange(Target) and Player:IsFacing(Target) then
            if GlacialAdvance:Cast(Target) then return end
        end
        -- 默认及主目标使用冰霜打击 (严格匹配 WCL 中 12.8 CPM 的高频使用率)
        if FrostStrike:IsKnownAndUsable() and FrostStrike:IsInRange(Target) and Player:IsFacing(Target) then
            if FrostStrike:Cast(Target) then return end
        end
    end

    -- [优先级6] 符文消耗：当可用符文较多（>= 2）时，使用湮灭攒能并打伤害
    if runes >= 2 and Obliterate:IsInRange(Target) and Player:IsFacing(Target) then
        if Obliterate:Cast(Target) then return end
    end
end)

Bastion:Register(M)
return M
