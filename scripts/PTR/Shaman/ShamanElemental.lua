local tcx, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义
-- ======================================================================
local LightningBolt    = SpellBook:GetSpell(188196) -- 闪电箭 (会被替换为狂风怒号)
local ChainLightning   = SpellBook:GetSpell(188443) -- 闪电链
local LavaBurst        = SpellBook:GetSpell(51505)  -- 熔岩爆裂
local FlameShock       = SpellBook:GetSpell(188389) -- 烈焰震击
local Earthquake       = SpellBook:GetSpell(61882)  -- 地震术
local ElementalBlast   = SpellBook:GetSpell(117014) -- 元素冲击
local EarthShock       = SpellBook:GetSpell(8042)   -- 大地震击 (备用，未点元素冲击时使用)

local FireElemental    = SpellBook:GetSpell(198067) -- 火元素
local StormElemental   = SpellBook:GetSpell(192249) -- 风暴元素
local Ascendance       = SpellBook:GetSpell(114050) -- 升腾
local Stormkeeper      = SpellBook:GetSpell(191634) -- 风暴守护者

local WindShear        = SpellBook:GetSpell(57994)  -- 风剪 (打断)
local AstralShift      = SpellBook:GetSpell(108271) -- 星界转移 (减伤)
local Spiritwalker     = SpellBook:GetSpell(79206)  -- 灵魂行者的恩赐

local Skyfury          = SpellBook:GetSpell(462854) -- 天怒 (团队Buff)
local EarthElemental   = SpellBook:GetSpell(198103) -- 土元素
local CapacitorTotem   = SpellBook:GetSpell(192058) -- 电能图腾

-- ======================================================================
-- Buff / Debuff 定义
-- ======================================================================
local FlameShockDebuff   = SpellBook:GetSpell(188389) -- 烈焰震击 DOT
local LavaSurgeBuff      = SpellBook:GetSpell(77762)  -- 熔岩奔腾 (瞬发熔岩爆裂)
local AwakeningStorms    = SpellBook:GetSpell(454009) -- 觉醒风暴 (使下一个闪电箭变成狂风怒号)
local SurgeOfPowerBuff   = SpellBook:GetSpell(260881) -- 能量湍流/流电炽焰 (使用地震/地震击后触发)
local SkyfuryBuff        = SpellBook:GetSpell(462854) -- 天怒 Buff
local StormkeeperBuff    = SpellBook:GetSpell(191840) -- 风暴守护者 Buff
local AscendanceBuff     = SpellBook:GetSpell(114050) -- 升腾 Buff

-- ======================================================================
-- 模块注册与设置
-- ======================================================================
local M = Bastion.Module:New("ShamanElemental")
M:SetDisplayName("Elemental Shaman", "元素萨满 (风暴使者)")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CYQAAAAAAAAAAAAAAAAAAAAAAAAAAAzMbbzMzYML2mhZMzAAAAAAbmxwGsAzwQjNAY2mZmxYZxEmZ2GLzMzMmxilZsYmZMzCAwAYmBGGG"
            if C_Keybindings and C_Keybindings.CopyToClipboard then
                if C_Keybindings.CopyToClipboard(talentStr) then
                    Bastion:Print("|cFF00FF00[推荐天赋]|r 元素萨满天赋导出字符串已成功复制到系统剪贴板！可以直接在游戏内导入。")
                    return
                end
            end
            StaticPopupDialogs["BASTION_COPY_SHAMAN_TALENTS"] = {
                text = "请按 Ctrl+C 复制推荐元素萨满配置天赋：",
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
            StaticPopup_Show("BASTION_COPY_SHAMAN_TALENTS")
            Bastion:Print("|cFFFFCC00[推荐天赋]|r 已拉起复制框，请按 Ctrl+C 复制推荐元素萨满天赋。")
        end
    },

    { type = "header", label = "== Auto Cooldowns ==", labelZh = "== 爆发技能开关 ==" },
    {
        type = "toggle",
        key = "useAscendance",
        label = "Use Ascendance",
        labelZh = "自动使用升腾",
        default = true
    },
    {
        type = "toggle",
        key = "useElemental",
        label = "Use Fire/Storm Elemental",
        labelZh = "自动使用火/风暴元素",
        default = true
    },
    {
        type = "toggle",
        key = "useStormkeeper",
        label = "Use Stormkeeper",
        labelZh = "自动使用风暴守护者",
        default = true
    },
    {
        type = "toggle",
        key = "useSpiritwalker",
        label = "Use Spiritwalker's Grace",
        labelZh = "移动时自动开启灵魂行者",
        default = true
    },
    
    { type = "header", label = "== Totems & Utility ==", labelZh = "== 图腾与辅助 ==" },
    {
        type = "toggle",
        key = "autoCapacitor",
        label = "Auto Capacitor Totem (3+ targets)",
        labelZh = "自动电能图腾群晕(3目标及以上)",
        default = false
    },
    {
        type = "toggle",
        key = "autoSkyfury",
        label = "Auto Skyfury Buff",
        labelZh = "自动保持天怒Buff",
        default = true
    },
    {
        type = "slider",
        key = "earthElementalHP",
        label = "Earth Elemental HP%",
        labelZh = "土元素护驾血量%",
        min = 0, max = 50, step = 5,
        default = 20
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
        key = "astralShiftHP",
        label = "Astral Shift HP%",
        labelZh = "星界转移开启血量%",
        min = 10, max = 80, step = 5,
        default = 35
    }
})

