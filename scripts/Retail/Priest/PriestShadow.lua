local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义
-- ======================================================================
local PowerWordFortitude = SpellBook:GetSpell(21562) -- 真言术：韧
local Shadowform       = SpellBook:GetSpell(232698) -- 暗影形态
local PowerInfusion    = SpellBook:GetSpell(10060)  -- 能量灌注

local Dispersion       = SpellBook:GetSpell(47585)  -- 消散
local DesperatePrayer  = SpellBook:GetSpell(19236)  -- 绝望祷言
local VampiricEmbrace  = SpellBook:GetSpell(15286)  -- 吸血鬼的拥抱
local Silence          = SpellBook:GetSpell(15487)  -- 沉默

local VampiricTouch    = SpellBook:GetSpell(34914)  -- 吸血鬼之触
local ShadowWordPain   = SpellBook:GetSpell(589)    -- 暗言术：痛
local DevouringPlague  = SpellBook:GetSpell(335467) -- 暗言术：癫 (原暗言术：噬，国服和谐与重做后的ID)
local MindBlast        = SpellBook:GetSpell(8092)   -- 心灵震爆 (虚空织源者会变成虚空冲击)
local VoidTorrent      = SpellBook:GetSpell(263165) -- 虚空洪流
local ShadowWordDeath  = SpellBook:GetSpell(32379)  -- 暗言术：灭
local MindFlay         = SpellBook:GetSpell(15407)  -- 精神鞭笞
local ShadowCrashBase  = SpellBook:GetSpell(205385) -- 暗影冲撞
local TentacleSlam     = SpellBook:GetSpell(1227280)-- 触须猛击 (英雄天赋替换)

local VoidformActive   = SpellBook:GetSpell(228260) -- 虚空形态 / 虚空齐射 (变身期间自动替换)
local Shadowfiend      = SpellBook:GetSpell(34433)  -- 暗影魔
local Mindbender       = SpellBook:GetSpell(200174) -- 摧心魔 (即使暗影魔被动化，如果有摧心魔仍为主动天赋)

-- ======================================================================
-- Buff / Debuff 定义
-- ======================================================================
local FortitudeBuff       = SpellBook:GetSpell(21562) -- 韧 Buff
local ShadowformBuff      = SpellBook:GetSpell(232698) -- 暗影形态 Buff
local VampiricTouchDebuff = SpellBook:GetSpell(34914) -- 触 Debuff
local VoidformBuff        = SpellBook:GetSpell(194249) -- 虚空形态 Buff

-- ======================================================================
-- 模块注册与设置
-- ======================================================================
local M = Bastion.Module:New("PriestShadow")
M:SetDisplayName("Shadow Priest", "暗影牧师 (虚空织源者)")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CIQAAAAAAAAAAAAAAAAAAAAAAMjZMGAAAAAAAAAAAAjZZmxYZmxMz2MDjZ2mZGzMzMQmhtZaMwMzMAQAmtZbDMbMAwgZmZmxsNmBzMYGMA"
            if C_Keybindings and C_Keybindings.CopyToClipboard then
                if C_Keybindings.CopyToClipboard(talentStr) then
                    Bastion:Print("|cFF00FF00[推荐天赋]|r 暗影牧师天赋导出字符串已成功复制到系统剪贴板！可以直接在游戏内导入。")
                    return
                end
            end
            StaticPopupDialogs["BASTION_COPY_PRIEST_TALENTS"] = {
                text = "请按 Ctrl+C 复制推荐暗影牧师配置天赋：",
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
            StaticPopup_Show("BASTION_COPY_PRIEST_TALENTS")
            Bastion:Print("|cFFFFCC00[推荐天赋]|r 已拉起复制框，请按 Ctrl+C 复制推荐暗影牧师天赋。")
        end
    },

    { type = "header", label = "== Auto Cooldowns ==", labelZh = "== 爆发技能开关 ==" },
    {
        type = "toggle",
        key = "useVoidform",
        label = "Use Voidform",
        labelZh = "自动使用虚空形态",
        default = true
    },
    {
        type = "toggle",
        key = "usePowerInfusion",
        label = "Use Power Infusion",
        labelZh = "自动对自己使用能量灌注",
        default = true
    },

    { type = "header", label = "== Rotation Settings ==", labelZh = "== 输出循环设置 ==" },
    {
        type = "slider",
        key = "aoeThreshold",
        label = "AOE Target Threshold",
        labelZh = "AOE目标数阈值",
        min = 2, max = 5, step = 1,
        default = 3
    },

    { type = "header", label = "== Defensive Settings ==", labelZh = "== 自保设置 ==" },
    {
        type = "slider",
        key = "dispersionHP",
        label = "Dispersion HP%",
        labelZh = "消散开启血量%",
        min = 10, max = 80, step = 5,
        default = 25
    },
    {
        type = "slider",
        key = "desperatePrayerHP",
        label = "Desperate Prayer HP%",
        labelZh = "绝望祷言开启血量%",
        min = 10, max = 80, step = 5,
        default = 40
    },
    {
        type = "slider",
        key = "vampiricEmbraceHP",
        label = "Vampiric Embrace HP%",
        labelZh = "吸血鬼的拥抱开启血量%",
        min = 10, max = 90, step = 5,
        default = 50
    }
})

