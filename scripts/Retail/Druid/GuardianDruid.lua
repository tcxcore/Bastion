local _, Bastion = ...

-- 职业与专精检查：仅守护德鲁伊（专精 3）加载
local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then return end

local GuardianModule = Bastion.Module:New('GuardianDruid')
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

----------------------------------------------------------------------
-- UI 设置定义
----------------------------------------------------------------------
GuardianModule:SetDisplayName("Guardian Druid", "守护德鲁伊")
GuardianModule:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CgGAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAgZmxsMPwYMzmZZGMWGAzY0ENzMLzMzMjxMmBAAAAAMjlZALbzMYMbDgJAAAgNMzDMgFzgBsYZbAmZAM"
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
    
    -- 防御阈值
    { type = "header", label = "Defensive Thresholds", labelZh = "防御阈值" },
    { key = "survival_hp", type = "slider", label = "Survival Instincts HP%", labelZh = "生存本能血量%", min = 10, max = 80, step = 5, default = 35 },
    { key = "frenzied_hp", type = "slider", label = "Frenzied Regeneration HP%", labelZh = "狂暴回复血量%", min = 20, max = 80, step = 5, default = 55 },
    { key = "barkskin_hp", type = "slider", label = "Barkskin HP%", labelZh = "树皮术血量%", min = 20, max = 90, step = 5, default = 65 },
    { key = "ironfur_rage", type = "slider", label = "Ironfur Min Rage", labelZh = "铁鬃最低怒气", min = 20, max = 60, step = 5, default = 40 },
    
    -- 爆发控制
    { type = "header", label = "Burst Control", labelZh = "爆发控制" },
    { key = "auto_incarnation", type = "toggle", label = "Auto Incarnation", labelZh = "自动化身", default = true },
    { key = "auto_rage_sleeper", type = "toggle", label = "Auto Rage of the Sleeper", labelZh = "自动沉睡者之怒", default = true },
    
    -- AoE 设置
    { type = "header", label = "AoE Settings", labelZh = "AoE 设置" },
    { key = "aoe_count", type = "slider", label = "AoE Target Count", labelZh = "AoE 目标数量", min = 2, max = 8, step = 1, default = 3 },
    
    -- 打断
    { type = "header", label = "Interrupt Settings", labelZh = "打断设置" },
    { key = "auto_interrupt", type = "toggle", label = "Auto Interrupt", labelZh = "自动打断", default = true },
    { key = "auto_mass_interrupt", type = "toggle", label = "Auto Mass Interrupt (Roar)", labelZh = "自动群体打断(和谐咆哮)", default = true },
    { key = "auto_taunt", type = "toggle", label = "Auto Growl (Taunt on Lost Aggro)", labelZh = "自动嘲讽丢仇恨目标(低吼)", default = true },
})

----------------------------------------------------------------------
-- 技能定义
----------------------------------------------------------------------
-- 核心输出
local Mangle       = SpellBook:GetSpell(33917)
local Thrash       = SpellBook:GetSpell(77758)
local Moonfire     = SpellBook:GetSpell(8921)
local Maul         = SpellBook:GetSpell(6807)
local Swipe        = SpellBook:GetSpell(213771)
local Raze         = SpellBook:GetSpell(391286)

-- 冷却技能
local LunarBeam        = SpellBook:GetSpell(204066)
local Incarnation      = SpellBook:GetSpell(102558)
local RageOfTheSleeper = SpellBook:GetSpell(200851)
local HeartOfTheWild   = SpellBook:GetSpell(319454)

-- 防御技能
local Ironfur               = SpellBook:GetSpell(192081)
local Barkskin              = SpellBook:GetSpell(22812)
local FrenziedRegeneration  = SpellBook:GetSpell(22842)
local SurvivalInstincts     = SpellBook:GetSpell(61336)

-- 打断 / 控制 / 嘲讽
local SkullBash         = SpellBook:GetSpell(106839)
local IncapacitatingRoar = SpellBook:GetSpell(99)
local Growl              = SpellBook:GetSpell(6795) -- 低吼 (嘲讽)

-- 形态
local BearForm   = SpellBook:GetSpell(5487)
local CatForm    = SpellBook:GetSpell(768)
local TravelForm = SpellBook:GetSpell(783)
local AutoAttack = SpellBook:GetSpell(6603)

