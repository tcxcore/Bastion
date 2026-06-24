local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 12.0.5 增辉唤魔师战斗循环 (Augmentation Evoker Rotation)
-- 基于 WCL 顶尖日志数据、蓄力精算、黑檀之力覆盖率与智能队友辅助机制精细设计
-- 核心机制：黑檀之力卡 CD 开启与延长覆盖、先知先觉智能双表融合 2 目标轮流投送、
--           亘古吐息爆发卡轴连携、扭转天平秒放 1 阶蓄力、多重指向安全墙拦截。
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 核心法术与技能定义 (Spell Definitions)
-- ======================================================================
local EbonMight         = SpellBook:GetSpell(395152)  -- 黑檀之力 (施法 ID)
local Prescience        = SpellBook:GetSpell(409311)  -- 先知先觉 (施法 ID)
local BreathOfEons      = SpellBook:GetSpell(442204)  -- 亘古吐息 (施法 ID)
local Eruption          = SpellBook:GetSpell(395160)  -- 喷发 (消耗精华，延长黑檀 1 秒)
local Upheaval          = SpellBook:GetSpell(396286)  -- 地壳激变 (蓄力，延长黑檀 2 秒)
local FireBreath        = SpellBook:GetSpell(357208)  -- 火焰吐息 (蓄力，延长黑檀 2 秒)
local TipTheScales      = SpellBook:GetSpell(370553)  -- 扭转天平 (蓄力秒放)
local Hover             = SpellBook:GetSpell(358267)  -- 悬空 (移动免法术读条)
local AzureStrike       = SpellBook:GetSpell(362969)  -- 碧蓝打击 (瞬发移动攒能)
local LivingFlame       = SpellBook:GetSpell(361469)  -- 活化烈焰 (常规填充/攒能/自疗)
local ObsidianScales    = SpellBook:GetSpell(363916)  -- 黑曜鳞片 (个人强力大减伤)
local Zephyr            = SpellBook:GetSpell(374227)  -- 微风 (小队/个人减伤自疗)
local Quell             = SpellBook:GetSpell(351338)  -- 镇压 (打断)
local EmeraldBlossom    = SpellBook:GetSpell(355913)  -- 翡翠之花 (智能自愈)
local BlessingOfBronze  = SpellBook:GetSpell(364342)  -- 青铜龙的祝福 (团队Buff)
local AutoAttack        = SpellBook:GetSpell(6603)    -- 自动攻击

