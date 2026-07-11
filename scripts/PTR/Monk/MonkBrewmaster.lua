local tcx, Bastion = ...

-- 职业检查：仅武僧 (MONK) 加载
local _, englishClass = UnitClass("player")
if englishClass ~= "MONK" then return end

---@class MonkBrewmaster : Module
local M = Bastion.Module:New("MonkBrewmaster")
M:SetDisplayName("Brewmaster Monk", "酒仙武僧")

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

----------------------------------------------------------------------
-- UI 设置定义
----------------------------------------------------------------------
M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CwQAAAAAAAAAAAAAAAAAAAAAAAAAAgZbzYGGzyMzGzMjBAAAAAAYZBzEzMwMM2AmZmZY2sNzYsMss9AbbzGmFAAYZWmWmtZWGAAAADbgZGw0YADAYA"
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
    
    -- 防御阈值设置
    { type = "header", label = "Defensive Settings", labelZh = "== 防御自救设置 ==" },
    {
        key = "purifying_stagger_red",
        type = "toggle",
        label = "Purify Red Stagger Automatically",
        labelZh = "自动消除红色重度醉拳",
        default = true
    },
    {
        key = "purifying_stagger_yellow_hp",
        type = "slider",
        label = "Purify Yellow Stagger HP Threshold",
        labelZh = "消除黄色中度醉拳血量门槛",
        min = 20, max = 100, step = 5,
        default = 80
    },
    {
        key = "celestial_hp",
        type = "slider",
        label = "Celestial Brew HP Threshold",
        labelZh = "天神酒释放血量阈值",
        min = 20, max = 90, step = 5,
        default = 60
    },
    {
        key = "celestial_infusion_stacks",
        type = "slider",
        label = "Celestial Brew Min Infusion Stacks",
        labelZh = "释放天神酒最低净化之能层数",
        min = 1, max = 10, step = 1,
        default = 6
    },
    {
        key = "expel_harm_hp",
        type = "slider",
        label = "Expel Harm HP Threshold",
        labelZh = "移花接木自疗血量阈值",
        min = 30, max = 90, step = 5,
        default = 70
    },
    {
        key = "fortifying_hp",
        type = "slider",
        label = "Fortifying Brew HP Threshold",
        labelZh = "壮胆酒大减伤血量阈值",
        min = 10, max = 50, step = 5,
        default = 35
    },
    -- 爆发与控制设置
    { type = "header", label = "Offense & Utility", labelZh = "== 仇恨与控制设置 ==" },
    {
        key = "auto_interrupt",
        type = "toggle",
        label = "Auto Spear Hand Strike (Interrupt)",
        labelZh = "自动打断 (切喉手)",
        default = true
    },
    {
        key = "auto_mass_interrupt",
        type = "toggle",
        label = "Auto Leg Sweep (Mass Interrupt)",
        labelZh = "自动群体打断控制 (扫堂腿)",
        default = true
    },
    {
        key = "auto_taunt",
        type = "toggle",
        label = "Auto Provoke (Taunt on Lost Aggro)",
        labelZh = "自动嘲讽丢仇恨目标 (嚎镇八方)",
        default = true
    },
    {
        key = "aoe_count",
        type = "slider",
        label = "AoE Target Count",
        labelZh = "AoE 判定敌人数 (使用神鹤填充)",
        min = 2, max = 8, step = 1,
        default = 3
    }
})

----------------------------------------------------------------------
-- 技能定义 (12.0.5 和谐大师酒仙)
----------------------------------------------------------------------
-- 核心拉怪与输出
local KegSmash          = SpellBook:GetSpell(121253)  -- 醉酿投 (灵魂核心)
local BreathOfFire      = SpellBook:GetSpell(115181)  -- 火焰之息 (核心减伤与DOT)
local BlackoutKick      = SpellBook:GetSpell(205523)  -- 幻灭踢 (高伤填充/精通)
local TigerPalm         = SpellBook:GetSpell(100780)  -- 猛虎掌 (泄能填充)
local SpinningCrane     = SpellBook:GetSpell(101546)  -- 神鹤引项踢 (AoE填充)
local TouchOfDeath      = SpellBook:GetSpell(115080)  -- 轮回之触 (斩杀)
local ChiBurst          = SpellBook:GetSpell(123986)  -- 真气爆裂 (被动/主动填充)
local CelestialInfusion = SpellBook:GetSpell(1241059) -- 天神灌注 (英雄主动核心技能)
local AutoAttack        = SpellBook:GetSpell(6603)    -- 自动攻击

-- 防御与爆发
local PurifyingBrew     = SpellBook:GetSpell(119582)  -- 活血酒 (消醉拳)
local CelestialBrew     = SpellBook:GetSpell(322507)  -- 天神酒 (护盾)
local ExpelHarm         = SpellBook:GetSpell(115072)  -- 移花接木 (自疗)
local FortifyingBrew    = SpellBook:GetSpell(115203)  -- 壮胆酒 (大减伤)
local InvokeNiuzao      = SpellBook:GetSpell(132578)  -- 玄牛下凡 (大招)

