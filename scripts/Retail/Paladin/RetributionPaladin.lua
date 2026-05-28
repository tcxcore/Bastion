local _, Bastion = ...

local _, englishClass = UnitClass("player")
if englishClass ~= "PALADIN" then return end

local RetributionModule = Bastion.Module:New('RetributionPaladin')
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

----------------------------------------------------------------------
-- UI 设置定义
----------------------------------------------------------------------
RetributionModule:SetDisplayName("Retribution Paladin", "惩戒骑 (圣殿骑士)")
RetributionModule:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CYEAAAAAAAAAAAAAAAAAAAAAAAAAAAAQz22MzsMmZGAAAAAAGlZZGmZsNMbDzsNjxYMMjN2GAAAzMtNzsNDAYDwAgxgZwMGzGWmBjZMjBD"
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
    
    { type = "header", label = "Burst Control", labelZh = "爆发控制" },
    { key = "use_cooldowns", type = "toggle", label = "Auto Burst (AW, ES, Toll)", labelZh = "自动爆发 (翅膀,处决,敲钟)", default = true },
    
    { type = "header", label = "AoE Settings", labelZh = "AoE 设置" },
    { key = "aoe_count", type = "slider", label = "Divine Storm Threshold", labelZh = "神圣风暴目标数", min = 2, max = 5, step = 1, default = 3 },
    
    { type = "header", label = "Interrupt Settings", labelZh = "打断设置" },
    { key = "auto_interrupt", type = "toggle", label = "Auto Rebuke", labelZh = "自动责难", default = true },
    
    { type = "header", label = "Defensives", labelZh = "防暴毙机制" },
    { key = "shield_hp", type = "slider", label = "Divine Shield HP%", labelZh = "圣盾术血量%", min = 0, max = 50, step = 5, default = 15 },
    { key = "vengeance_hp", type = "slider", label = "Shield of Vengeance HP%", labelZh = "复仇之盾血量%", min = 0, max = 80, step = 5, default = 40 },
})

----------------------------------------------------------------------
-- 技能定义
----------------------------------------------------------------------
-- 核心消耗
local FinalVerdict      = SpellBook:GetSpell(383328) -- 最终审判
local DivineStorm       = SpellBook:GetSpell(53385)  -- 神圣风暴

-- 核心产豆
local BladeOfJustice    = SpellBook:GetSpell(184575) -- 公正之剑 (产2)
local Judgment          = SpellBook:GetSpell(20271)  -- 审判 (产1)
local HammerOfWrath     = SpellBook:GetSpell(24275)  -- 愤怒之锤 (产1)

-- 爆发大招
local AvengingWrath     = SpellBook:GetSpell(31884)  -- 复仇之怒
local ExecutionSentence = SpellBook:GetSpell(343527) -- 处决宣判
local WakeOfAshes       = SpellBook:GetSpell(255937) -- 灰烬觉醒 (产3)
local HammerOfLight     = SpellBook:GetSpell(427453) -- 圣光之锤 (圣殿骑士大招，耗5)
local DivineToll        = SpellBook:GetSpell(375576) -- 圣洁鸣钟 (大量产豆)

-- 防御与打断
local Rebuke            = SpellBook:GetSpell(96231)  -- 责难
local DivineShield      = SpellBook:GetSpell(642)    -- 无敌
local ShieldOfVengeance = SpellBook:GetSpell(184662) -- 复仇之盾
local AutoAttack        = SpellBook:GetSpell(6603)

-- ======================================================================
-- BUFF / DEBUFF 定义
-- ======================================================================
local DivinePurposeBuff       = SpellBook:GetSpell(223819) -- 神圣意志 (免费消耗)
local EmpyreanPowerBuff       = SpellBook:GetSpell(326733) -- 至高天之力 (免费风暴)
local JudgmentDebuff          = SpellBook:GetSpell(197277) -- 审判易伤 (目标受到伤害增加)
local ExecutionSentenceDebuff = SpellBook:GetSpell(343527) -- 处决宣判 (目标积累伤害)
local HammerOfWrathBuff       = SpellBook:GetSpell(1241410) -- 愤怒之锤变异 BUFF (12.0.5)

----------------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------------
local function GetHolyPower()
    return Player:GetPower(9) or 0
end

local function HasDivinePurpose()
    return Player:GetAuras():FindMy(DivinePurposeBuff):IsUp()
end

local function HasEmpyreanPower()
    return Player:GetAuras():FindMy(EmpyreanPowerBuff):IsUp()