--======================================================================
-- BUFF/DEBUFF
--======================================================================
local EbonMightBuff     = SpellBook:GetSpell(395296)  -- 黑檀之力 Buff (Buff ID)
local PrescienceBuff    = SpellBook:GetSpell(410089)  -- 先知先觉 Buff (Buff ID)
local EssenceBurstBuff  = SpellBook:GetSpell(392268)  -- 精华迸发 Buff (下一个喷发免费)
local BlessingOfBronzeBuff = SpellBook:GetSpell(381748) -- 青铜龙的祝福 Buff (Buff ID 与施法 ID 不同)
-- ======================================================================
-- 模块注册与设置
-- ======================================================================
local M = Bastion.Module:New("EvokerAugmentation")
M:SetDisplayName("Augmentation Evoker", "增辉唤魔师")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "CEcBAAAAAAAAAAAAAAAAAAAAAwMzMbzMzgBzMLzYMMzGAAAAAMAAwM8AzAjpGzMzAAAAgZmZMmZWGzMwMbzYwCsMGGLDgZQshZmBzMAG"
            if C_Keybindings and C_Keybindings.CopyToClipboard then
                if C_Keybindings.CopyToClipboard(talentStr) then
                    Bastion:Print("|cFF00FF00[推荐天赋]|r 增辉唤魔师天赋导出字符串已成功复制到系统剪贴板！可以直接在游戏内导入。")
                    return
                end
            end
            StaticPopupDialogs["BASTION_COPY_EVOKER_TALENTS"] = {
                text = "请按 Ctrl+C 复制推荐增辉唤魔师配置天赋：",
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
            StaticPopup_Show("BASTION_COPY_EVOKER_TALENTS")
            Bastion:Print("|cFFFFCC00[推荐天赋]|r 已拉起复制框，请按 Ctrl+C 复制推荐增辉唤魔师天赋。")
        end
    },

    { type = "header", label = "== General Settings ==", labelZh = "== 通用设置 ==" },
    {
        type = "toggle",
        key = "useCooldowns",
        label = "Use Cooldowns (Burst)",
        labelZh = "自动释放爆发大招 (亘古吐息/扭转天平)",
        default = true
    },
    {
        type = "toggle",
        key = "autoHover",
        label = "Auto Hover (Move Cast)",
        labelZh = "移动中智能悬空免打断",
        default = true
    },
    { type = "header", label = "== Empower Settings ==", labelZh = "== 蓄力法术设置 ==" },
    {
        type = "slider",
        key = "upheavalStage",
        label = "Upheaval Stage",
        labelZh = "地壳激变蓄力层数",
        min = 1, max = 3, step = 1,
        default = 1
    },
    {
        type = "slider",
        key = "fireBreathStage",
        label = "Fire Breath Stage",
        labelZh = "火焰吐息蓄力层数",
        min = 1, max = 3, step = 1,
        default = 1
    },
    
    { type = "header", label = "== Defensive & Heal Settings ==", labelZh = "== 自保与自疗设置 ==" },
    {
        type = "slider",
        key = "scalesHP",
        label = "Obsidian Scales HP%",
        labelZh = "黑曜鳞片使用血量%",
        min = 10, max = 80, step = 5,
        default = 35
    },
    {
        type = "slider",
        key = "zephyrHP",
        label = "Zephyr HP%",
        labelZh = "微风使用血量%",
        min = 10, max = 60, step = 5,
        default = 25
    },
    {
        type = "slider",
        key = "emeraldHP",
        label = "Emerald Blossom HP%",
        labelZh = "翡翠之花自愈血量%",
        min = 20, max = 80, step = 5,
        default = 50
    },
    {
        type = "slider",
        key = "healHP",
        label = "Living Flame Heal HP%",
        labelZh = "活化烈焰自疗血量%",
        min = 10, max = 80, step = 5,
        default = 40
    },
    {
        type = "toggle",
        key = "autoInterrupt",
        label = "Auto Quell (Interrupt)",
        labelZh = "自动打断 (镇压)",
        default = true
    }
})

-- ======================================================================
-- 内部高阶辅助函数 (Helper Functions)
-- ======================================================================

-- 1. 检查自身是否拥有黑檀之力 (Ebon Might) 状态
local function HasEbonMight()
    local em = Player:GetAuras():FindMy(EbonMightBuff)
    return em and em:IsUp()
end

-- 2. 检查自身剩余的黑檀之力时间
local function GetEbonMightRemaining()
    local em = Player:GetAuras():FindMy(EbonMightBuff)
    if em and em:IsUp() then
        return em:GetRemainingTime() or 0
    end
    return 0
end

-- 3. 判断是否为自身
local function IsSelf(unit)
    return UnitIsUnit(unit:GetOMToken(), "player")
end

-- 4. 融合检索队友或自己身上的先知先觉 (Prescience) Buff 剩余时间
local function GetPrescienceRemaining(unit)
    local auras = unit:GetAuras()
    local b = auras:FindMy(PrescienceBuff)
    if not b or not b:IsUp() then
        b = auras:Find(PrescienceBuff)
    end
    if b and b:IsUp() then
        return b:GetRemainingTime() or 0
    end
    return 0
end