-- ======================================================================
-- 辅助函数
-- ======================================================================
local function GetMaelstrom()
    return Player:GetPower(11) -- 11 是漩涡值 (Maelstrom)
end

--- 检查目标附近敌人数量 (以目标为中心, AOE 落点判断)
--- 使用 EnumUnits (遍历所有敌方单位) 而非 GetEnemies (仅遍历 activeEnemies)
--- activeEnemies 需要 InCombatOdds>80, 可能漏掉大量未建立仇恨的怪物
---@param range number
---@return number
local function GetEnemyCount(range)
    range = range or 8
    local count = 0
    Bastion.UnitManager:EnumUnits(function(unit)
        if unit:IsAlive() and unit:IsEnemy() and Target:IsWithinCombatDistance(unit, range) then
            count = count + 1
        end
        return false
    end)
    return count
end

-- 处理打断
local function HandleInterrupts()
    -- 风剪打断交由Cast内部去判定CD和可用状态

    -- 焦点打断优先
    local focus = Bastion.UnitManager:Get('focus')
    if focus:IsValid() and focus:IsEnemy() and focus:IsInterruptible() then
        if WindShear:IsInRange(focus) and Player:IsFacing(focus) and Player:CanSee(focus) then
            if WindShear:Cast(focus) then
                Bastion:Print("|cFF00FF00[打断]|r 施放风剪打断焦点目标 -> " .. focus:GetName())
                return true
            end
        end
    end

    -- 当前目标打断
    if Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() then
        if WindShear:IsInRange(Target) and Player:IsFacing(Target) and Player:CanSee(Target) then
            if WindShear:Cast(Target) then
                Bastion:Print("|cFF00FF00[打断]|r 施放风剪打断当前目标 -> " .. Target:GetName())
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
    -- 施法中不打断当前施法
    if Player:IsCastingOrChanneling() then return end

    -- ==================== 脱战与团队增益 ====================
    if M:GetSetting("autoSkyfury") then
        local skyBuff = Player:GetAuras():FindMy(SkyfuryBuff)
        if not skyBuff or skyBuff:GetRemainingTime() < 300 then
            -- 没buff或者剩余不足5分钟则补天怒
            if Skyfury:Cast(Player) then return end
        end
    end

    -- 自动减伤与土元素护驾
    if Player:GetHealthPercent() <= M:GetSetting("astralShiftHP") then
        if AstralShift:Cast(Player) then
            Bastion:Print("|cFF00FFFF[减伤]|r 血量危急，自动开启星界转移！")
            return
        end
    end
    
    local earthHP = M:GetSetting("earthElementalHP")
    if earthHP > 0 and Player:GetHealthPercent() <= earthHP then
        if EarthElemental:Cast(Player) then
            Bastion:Print("|cFF8B4513[自保]|r 血量极低，召唤土元素护驾！")
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
    local maelstrom = GetMaelstrom()
    local enemyCount = GetEnemyCount(10)
    local aoeThreshold = M:GetSetting("aoeThreshold")
    local isAOE = enemyCount >= aoeThreshold

    -- 自动电能图腾 (群晕)
    if inCombat and isAOE and M:GetSetting("autoCapacitor") then
        if Player:IsWithinCombatDistance(Target, 30) then
            if CapacitorTotem:Cast(nil) then
                CapacitorTotem:Click(Target:GetPosition())
                Bastion:Print("|cFF00FF00[控制]|r 目标过多，自动施放电能图腾群晕！")
                return
            end
        end
    end

    -- ==================== 1. 爆发技能 (Cooldowns) ====================
    if inCombat then
        if M:GetSetting("useElemental") then
            if StormElemental:Cast(Player) then return end
            if FireElemental:Cast(Player) then return end
        end

        if M:GetSetting("useAscendance") then
            if Ascendance:Cast(Player) then
                Bastion:Print("|cFFFFD700[爆发]|r 开启升腾！")
                return
            end
        end

        if M:GetSetting("useStormkeeper") then
            if Stormkeeper:Cast(Player) then
                Bastion:Print("|cFF00FFFF[爆发]|r 开启风暴守护者！")
                return
            end
        end
    end

    -- ==================== 2. 核心输出优先级 ====================
    local hasTempest = Player:GetAuras():FindMy(AwakeningStorms)
    local hasStormkeeper = Player:GetAuras():FindMy(StormkeeperBuff)
    local hasAscendance = Player:GetAuras():FindMy(AscendanceBuff)
    local hasSurgeOfPower = Player:GetAuras():FindMy(SurgeOfPowerBuff)
    local hasLavaSurge = Player:GetAuras():FindMy(LavaSurgeBuff)
    local hasSpiritwalker = Player:GetAuras():FindMy(Spiritwalker)
    
    local tempestUp = hasTempest and hasTempest:IsUp()
    local skUp = hasStormkeeper and hasStormkeeper:IsUp()
    local ascUp = hasAscendance and hasAscendance:IsUp()
    local sopUp = hasSurgeOfPower and hasSurgeOfPower:IsUp()
    local lsUp = hasLavaSurge and hasLavaSurge:IsUp()
    local swUp = hasSpiritwalker and hasSpiritwalker:IsUp()

    local isMoving = Player:IsMoving()
    local canCastNonInstant = not isMoving or swUp

    -- 移动时自动开启灵魂行者
    if isMoving and inCombat and not swUp then
        if M:GetSetting("useSpiritwalker") then
            if Spiritwalker:Cast(Player) then
                Bastion:Print("|cFF00FFFF[移动]|r 自动开启灵魂行者的恩赐！")
                return
            end
        end
    end

    -- 2.1 终结技泄能 (防溢出最高优：AOE地震术 / 单体元素冲击)
    -- AOE 时使用地震术 (消耗 55 漩涡)
    if isAOE and maelstrom >= 55 then
        -- 核心Bug就在这里：地面法术的 IsInRange 会被暴雪API返回 nil，导致框架底层把它当成了近战技能！
        if Player:IsWithinCombatDistance(Target, 40) then
            -- 必须用 Cast(nil) 来绕过底层框架内部对 Target 的二次 IsInRange 校验
            if Earthquake:Cast(nil) then
                Earthquake:Click(Target:GetPosition())
                return
            end
        end
    end

    -- 单体终结技泄能
    -- WCL标准手法：如果点了元素冲击，大地震击被替换。元素冲击CD期间如果漩涡满了，直接让它溢出，继续打闪电箭/狂风怒号。不应该打地震术浪费GCD。
    if not isAOE then
        if maelstrom >= 75 and canCastNonInstant and ElementalBlast:IsInRange(Target) then
            if ElementalBlast:Cast(Target) then return end
        -- 如果没点元素冲击天赋，则使用基础的大地震击泄能
        elseif maelstrom >= 50 and EarthShock:IsInRange(Target) then
            if EarthShock:Cast(Target) then return end
        end
    end

    -- 2.2 狂风怒号 (觉醒风暴 Buff 存在时)
    if tempestUp and canCastNonInstant then
        if LightningBolt:IsInRange(Target) then
            if LightningBolt:Cast(Target) then
                Bastion:Print("|cFF00BFFF[风暴使者]|r 施放狂风怒号 (Tempest)！")
                return
            end
        end
    end

    -- 2.3 风暴守护者 (瞬发且增伤闪电箭/闪电链，无视移动)
    if skUp then
        if isAOE then
            if ChainLightning:IsInRange(Target) and ChainLightning:Cast(Target) then return end
        else
            if LightningBolt:IsInRange(Target) and LightningBolt:Cast(Target) then return end
        end
    end

    -- 2.4 保持主目标烈焰震击 (瞬发，无视移动)
    local flameShockDebuff = Target:GetAuras():FindMy(FlameShockDebuff)
    if not flameShockDebuff or not flameShockDebuff:IsUp() or flameShockDebuff:GetRemainingTime() <= 5.4 then
        if FlameShock:IsInRange(Target) then
            if FlameShock:Cast(Target) then return end
        end
    end



    -- 2.5 熔岩爆裂
    -- 如果有能量湍流(SOP)，留给闪电箭/闪电链触发过载
    if not sopUp then
        if isAOE then
            -- AOE环境下，单体熔岩爆裂(即使瞬发)的收益也不如闪电链(多目标伤害+海量漩涡值用于地震术)
            -- 因此在AOE中，只有处于升腾期间(熔岩爆裂会自动击中所有带火震的目标)才打熔岩爆裂
            if ascUp then
                if LavaBurst:IsInRange(Target) then
                    if LavaBurst:Cast(Target) then return end
                end
            end
        else
            -- 单体环境下：如果有熔岩奔腾(lsUp)则是瞬发，无视移动；否则判断是否可以读条防溢出
            if lsUp or (canCastNonInstant and (ascUp or LavaBurst:GetCharges() == 2)) then
                if LavaBurst:IsInRange(Target) then
                    if LavaBurst:Cast(Target) then return end
                end
            end
        end
    end

    -- 2.6 填充法术 (AOE用闪电链，单体用闪电箭，需读条)
    if canCastNonInstant then
        if isAOE then
            if ChainLightning:IsInRange(Target) then
                if ChainLightning:Cast(Target) then return end
            end
        else
            if LightningBolt:IsInRange(Target) then
                if LightningBolt:Cast(Target) then return end
            end
        end
    end

    -- 2.7 移动中无法读条时的最终备用方案 (冰霜震击)
    if isMoving then
        local FrostShock = SpellBook:GetSpell(196840)
        if FrostShock and FrostShock:IsInRange(Target) then
            if FrostShock:Cast(Target) then return end
        end
    end

end)

Bastion:Register(M)
return M