end

local function HasJudgmentDebuff()
    return Target:GetAuras():FindMy(JudgmentDebuff):IsUp()
end

local function HasExecutionSentenceDebuff()
    return Target:GetAuras():FindMy(ExecutionSentenceDebuff):IsUp()
end

-- ======================================================================
-- 12.0.5 变异机制核心修复：
-- 当审判变异为愤怒之锤时，通过法术名称施放“愤怒之锤”会被服务器拒绝（因为目标血量条件不满足）。
-- 玩家实测：游戏底层原生支持通过按键源法术 ID `CastSpellByID(20271)`，服务器会自动完美地转换为变异后的愤怒之锤。
-- 因此我们重写 Judgment 的施法函数，完全绕过框架内部写死的 CastSpellByName。
-- ======================================================================
function Judgment:Cast(unit, condition)
    if condition then
        if type(condition) == "string" and not self:EvaluateCondition(condition) then return false end
        if type(condition) == "function" and not condition(self) then return false end
    end

    if not self:Castable() then return false end

    if self:GetPreCastFunction() then self:GetPreCastFunction()(self) end

    self.wasLooking = IsMouselooking()
    
    -- 核心修复：强制使用 ID 施放 20271
    Bastion.TCX.Unlock("CastSpellByID", 20271, unit:GetOMToken())
    Bastion.TCX.Unlock("SpellCancelQueuedSpell")
    
    self.lastCastAttempt = GetTime()

    if self:GetOnCastFunction() then self:GetOnCastFunction()(self) end

    return true
end

-- 检查我们是否处于灰烬觉醒变异为【圣光之锤】的可用窗口期
local function IsHammerOfLightWindow()
    -- 首选：12.0.5 原生 API 检测法术 Override
    if C_Spell and C_Spell.GetOverrideSpell then
        local override = C_Spell.GetOverrideSpell(WakeOfAshes:GetID())
        if override == HammerOfLight:GetID() or override == 427453 then
            return true
        end
    end
    
    -- 次选：变异检测：如果灰烬觉醒的名字变成了圣光之锤，说明正在窗口期内
    if WakeOfAshes:GetName() == HammerOfLight:GetName() then
        return true
    end
    
    return false
end

-- 检查处决宣判是否刚释放过 (用于判定高优爆发期)
local function IsExecutionSentenceActive()
    if ExecutionSentence:IsKnown() then
        local cd = ExecutionSentence:GetCooldown()
        if cd > 20 then return true end
    end
    return false
end