-- 打断与嘲讽
local SpearHandStrike   = SpellBook:GetSpell(116705)  -- 切喉手 (单断)
local LegSweep          = SpellBook:GetSpell(119381)  -- 扫堂腿 (群断控制)
local Provoke           = SpellBook:GetSpell(115546)  -- 嚎镇八方 (嘲讽)
----------------------------------------------------------------------
-- 状态与 Buff/Debuff 引用
----------------------------------------------------------------------
local HeavyStagger       = SpellBook:GetSpell(124273) -- 重度醉拳 (红)
local ModerateStagger    = SpellBook:GetSpell(124274) -- 中度醉拳 (黄)
local LightStagger       = SpellBook:GetSpell(124275) -- 轻度醉拳 (绿)
local PurifiedQi         = SpellBook:GetSpell(325092) -- 净化之能 (天神酒强化Buff)
local KegSmashDebuff     = SpellBook:GetSpell(121253) -- 醉酿投Debuff
local BreathOfFireDebuff = SpellBook:GetSpell(115181) -- 火焰之息点燃Debuff

----------------------------------------------------------------------
-- 主循环入口
----------------------------------------------------------------------
M:Sync(function()
    -- ==================== 施法状态保护 ====================
    if Player:IsCastingOrChanneling() then return end

    -- ==================== 目标有效性检查 ====================
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 确保自动攻击开启
    if not AutoAttack:IsCurrent() and Player:InMelee(Target) then
        AutoAttack:Cast(Target)
    end

    -- ==================== 基础变量获取 ====================
    local hp = Player:GetHP()
    local energy = Player:GetPower(3) or 0 -- 能量 (Energy)
    local enemiesCount = Player:GetEnemies(8) or 0

    -- 醉拳严重程度判定
    local isRedStagger = Player:GetAuras():FindMy(HeavyStagger):IsUp()
    local isYellowStagger = Player:GetAuras():FindMy(ModerateStagger):IsUp()

    -- 净化之能层数获取
    local qiBuff = Player:GetAuras():FindMy(PurifiedQi)
    local qiStacks = (qiBuff and qiBuff:IsUp()) and qiBuff:GetCount() or 0

    -- ==================== 1. 核心打断与嘲讽控制 ====================
    -- 自动打断：优先当前目标，其次焦点目标
    if M:GetSetting("auto_interrupt") then
        if SpearHandStrike:IsKnownAndUsable() then
            -- 当前目标打断 (加入面向判定)
            if Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() and Player:IsWithinCombatDistance(Target, 13) and Player:IsFacing(Target) then
                if SpearHandStrike:Cast(Target) then return end
            end
            -- 焦点目标打断 (加入面向判定)
            local focus = Bastion.UnitManager:Get('focus')
            if focus and focus:IsValid() and focus:IsEnemy() and focus:IsInterruptible() and Player:IsWithinCombatDistance(focus, 13) and Player:IsFacing(focus) then
                if SpearHandStrike:Cast(focus) then return end
            end
        end
    end

    -- 自动群控打断（扫堂腿）
    -- 当身边敌人数 >= 2 且有目标正在施法，并且单体打断不可用时施放扫堂腿
    if M:GetSetting("auto_mass_interrupt") and LegSweep:IsKnownAndUsable() and enemiesCount >= 2 then
        local targetCasting = Target:IsValid() and Target:IsInterruptible() and Player:IsWithinCombatDistance(Target, 5)
        local shouldSweep = targetCasting and not SpearHandStrike:IsKnownAndUsable()
        if shouldSweep then
            if LegSweep:Cast(Player) then return end
        end
    end

    -- 自动嘲讽丢失仇恨目标 (嚎镇八方)
    if M:GetSetting("auto_taunt") and Provoke:IsKnownAndUsable() then
        if Target:IsValid() and Target:IsEnemy() and not Target:IsDead() and Player:IsAffectingCombat() then
            -- 使用框架自带的 IsTanking 方法检测当前怪物的仇恨是否稳固在自己(Player)身上，且我们正面对着目标
            if not Target:IsTanking(Player) and Player:IsFacing(Target) then
                if Provoke:Cast(Target) then return end
            end
        end
    end

    -- ==================== 2. 防御自救逻辑 ====================

    -- [大减伤] 壮胆酒 (Fortifying Brew)
    -- 血量低于设定危急线时自动开启
    if hp <= M:GetSetting("fortifying_hp") then
        if FortifyingBrew:IsKnownAndUsable() then
            if FortifyingBrew:Cast(Player) then return end
        end
    end

    -- [消醉拳] 活血酒 (Purifying Brew)
    -- 1. 自动消除红色重度醉拳
    -- 2. 血量低于设定值且处于黄色中度醉拳时消除
    if PurifyingBrew:IsKnownAndUsable() then
        if (isRedStagger and M:GetSetting("purifying_stagger_red")) or
           (isYellowStagger and hp <= M:GetSetting("purifying_stagger_yellow_hp")) then
            if PurifyingBrew:Cast(Player) then return end
        end
    end

    -- [护盾] 天神酒 (Celestial Brew)
    -- 1. 血量低于设定危险线 (默认 60%) 时使用
    -- 2. 身上拥有的“净化之能”层数达到设定极高层 (默认 6层) 且血量非健康时使用
    if CelestialBrew:IsKnownAndUsable() then
        if hp <= M:GetSetting("celestial_hp") or 
           (qiStacks >= M:GetSetting("celestial_infusion_stacks") and hp <= 85) then
            if CelestialBrew:Cast(Player) then return end
        end
    end

    -- [自疗] 移花接木 (Expel Harm)
    -- 血量较低且可用时释放，吃珠自保
    if hp <= M:GetSetting("expel_harm_hp") then
        if ExpelHarm:IsKnownAndUsable() then
            if ExpelHarm:Cast(Player) then return end
        end
    end

    -- ==================== 3. 爆发生存大招 ====================
    -- 玄牛下凡：卡CD或玩家接怪后立即开启，嘲讽与分担伤害
    if InvokeNiuzao:IsKnownAndUsable() and Player:InMelee(Target) then
        if InvokeNiuzao:Cast(Player) then return end
    end

    -- ==================== 4. 仇恨与输出循环 (基于 WCL 实测占比) ====================

    -- [优先级 1] 轮回之触斩杀
    -- 当目标符合斩杀线时，第一时间踢出秒杀 (加入面向判定)
    if TouchOfDeath:IsKnownAndUsable() and Player:InMelee(Target) and Player:IsFacing(Target) then
        local targetHPVal = Target:GetHP() * 0.01 * Target:GetHPMax()
        if targetHPVal < Player:GetHPMax() or Target:GetHP() <= 15 then
            if TouchOfDeath:Cast(Target) then return end
        end
    end

    -- [优先级 2] 醉酿投 (Keg Smash)
    -- 核心中的核心，卡 CD 砸出 (加入面向判定)
    if KegSmash:IsKnownAndUsable() and KegSmash:IsInRange(Target) and Player:IsFacing(Target) then
        if KegSmash:Cast(Target) then return end
    end

    -- [优先级 3] 火焰之息 (Breath of Fire)
    -- 必须在目标带有醉酿投 Debuff 且我们面对它时施放，以触发减伤 (加入面向判定)
    local isKegSmashed = Target:GetAuras():FindMy(KegSmashDebuff):IsUp()
    if isKegSmashed and BreathOfFire:IsKnownAndUsable() and Player:IsWithinCombatDistance(Target, 8) and Player:IsFacing(Target) then
        if BreathOfFire:Cast(Player) then return end
    end

    -- [优先级 4] 天神灌注 (Celestial Infusion)
    -- 祥和宗师专精的英雄主动大招，卡 CD 极速砸出 (自身Buff，对Player施放)
    if CelestialInfusion:IsKnownAndUsable() and Player:IsWithinCombatDistance(Target, 8) then
        if CelestialInfusion:Cast(Player) then return end
    end

    -- [优先级 5] 幻灭踢 (Blackout Kick)
    -- 提供醉拳大师闪避并打出伤害 (加入面向判定)
    if BlackoutKick:IsKnownAndUsable() and BlackoutKick:IsInRange(Target) and Player:IsFacing(Target) then
        if BlackoutKick:Cast(Target) then return end
    end

    -- [优先级 6] 真气爆裂 (Chi Burst)
    -- 天赋主动技能，作为优秀的拉怪和回能补充 (加入面向判定)
    if ChiBurst:IsKnownAndUsable() and Player:IsWithinCombatDistance(Target, 40) and Player:IsFacing(Target) then
        if ChiBurst:Cast(Target) then return end
    end

    -- [优先级 7] 填充消耗
    -- 1. AoE 填充：如果身边敌人数大于等于设定阈值，使用神鹤引项踢填充
    -- 2. 单体填充：能量充足且面对目标时，使用猛虎掌泄能触发和谐涌动 (加入面向判定)
    if enemiesCount >= M:GetSetting("aoe_count") then
        if SpinningCrane:IsKnownAndUsable() and Player:IsWithinCombatDistance(Target, 8) then
            if SpinningCrane:Cast(Player) then return end
        end
    else
        if energy >= 50 and TigerPalm:IsKnownAndUsable() and TigerPalm:IsInRange(Target) and Player:IsFacing(Target) then
            if TigerPalm:Cast(Target) then return end
        end
    end

end)

Bastion:Register(M)
return M