-- 5.5. 火焰吐息专用施放 (该法术无法通过 CastSpellByName 释放，需使用 CastSpellByID)
local function CastFireBreath(unit)
    if not FireBreath:IsKnownAndUsable() then return false end
    Bastion.TCX.Unlock("CastSpellByID", FireBreath:GetID(), unit:GetOMToken())
    Bastion.TCX.Unlock("SpellCancelQueuedSpell")
    return true
end

-- 5.6. 亘古吐息专用施放 (该技能 ID 不被框架 IsKnownAndUsable 正确识别，绕过检查)
local function CastBreathOfEons(unit)
    -- 简单 CD 检查
    local info = C_Spell.GetSpellCooldown(BreathOfEons:GetID())
    if info and info.duration > 0 then return false end
    Bastion.TCX.Unlock("CastSpellByName", "亘古吐息", unit:GetOMToken())
    Bastion.TCX.Unlock("SpellCancelQueuedSpell")
    return true
end

-- 5.8. 查找火焰吐息所在的动作条按钮名 (火焰吐息无法通过 /cast 释放蓄力，需用 /click)
local _fireBreathBtn = nil
local function FindFireBreathButton()
    if _fireBreathBtn then return _fireBreathBtn end
    local prefixes = {
        "ActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton",
        "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "MultiBar8Button"
    }
    for _, prefix in ipairs(prefixes) do
        for i = 1, 12 do
            local btn = _G[prefix .. i]
            if btn then
                local slot = btn.action or (btn.GetAttribute and btn:GetAttribute("action"))
                if slot and HasAction(slot) then
                    local actionType, id = GetActionInfo(slot)
                    if actionType == "spell" and id == FireBreath:GetID() then
                        _fireBreathBtn = prefix .. i
                        Bastion:Print("|cFF00FF00[火焰吐息]|r 找到动作条按钮: " .. _fireBreathBtn)
                        return _fireBreathBtn
                    end
                end
            end
        end
    end
    return nil
end

-- 6. 获取当前的精华数 (Essence)
local function GetEssence()
    local power
    if Enum and Enum.PowerType and Enum.PowerType.Essence then
        power = Player:GetPower(Enum.PowerType.Essence)
    end
    if not power then
        power = Player:GetPower(19) or UnitPower("player", 19)
    end
    return power or 0
end

-- 6.5. 检查自身是否触发了“精华迸发” (Essence Burst) 状态
local function HasEssenceBurst()
    local eb = Player:GetAuras():FindMy(EssenceBurstBuff)
    if not eb or not eb:IsUp() then
        eb = Player:GetAuras():Find(EssenceBurstBuff)
    end
    return eb and eb:IsUp()
end

-- 7. 智能多目标/队友先知先觉 (Prescience) 投送决策
local function CastPrescienceOnBestFriend()
    local friends = {}
    Bastion.UnitManager:EnumFriends(function(unit)
        if unit:IsValid() and unit:IsPlayer() and unit:IsInParty() and not unit:IsDead() then
            if not IsSelf(unit) then
                -- 施法距离和面向，视野安全过滤，确保完美投送
                if Prescience:IsInRange(unit) and Player:IsFacing(unit) and Player:CanSee(unit) then
                    table.insert(friends, unit)
                end
            end
        end
    end)

    if #friends == 0 then
        -- 单人或无有效队友时自适应对自己投送
        local myRem = GetPrescienceRemaining(Player)
        if myRem < 2.0 then
            if Prescience:Cast(Player) then
                Bastion:Print("|cFF00FF00[先知先觉]|r 队伍无队友，对自己施放先知先觉")
                return true
            end
        end
        return false
    end

    -- 核心排序逻辑：没有Buff或过期优先 > 职责DPS优先 > 距离优先
    table.sort(friends, function(a, b)
        local remA = GetPrescienceRemaining(a)
        local remB = GetPrescienceRemaining(b)

        if remA == 0 and remB > 0 then return true end
        if remB == 0 and remA > 0 then return false end

        if remA > 0 and remB > 0 then
            if remA < 2.0 and remB >= 2.0 then return true end
            if remB < 2.0 and remA >= 2.0 then return false end
            if math.abs(remA - remB) > 0.1 then
                return remA < remB
            end
        end

        local roleA = a:IsDamage() and 3 or (a:IsTank() and 2 or 1)
        local roleB = b:IsDamage() and 3 or (b:IsTank() and 2 or 1)
        if roleA ~= roleB then
            return roleA > roleB
        end

        return a:GetDistance(Player) < b:GetDistance(Player)
    end)

    -- 找到最需要补先知先觉的目标
    local targetFriend = friends[1]
    if targetFriend then
        local rem = GetPrescienceRemaining(targetFriend)
        if rem < 2.0 then
            if Prescience:Cast(targetFriend) then
                Bastion:Print("|cFF00FF00[先知先觉]|r 智能施放先知先觉 -> " .. targetFriend:GetName() .. " (职责: " .. (targetFriend:IsDamage() and "DPS" or (targetFriend:IsTank() and "坦克" or "治疗")) .. ")")
                return true
            end
        end
    end

    return false