----------------------------------------------------------------------
-- 主循环
----------------------------------------------------------------------
RetributionModule:Sync(function()
    if Player:IsCastingOrChanneling() then return end
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 自动攻击 (触发远征打击被动)
    if not AutoAttack:IsCurrent() and Player:InMelee(Target) then
        AutoAttack:Cast(Target)
    end

    local hp = Player:GetHP()
    local holyPower = GetHolyPower()
    local enemyCount = Player:GetEnemies(8)
    local useCDs = RetributionModule:GetSetting("use_cooldowns")
    local aoeThreshold = RetributionModule:GetSetting("aoe_count")
    local isAoE = (enemyCount >= aoeThreshold)

    -- ==================== 打断与防暴毙 ====================
    if RetributionModule:GetSetting("auto_interrupt") and Target:IsInterruptible() and Target:GetDistance(Player) <= 8 then
        if Rebuke:Cast(Target) then return end
    end

    if hp <= RetributionModule:GetSetting("shield_hp") then
        if DivineShield:Cast(Player) then return end
    end

    if hp <= RetributionModule:GetSetting("vengeance_hp") then
        if ShieldOfVengeance:Cast(Player) then return end
    end

    -- ==================== 爆发技能组 (Burst Cooldowns) ====================
    if useCDs then
        -- 1. 复仇之怒 (翅膀)
        if AvengingWrath:Cast(Player) then return end

        -- 2. 处决宣判 (需至少 3 豆，作为爆发链的绝对起手)
        if holyPower >= 3 and ExecutionSentence:IsInRange(Target) then
            if ExecutionSentence:Cast(Target) then return end
        end

        -- 3. 灰烬觉醒 (产 3 豆并激活圣光之锤)
        -- 施放条件：刚打完处决宣判，或者豆子 <= 2 避免溢出太多
        if Player:InMelee(Target) then
            if holyPower <= 2 or IsExecutionSentenceActive() then
                if WakeOfAshes:Cast(Player) then return end
            end
        end

        -- 4. 圣洁鸣钟 (产 1~5 豆)
        -- 施放条件：打完圣光之锤豆子空了，或者处决窗口期急需豆子
        if DivineToll:IsInRange(Target) then
            if holyPower <= 2 then
                if DivineToll:Cast(Target) then return end
            end
        end
    end

    -- ==================== 圣能倾泄与积攒系统 (Core Rotation) ====================
    local isHoLWindow = IsHammerOfLightWindow()
    local esActive = HasExecutionSentenceDebuff()

    -- 封装：常规倾泄 (最终审判 / 神圣风暴)
    local function DumpHolyPower()
        if isAoE and Target:GetDistance(Player) <= 8 then
            if DivineStorm:Cast(Player) then return true end
        elseif Target:GetDistance(Player) <= 12 then
            if FinalVerdict:Cast(Target) then return true end
        end
        return false
    end

    -- 【优先级 1】：圣光之锤 (耗 5 豆，绝杀伤害。哪怕有免费BUFF也先砸锤子，防止窗口期结束)
    -- 和审判一样的原理：因为是变异技能，CastSpellByName("圣光之锤") 会被拒收！必须直接用原始 ID 强砸！
    if holyPower == 5 and isHoLWindow and WakeOfAshes:IsInRange(Target) then
        Bastion.TCX.Unlock("CastSpellByID", 255937, Target:GetOMToken())
        Bastion.TCX.Unlock("SpellCancelQueuedSpell")
        WakeOfAshes.lastCastAttempt = GetTime()
        return
    end

    -- 【优先级 2】：处决宣判期间，只要有 3 豆以上，拼命倾泄所有伤害进池子
    if esActive and holyPower >= 3 then
        if DumpHolyPower() then return end
    end

    -- 【优先级 3】：白嫖 BUFF 消耗 (至高天之力 / 神圣意志)
    if HasEmpyreanPower() and Target:GetDistance(Player) <= 8 then
        if DivineStorm:Cast(Player) then return end
    end

    if HasDivinePurpose() then
        if DumpHolyPower() then return end
    end

    -- 【优先级 4】：满 5 豆绝对倾泄 (防溢出)
    if holyPower == 5 then
        if DumpHolyPower() then return end
    end

    -- 如果在圣光之锤窗口期，此时没到 5 豆，唯一目标是攒到 5 豆！
    if isHoLWindow and holyPower < 5 then
        if holyPower == 4 then
            if HammerOfWrath:IsInRange(Target) and HammerOfWrath:Cast(Target) then return end
            if Judgment:IsInRange(Target) and Judgment:Cast(Target) then return end
            if BladeOfJustice:IsInRange(Target) and BladeOfJustice:Cast(Target) then return end
        else
            if BladeOfJustice:IsInRange(Target) and BladeOfJustice:Cast(Target) then return end
            if HammerOfWrath:IsInRange(Target) and HammerOfWrath:Cast(Target) then return end
            if Judgment:IsInRange(Target) and Judgment:Cast(Target) then return end
        end
        -- 圣光之锤窗口期，绝对不打普通终结技，死等 5 豆
        return
    end

    -- ==================== 常规平稳期 (非圣光之锤窗口) ====================
    if not isHoLWindow then
        -- 【优先级 5】：最高优先铺垫审判易伤
        if not HasJudgmentDebuff() and Judgment:IsInRange(Target) then
            if Judgment:Cast(Target) then return end
        end

        if holyPower == 4 then
            if HammerOfWrath:IsInRange(Target) and HammerOfWrath:Cast(Target) then return end
            if Judgment:IsInRange(Target) and Judgment:Cast(Target) then return end
            if DumpHolyPower() then return end
        elseif holyPower == 3 then
            if BladeOfJustice:IsInRange(Target) and BladeOfJustice:Cast(Target) then return end
            if HammerOfWrath:IsInRange(Target) and HammerOfWrath:Cast(Target) then return end
            if Judgment:IsInRange(Target) and Judgment:Cast(Target) then return end
            if DumpHolyPower() then return end
        else
            if BladeOfJustice:IsInRange(Target) and BladeOfJustice:Cast(Target) then return end
            if HammerOfWrath:IsInRange(Target) and HammerOfWrath:Cast(Target) then return end
            if Judgment:IsInRange(Target) and Judgment:Cast(Target) then return end
        end
    end

end)

Bastion:Register(RetributionModule)