----------------------------------------------------------------------
-- Buff / Debuff 引用
----------------------------------------------------------------------
local MoonfireDot          = SpellBook:GetSpell(164812)
local ThrashDot            = SpellBook:GetSpell(192090)
local IronfurBuff          = SpellBook:GetSpell(192081)
local ToothAndClawBuff     = SpellBook:GetSpell(135286)
local GalacticGuardianBuff = SpellBook:GetSpell(213708)
local DreamOfCenariusBuff  = SpellBook:GetSpell(372119)

----------------------------------------------------------------------
-- 辅助函数
----------------------------------------------------------------------

-- 铁鬃当前层数
local function GetIronfurStacks()
    return Player:GetAuras():FindMy(IronfurBuff):GetCount()
end

-- 铁鬃剩余时间
local function GetIronfurRemaining()
    return Player:GetAuras():FindMy(IronfurBuff):GetRemainingTime()
end

-- 是否在熊形态
local function IsInBearForm()
    return Player:GetAuras():FindMy(BearForm):IsUp()
end

----------------------------------------------------------------------
-- 主循环
----------------------------------------------------------------------
GuardianModule:Sync(function()
    -- ==================== 施法状态保护 ====================
    if Player:IsCastingOrChanneling() then return end

    -- ==================== 形态管理 ====================
    if Player:IsAffectingCombat() then
        -- 战斗中：必须熊形态
        if not IsInBearForm() then
            if BearForm:IsKnownAndUsable() then
                BearForm:Cast(Player)
                return
            end
        end
    end

    -- ==================== 目标有效性检查 ====================
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 确保自动攻击开启
    if not AutoAttack:IsCurrent() and Player:InMelee(Target) then
        AutoAttack:Cast(Target)
    end

    local rage = Player:GetPower()
    local hp = Player:GetHP()
    local enemiesNearby = Player:GetEnemies(8)

    -- ==================== 打断 ====================
    if GuardianModule:GetSetting("auto_interrupt") then
        if Target:IsInterruptible() and Player:IsWithinCombatDistance(Target, 13) and Player:IsFacing(Target) then
            if SkullBash:IsKnownAndUsable() then
                SkullBash:Cast(Target)
                return
            end
        end
    end

    -- 群体打断（仅当头骨猛击不可用时）
    if GuardianModule:GetSetting("auto_mass_interrupt") then
        if enemiesNearby > 1 and not SkullBash:IsKnownAndUsable() then
            if IncapacitatingRoar:IsKnownAndUsable() and Target:IsCastingOrChanneling() then
                IncapacitatingRoar:Cast(Player)
                return
            end
        end
    end

    -- ==================== 仇恨处理 ====================
    -- 自动低吼嘲讽丢仇恨的目标 (加入面向判定)
    if GuardianModule:GetSetting("auto_taunt") and Growl:IsKnownAndUsable() then
        if Target:IsValid() and Target:IsEnemy() and not Target:IsDead() and Player:IsAffectingCombat() then
            -- 使用框架自带的 IsTanking 威胁度系统进行高精度仇恨检测，且正对目标时才嘲讽
            if not Target:IsTanking(Player) and Player:IsFacing(Target) then
                if Growl:Cast(Target) then return end
            end
        end
    end

    -- ==================== 防御与资源分配 ====================
    
    -- 生存本能：血量极低时使用
    if hp <= GuardianModule:GetSetting("survival_hp") then
        if SurvivalInstincts:IsKnownAndUsable() then
            if SurvivalInstincts:Cast(Player) then return end
        end
    end

    -- 狂暴回复：中等血量时使用
    if hp <= GuardianModule:GetSetting("frenzied_hp") then
        if FrenziedRegeneration:IsKnownAndUsable() then
            if FrenziedRegeneration:Cast(Player) then return end
        end
    end

    -- 树皮术：血量较低时使用
    if hp <= GuardianModule:GetSetting("barkskin_hp") then
        if Barkskin:IsKnownAndUsable() then
            if Barkskin:Cast(Player) then return end
        end
    end

    -- 铁鬃逻辑 (Ironfur)
    -- 1. 基础维持：保持至少 1 层覆盖
    if rage >= 40 and GetIronfurStacks() < 1 then
        if Ironfur:IsKnownAndUsable() then
            if Ironfur:Cast(Player) then return end
        end
    end

    -- 2. 高压叠层：如果血量低于安全线，或者怒气快溢出了，则积极叠第 2/3 层
    if rage >= 40 and (hp < 70 or rage >= 85) and GetIronfurStacks() < 3 then
        if Ironfur:IsKnownAndUsable() then
            if Ironfur:Cast(Player) then return end
        end
    end

    -- 3. 补覆盖：快过期时刷新
    if rage >= 40 and GetIronfurRemaining() < 2 then
        if Ironfur:IsKnownAndUsable() then
            if Ironfur:Cast(Player) then return end
        end
    end

    -- ==================== 爆发冷却 ====================
    if GuardianModule:GetSetting("auto_incarnation") and Incarnation:IsKnownAndUsable() then
        if Incarnation:Cast(Player) then return end
    end

    if GuardianModule:GetSetting("auto_rage_sleeper") and RageOfTheSleeper:IsKnownAndUsable() then
        if RageOfTheSleeper:Cast(Player) then return end
    end

    if HeartOfTheWild:IsKnownAndUsable() then
        if HeartOfTheWild:Cast(Player) then return end
    end

    -- ==================== 艾露恩神选者 核心输出循环 ====================
    
    -- 1. 明月普照 (Lunar Beam) - WCL核心爆发，卡CD用
    if LunarBeam:IsKnownAndUsable() and (Player:InMelee(Target) or Player:IsWithinCombatDistance(Target, 8)) then
        if LunarBeam:Cast(Player) then return end
    end

    -- 2. 高优先级 摧折 (Raze) / 重殴 (Maul) - 防止怒气溢出或消耗高亮免费buff (加入面向判定)
    local hasTooth = Player:GetAuras():FindMy(ToothAndClawBuff):IsUp()
    if hasTooth or rage >= 80 then
        if Raze:IsKnown() then
            if Raze:IsKnownAndUsable() and (Player:InMelee(Target) or Player:IsWithinCombatDistance(Target, 8)) and Player:IsFacing(Target) then
                if Raze:Cast(Target) then return end
            end
        else
            if Maul:IsKnownAndUsable() and Player:InMelee(Target) and Player:IsFacing(Target) then
                if Maul:Cast(Target) then return end
            end
        end
    end

    -- 3. 痛击 (Thrash) - 最高优先级填充，卡CD获取怒气 (360度周身群拉)
    if Thrash:IsKnownAndUsable() and (Player:InMelee(Target) or Player:IsWithinCombatDistance(Target, 8)) then
        if Thrash:Cast(Player) then return end
    end

    -- -- 4. 裂伤 (Mangle) - 最高单体填充，卡CD获取怒气 (需要面向)
    -- if Mangle:IsKnownAndUsable() and Player:InMelee(Target) and Player:IsFacing(Target) then
    --     if Mangle:Cast(Target) then return end
    -- end

    -- 5. 低优先级 摧折 (Raze) / 重殴 (Maul) - 常规泄怒 (加入面向判定)
    if rage >= 40 and GetIronfurStacks() >= 1 then
        if Raze:IsKnown() then
            if Raze:IsKnownAndUsable() and (Player:InMelee(Target) or Player:IsWithinCombatDistance(Target, 8)) and Player:IsFacing(Target) then
                if Raze:Cast(Target) then return end
            end
        else
            if Maul:IsKnownAndUsable() and Player:InMelee(Target) and Player:IsFacing(Target) then
                if Maul:Cast(Target) then return end
            end
        end
    end

    -- 6. 月火术 (Moonfire) - 银河守护者触发 或 DOT 维持 (加入面向判定)
    if Player:GetAuras():FindMy(GalacticGuardianBuff):IsUp()
        or not Target:GetAuras():FindMy(MoonfireDot):IsUp()
        or Target:GetAuras():FindMy(MoonfireDot):GetRemainingTime() < 3 then
        if Moonfire:IsKnownAndUsable() and Player:IsWithinCombatDistance(Target, 40) and Player:IsFacing(Target) then
            if Moonfire:Cast(Target) then return end
        end
    end

    -- 7. 横扫 (Swipe) - 无事可做的底层填充 (360度周身群拉)
    if Swipe:IsKnownAndUsable() and (Player:InMelee(Target) or Player:IsWithinCombatDistance(Target, 8)) then
        if Swipe:Cast(Target) then return end
    end

end)

Bastion:Register(GuardianModule)