-- ======================================================================
-- 辅助函数
-- ======================================================================
local function GetInsanity()
    return Player:GetPower(13) -- 13 是狂乱值 (Insanity)
end

-- 检查目标附近敌人数量 (以目标为中心, AOE 落点判断)
local function GetEnemyCount(range)
    range = range or 8
    local count = 0
    Bastion.UnitManager:EnumUnits(function(unit)
        if unit:IsAlive() and unit:IsEnemy() and Target:GetDistance(unit) <= range then
            count = count + 1
        end
        return false
    end)
    return count
end

-- 获取 AOE 挂 DoT 技能 (触须猛击 > 暗影冲撞)
local function GetShadowCrash()
    if TentacleSlam:IsKnown() then return TentacleSlam end
    return ShadowCrashBase
end

-- 处理打断
local function HandleInterrupts()
    -- 焦点打断优先
    local focus = Bastion.UnitManager:Get('focus')
    if focus:IsValid() and focus:IsEnemy() and focus:IsInterruptible() then
        if Silence:IsInRange(focus) and Player:IsFacing(focus) and Player:CanSee(focus) then
            if Silence:Cast(focus) then
                Bastion:Print("|cFF00FF00[打断]|r 施放沉默打断焦点目标 -> " .. focus:GetName())
                return true
            end
        end
    end

    -- 当前目标打断
    if Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() then
        if Silence:IsInRange(Target) and Player:IsFacing(Target) and Player:CanSee(Target) then
            if Silence:Cast(Target) then
                Bastion:Print("|cFF00FF00[打断]|r 施放沉默打断当前目标 -> " .. Target:GetName())
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
    -- 1. 施法保护与引导打断 (Clipping) 逻辑
    local isCastingOrChanneling = Player:IsCastingOrChanneling()
    local currentSpell = isCastingOrChanneling and Player:GetCastingOrChannelingSpell() or nil
    local isChannelingMindFlay = (currentSpell and currentSpell:GetID() == 15407)
    
    -- 如果正在施法或引导，并且【不是】可以被打断的填充技能（精神鞭笞），则锁定循环不施法
    if isCastingOrChanneling and not isChannelingMindFlay then
        return
    end

    -- ==================== 脱战与团队增益 ====================
    -- 保持暗影形态
    if not Player:GetAuras():FindMy(ShadowformBuff) then
        if Shadowform:Cast(Player) then return end
    end

    -- 保持真言术：韧
    local fortitude = Player:GetAuras():FindMy(FortitudeBuff)
    if not fortitude or fortitude:GetRemainingTime() < 300 then
        if PowerWordFortitude:Cast(Player) then return end
    end

    -- ==================== 自动防守与打断 ====================
    if Player:GetHealthPercent() <= M:GetSetting("dispersionHP") then
        if Dispersion:Cast(Player) then
            Bastion:Print("|cFF00FFFF[减伤]|r 血量危急，自动开启消散！")
            return
        end
    end

    if Player:GetHealthPercent() <= M:GetSetting("desperatePrayerHP") then
        if DesperatePrayer:Cast(Player) then
            Bastion:Print("|cFF00FFFF[自疗]|r 自动开启绝望祷言！")
            return
        end
    end

    if Player:GetHealthPercent() <= M:GetSetting("vampiricEmbraceHP") then
        if VampiricEmbrace:Cast(Player) then
            Bastion:Print("|cFF00FFFF[团队回血]|r 自动开启吸血鬼的拥抱！")
            return
        end
    end

    -- 必须有有效敌对目标
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 自动打断
    if HandleInterrupts() then return end

    -- 必须面向目标且在视野内才能放攻击法术
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    local inCombat = Player:IsAffectingCombat()
    local insanity = GetInsanity()
    local isMoving = Player:IsMoving()
    local enemyCount = GetEnemyCount(10)
    local aoeThreshold = M:GetSetting("aoeThreshold")
    local isAOE = enemyCount >= aoeThreshold

    -- ==================== 1. 爆发大招 (Cooldowns) ====================
    if inCombat and (Target:GetHealthPercent() > 20 or Target:IsBoss()) then
        if M:GetSetting("usePowerInfusion") then
            if PowerInfusion:Cast(Player) then
                Bastion:Print("|cFF00FFFF[爆发]|r 开启能量灌注！")
                return
            end
        end

        if M:GetSetting("useVoidform") then
            -- 绕过 Spell:Cast 内部的 CastSpellByName，直接在底层调用 ID 施放。
            -- 暴雪底层会自动根据形态（虚空形态/虚空齐射）判定释放结果。
            if VoidformActive:IsInRange(Target) then
                -- local hasVoidform = Player:GetAuras():FindMy(VoidformBuff)
                -- 如果在虚空形态（瞬发齐射）可以移动施法；如果是基础爆发（读条）则需站定
                if not isMoving then
                    C_Timer.TCX.Unlock("CastSpellByID", 228260, Target:GetOMToken())
                    -- VoidformActive.lastCastAttempt = GetTime()
                    --return
                end
            end
        end
    end

    -- ==================== 2. 核心输出循环 (Core Rotation) ====================
    
    -- 2.1 AOE环境：暗影冲撞/触须猛击 (地面选点技能)
    -- 如果侦测到多目标，且技能可用，使用 Cast(nil) + Click 精准群挂 DoT
    local crashSpell = GetShadowCrash()
    if isAOE and crashSpell:IsKnown() then
        if Target:GetDistance() <= 40 then
            if crashSpell:Cast(nil) then
                crashSpell:Click(Target:GetPosition())
                return
            end
        end
    end

    -- 2.2 维持主目标 DoT (吸血鬼之触自带暗言术：痛)
    local vtDebuff = Target:GetAuras():FindMy(VampiricTouchDebuff)
    if not vtDebuff or not vtDebuff:IsUp() or vtDebuff:GetRemainingTime() <= 6.3 then
        -- 吸血鬼之触需要读条
        if not isMoving and VampiricTouch:IsInRange(Target) then
            if VampiricTouch:Cast(Target) then return end
        end
    end
    -- 2.3 暗言术：痛
    local swpDebuff = Target:GetAuras():FindMy(ShadowWordPain)
    if not swpDebuff or not swpDebuff:IsUp() or swpDebuff:GetRemainingTime() <= 0.5 then
        if ShadowWordPain:IsInRange(Target) then
            if ShadowWordPain:Cast(Target) then return end
        end
    end

    -- 2.4 泄能防溢出 (暗言术：癫/噬)
    if insanity >= 45 then
        if DevouringPlague:IsInRange(Target) then
            if DevouringPlague:Cast(Target) then return end
        end
    end

    -- 2.5 虚空洪流 (虚空织源者核心机制，开启熵能裂隙)
    if not isMoving and VoidTorrent:IsInRange(Target) then
        if VoidTorrent:Cast(Target) then return end
    end

    -- 2.6 斩杀核心 (暗言术：灭)
    -- 绝对核心被动：对血量 <= 20% 的目标施放可召唤暗影魔！绝不能在平时随意使用浪费 CD！
    if Target:GetHealthPercent() <= 20 then
        if ShadowWordDeath:IsInRange(Target) then
            if ShadowWordDeath:Cast(Target) then return end
        end
    end

    -- 2.7 心灵震爆 / 虚空冲击 (裂隙期间自动替换)
    if not isMoving and MindBlast:IsInRange(Target) then
        if MindBlast:Cast(Target) then return end
    end

    -- 2.8 终极填充 (精神鞭笞)
    -- 如果当前已经在引导精神鞭笞，不要重复施放以避免空耗蓝量和 GCD
    if not isMoving and not isChannelingMindFlay and MindFlay:IsInRange(Target) then
        if MindFlay:Cast(Target) then return end
    end

end)

Bastion:Register(M)
return M