end

-- 8. 智能打断处理
local function HandleInterrupts()
    if not M:GetSetting("autoInterrupt") then return false end

    -- 1. 优先打断当前目标
    if Target:IsValid() and Target:IsEnemy() and Target:IsInterruptible() then
        if Quell:IsInRange(Target) and Player:IsFacing(Target) and Player:CanSee(Target) then
            if Quell:Cast(Target) then
                Bastion:Print("|cFF00FF00[打断]|r 施放镇压打断当前目标 -> " .. Target:GetName())
                return true
            end
        end
    end

    -- 2. 焦点目标打断
    local focus = Bastion.UnitManager:Get('focus')
    if focus and focus:IsValid() and focus:IsEnemy() and focus:IsInterruptible() then
        if Quell:IsInRange(focus) and Player:IsFacing(focus) and Player:CanSee(focus) then
            if Quell:Cast(focus) then
                Bastion:Print("|cFF00FF00[打断]|r 施放镇压打断焦点目标 -> " .. focus:GetName())
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
    -- 施法中或者正在蓄力时的智能处理
    if Player:IsCastingOrChanneling() then
        if Player:IsChanneling() then
            local empStage = Player:GetEmpoweredStage()
            local chanName, _, _, _, _, _, _, chanSpellID = UnitChannelInfo("player")
            
            local targetStage = 1
            if chanSpellID and chanSpellID == FireBreath:GetID() then
                targetStage = M:GetSetting("fireBreathStage")
            else
                targetStage = M:GetSetting("upheavalStage")
            end

            if empStage >= targetStage then
                if chanSpellID and chanSpellID == FireBreath:GetID() then
                    -- 火焰吐息：/cast 无法释放，用 /click 动作条按钮释放
                    local btnName = FindFireBreathButton()
                    if btnName then
                        Bastion.TCX.RunScript('C_Macro.RunMacroText("/click ' .. btnName .. '", "button")')
                    end
                elseif chanName then
                    -- 其他蓄力法术 (地壳激变等)：用 /cast 释放
                    Bastion.TCX.RunScript('C_Macro.RunMacroText("/cast ' .. chanName .. '", "button")')
                end
            end
        end
        return
    end

    -- ==================== 1. 自保与生存逻辑 (高优先，不受安全墙限制) ====================
    local hp = Player:GetHP()

    -- 黑曜鳞片 (核心自保减伤)
    if hp <= M:GetSetting("scalesHP") and Player:IsAffectingCombat() then
        if ObsidianScales:Cast(Player) then
            Bastion:Print("|cFFFF0000[减伤自保]|r 开启黑曜鳞片自保！")
            return
        end
    end

    -- 微风 (群体减伤自愈)
    if hp <= M:GetSetting("zephyrHP") and Player:IsAffectingCombat() then
        if Zephyr:Cast(Player) then
            Bastion:Print("|cFFFF0000[减伤自保]|r 开启微风生存自疗！")
            return
        end
    end

    -- 翡翠之花 (高性价比自疗)
    if hp <= M:GetSetting("emeraldHP") then
        if EmeraldBlossom:Cast(Player) then return end
    end

    -- 活化烈焰 (低血量无目标时回血)
    if hp <= M:GetSetting("healHP") and not Player:IsMoving() then
        if LivingFlame:Cast(Player) then return end
    end

    -- ==================== 2. 脱战且非上马状态智能 Buff ====================
    if not Player:IsAffectingCombat() and not Player:IsMounted() then
        -- 团队祝福 Buff 青铜龙的祝福 (用 Buff ID 381748 检测，用施法 ID 364342 释放)
        local bronze = Player:GetAuras():FindMy(BlessingOfBronzeBuff)
        if not bronze or not bronze:IsUp() or bronze:GetRemainingTime() < 60 then
            if BlessingOfBronze:Cast(Player) then return end
        end
    end

    -- ==================== 3. 黑檀之力最高优先 (有敌对目标或进战时，第一件事激活/刷新) ====================
    local hasEnemyTarget = Target:IsValid() and Target:IsEnemy() and not Target:IsDead()
    if Player:IsAffectingCombat() or hasEnemyTarget then
        local emRem = GetEbonMightRemaining()
        if emRem <= 5.5 then
            if EbonMight:Cast(Player) then
                Bastion:Print("|cFF00FF00[黑檀之力]|r Pandemic 刷新黑檀之力！")
                return
            end
            -- Cast 失败 (GCD 中)：检查是否只是 GCD 阻挡，若是则阻止其他技能直到黑檀释放
            local cdInfo = C_Spell.GetSpellCooldown(EbonMight:GetID())
            local cd = cdInfo and cdInfo.duration or 0
            if cd <= 1.5 then
                return  -- 仅 GCD 阻挡，等待下一 tick 优先释放黑檀
            end
        end
    end

    -- ==================== 4. 目标与打断判定 ====================
    if not Target:IsValid() or not Target:IsEnemy() or Target:IsDead() then return end

    -- 自动打断
    if HandleInterrupts() then return end

    -- 开启自动攻击
    if not Player:IsMounted() then
        if not AutoAttack:IsCurrent() and AutoAttack:IsInRange(Target) then
            AutoAttack:Cast(Target)
        end
    end

    -- ==================== 5. 移动与悬空智能处理 ====================
    -- 悬空 Buff 检测：有悬空或不移动时可释放蓄力/读条法术
    local isMoving = Player:IsMoving()
    local hoverBuff = Player:GetAuras():FindMy(Hover)
    local hasHover = hoverBuff and hoverBuff:IsUp()
    local canCastNonInstant = not isMoving or hasHover

    -- 移动中没有悬空时，尝试开启悬空 (悬空可在施法中释放，不打断)
    if isMoving and not hasHover and M:GetSetting("autoHover") then
        if Hover:Cast(Player) then
            Bastion:Print("|cFF00FF00[悬空辅助]|r 移动中自动施放悬空，实现自由读条！")
            canCastNonInstant = true
        end
    end

    -- ==================== 6. 非指向性战中辅助技能投送 ====================
    if Player:IsAffectingCombat() then
        if CastPrescienceOnBestFriend() then return end
    end

    -- ==================== 7. 指向性攻击技能 (实施高标准朝向与 LoS 视野统一过滤) ====================
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    -- 获取自身黑檀状态与当前精华资源数
    local hasEM = HasEbonMight()
    local emRem = GetEbonMightRemaining()
    local essence = GetEssence()
    local hasEssenceBurst = HasEssenceBurst()

    -- ------------------------------------------------------------------
    -- A. 【亘古吐息爆发连携】(黑檀激活时高优施放，瞬发冲锋类)
    -- ------------------------------------------------------------------
    if M:GetSetting("useCooldowns") and Player:IsAffectingCombat() then
        if hasEM then
            if CastBreathOfEons(Target) then
                Bastion:Print("|cFFFF00FF[亘古吐息]|r 黑檀激活，施放亘古吐息轰炸！")
                return
            end
        end
    end

    -- ------------------------------------------------------------------
    -- B. 【黑檀活性期维持链条】(已激活黑檀之力时，全力释放蓄力与喷发延长)
    -- ------------------------------------------------------------------
    if hasEM then
        -- 1. 精华迸发触发时，喷发免费最高优先施放 (瞬发，不受移动限制)
        if hasEssenceBurst then
            if Eruption:IsInRange(Target) then
                if Eruption:Cast(Target) then return end
            end
        end

        -- 2. 扭转天平 + 地壳激变 (蓄力技能，需站立或悬空)
        if canCastNonInstant and Upheaval:IsInRange(Target) then
            if M:GetSetting("useCooldowns") then
                TipTheScales:Cast(Player)
            end
            if Upheaval:Cast(Target) then return end
        end

        -- 3. 火焰吐息 (蓄力技能，需站立或悬空)
        if canCastNonInstant and FireBreath:IsInRange(Target) then
            if CastFireBreath(Target) then return end
        end

        -- 4. 喷发泄能 (瞬发，不受移动限制)
        if essence >= 2 then
            if Eruption:IsInRange(Target) then
                if Eruption:Cast(Target) then return end
            end
        end
    else
        -- ------------------------------------------------------------------
        -- C. 【非黑檀期正常输出】
        -- ------------------------------------------------------------------

        -- 获取黑檀之力的剩余冷却时间，如果小于10秒，则保留蓄力技能等黑檀
        local emCdInfo = C_Spell.GetSpellCooldown(EbonMight:GetID())
        local emCd = emCdInfo and emCdInfo.duration or 0
        local holdForEM = emCd > 0 and emCd < 10

        -- 1. 精华迸发触发时，免费施放喷发 (瞬发)
        if hasEssenceBurst then
            if Eruption:IsInRange(Target) then
                if Eruption:Cast(Target) then return end
            end
        end

        -- 2. 扭转天平 + 地壳激变 (蓄力，需站立或悬空，如果不需为黑檀预留)
        if canCastNonInstant and not holdForEM and Upheaval:IsInRange(Target) then
            if M:GetSetting("useCooldowns") then
                TipTheScales:Cast(Player)
            end
            if Upheaval:Cast(Target) then return end
        end

        -- 3. 火焰吐息 (蓄力，需站立或悬空，如果不需为黑檀预留)
        if canCastNonInstant and not holdForEM and FireBreath:IsInRange(Target) then
            if CastFireBreath(Target) then return end
        end

        -- 4. 喷发常规释放 (瞬发)
        if essence >= 2 then
            if Eruption:IsInRange(Target) then
                if Eruption:Cast(Target) then return end
            end
        end
    end

    -- ------------------------------------------------------------------
    -- D. 【平稳期/低能积蓄期填充机制】
    -- ------------------------------------------------------------------
    
    -- 1. 移动中无悬空时使用碧蓝打击瞬发攒能
    if isMoving and not hasHover then
        if AzureStrike:IsInRange(Target) then
            if AzureStrike:Cast(Target) then return end
        end
    end

    -- 2. 站立或有悬空时，使用活化烈焰常规积蓄精华碎片 (有读条，需站立或悬空)
    if canCastNonInstant then
        if LivingFlame:IsInRange(Target) then
            if LivingFlame:Cast(Target) then return end
        end
    else
        -- 移动中无悬空，降级为碧蓝打击
        if AzureStrike:IsInRange(Target) then
            if AzureStrike:Cast(Target) then return end
        end
    end

end)

Bastion:Register(M)
return M
