local _, Bastion = ...
local L = Bastion.Locale

-- ======================================================================
-- 12.0.5 兽王猎人战斗循环 (Beast Mastery Hunter DPS Rotation)
-- 基于 Warcraft Logs 实战数据与 12.0.5 猎群领袖 (Pack Leader) 英雄天赋设计
-- 核心机制：
-- 1. 宠物 3 层狂乱 (Frenzy) Buff 精准续期覆盖，倒刺射击防溢出。
-- 2. AOE 模式自动监控宠物【野兽顺劈 (Beast Cleave)】状态，智能狂野鞭笞补齐。
-- 3. 狂野怒火开启前，智能消耗光倒刺射击充能以实现伤害最大化。
-- 4. 全套敌对指向性伤害/打断/控制技能强制绑定 Player:IsFacing(Target) 拦截。
-- ======================================================================

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')
local SpellBook = Bastion.SpellBook:New()

-- ======================================================================
-- 法术定义 (Spell Definitions)
-- ======================================================================

-- 基础与核心输出技能
local AutoShot          = SpellBook:GetSpell(75)      -- 自动射击
local KillCommand       = SpellBook:GetSpell(34026)   -- 杀戮命令 (最高伤害来源)
local BarbedShot        = SpellBook:GetSpell(217200)  -- 倒刺射击 (狂乱维持核心)
local CobraShot         = SpellBook:GetSpell(193455)  -- 眼镜蛇射击 (单体集中填充/减杀戮CD)

-- 爆发与大招技能
local BestialWrath      = SpellBook:GetSpell(19574)   -- 狂野怒火 (核心增伤大爆发)
local Bloodshed         = SpellBook:GetSpell(321530)  -- 血溅十方 (宠物撕咬流派增伤)
local WildLash          = SpellBook:GetSpell(1264359) -- 狂野鞭笞 (核心主力输出)
local Stampede          = SpellBook:GetSpell(201127)  -- 群兽奔腾 (爆发召唤大招)

-- 工具与防御自保技能
local CounterShot       = SpellBook:GetSpell(147362)  -- 反制射击 (打断)
local Exhilaration      = SpellBook:GetSpell(109304)  -- 意气风发 (强力自疗/宠疗)
local SurvivalOfTheFittest = SpellBook:GetSpell(264735) -- 优胜劣汰 (核心减伤)
local AspectOfTheTurtle = SpellBook:GetSpell(186265)  -- 灵龟守护 (无敌保命)
local MendPet           = SpellBook:GetSpell(136)     -- 治疗宠物
local RevivePet         = SpellBook:GetSpell(982)     -- 复活宠物
local Intimidation      = SpellBook:GetSpell(19577)   -- 胁迫 (单体眩晕)
local TranquilizingShot = SpellBook:GetSpell(19801)   -- 宁神射击 (驱散)
local HuntersMark       = SpellBook:GetSpell(257284)  -- 猎人印记
 
-- ======================================================================
-- BUFF/DEBUFF ID 定义
-- ======================================================================
local FrenzyBuff         = SpellBook:GetSpell(272790)  -- 宠物狂乱 Buff (3层满)
local BeastCleaveBuff    = SpellBook:GetSpell(268877)  -- 宠物野兽顺劈 Buff
local BestialWrathBuff   = BestialWrath                -- 狂野怒火 Buff
local HuntersMarkDebuff  = HuntersMark                 -- 猎人印记 Debuff (技能与Debuff同为257284)

-- ======================================================================
-- 模块定义
-- ======================================================================

---@class HunterBeastMaster : Module
local M = Bastion.Module:New("HunterBeastMaster")
M:SetDisplayName("BeastMaster Hunter", "野兽控制猎人")

M:DefineSettings({
    {
        type = "button",
        key = "exportTalents",
        label = "Copy Recommend Talents",
        labelZh = "复制推荐配置天赋导出",
        width = 280,
        onClick = function()
            local talentStr = "C0PAAAAAAAAAAAAAAAAAAAAAAAMmxwCsAzwQDbAAYGPwyMzsYGmZmZGzMMzMmhZGzMzYbmZYMDbDNDAAAAAAAAwMGDYmNADzCYbAA"
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
                    self:SetHeight(130)  -- 恢复面板默认高度
                    
                    -- 恢复原生 EditBox 的默认单行物理尺寸，按钮也会自动缩回默认位置！
                    self.EditBox:SetWidth(290)
                    self.EditBox:SetHeight(20)
                    self.EditBox:Show()  -- 恢复原生单行输入框的显示
                    
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
    
    { type = "header", label = "== General Settings ==", labelZh = "== 通用输出设置 ==" },
    {
        type = "toggle",
        key = "useCooldowns",
        label = "Use Cooldowns (Bestial Wrath)",
        labelZh = "自动释放爆发(狂野怒火/血溅)",
        default = true
    },
    {
        type = "toggle",
        key = "useAOE",
        label = "Use AOE (Wild Lash)",
        labelZh = "自动狂野鞭笞激活野兽顺劈",
        default = true
    },
    {
        type = "slider",
        key = "aoeTargets",
        label = "AOE Target Count",
        labelZh = "AOE 目标数量阈值",
        min = 2, max = 10, step = 1,
        default = 2
    },

    { type = "header", label = "== Defensive Settings ==", labelZh = "== 生存与防御设置 ==" },
    {
        type = "slider",
        key = "exhilarationHP",
        label = "Exhilaration HP (%)",
        labelZh = "意气风发血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 45
    },
    {
        type = "slider",
        key = "survivalHP",
        label = "Survival HP (%)",
        labelZh = "优胜劣汰血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 60
    },
    {
        type = "slider",
        key = "mendPetHP",
        label = "Mend Pet HP (%)",
        labelZh = "治疗宠物血量阈值 (%)",
        min = 0, max = 100, step = 5,
        default = 75
    },
    
    { type = "header", label = "== Interrupt Settings ==", labelZh = "== 智能打断设置 ==" },
    {
        type = "toggle",
        key = "useInterrupt",
        label = "Use Counter Shot",
        labelZh = "使用反制射击自动打断",
        default = true
    },
    {
        type = "toggle",
        key = "interruptFocus",
        label = "Interrupt Focus/Mouseover",
        labelZh = "自动打断焦点与鼠标指向",
        default = true
    },
    {
        type = "toggle",
        key = "useIntimidation",
        label = "Use Intimidation to Interrupt",
        labelZh = "使用胁迫进行控制打断",
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
-- 辅助功能函数
-- ======================================================================

--- 获取主目标周围的敌方数量
---@param range number
---@return number
local function GetEnemyCount(range)
    range = range or 10
    local count = 0
    Bastion.UnitManager:EnumUnits(function(unit)
        if unit:IsAlive() and unit:IsEnemy() and Target:GetDistance(unit) <= range then
            count = count + 1
        end
        return false
    end)
    return count
end

-- ======================================================================
-- 核心逻辑主体
-- ======================================================================

M:Sync(function()
    -- 正在施法或引导则跳过
    if Player:IsCastingOrChanneling() then return end

    -- 目标验证
    if not Target:IsValid() or Target:IsDead() or not Target:IsEnemy() then return end

    -- 开启自动射击 (无距离限制，不使用近战自动攻击)
    if not AutoShot:IsCurrent() then
        AutoShot:Cast(Target)
    end

    -- ==================================================================
    -- 1. 宠物存在性与宠物救援逻辑
    -- ==================================================================
    local Pet = Bastion.UnitManager:Get('pet')
    
    -- 宠物死亡复活处理 (战斗中最高优先级救援)
    if Pet and Pet:IsValid() and Pet:IsDead() then
        if RevivePet:IsKnownAndUsable() then
            -- 复活宠物通常需要站桩读条
            if not Player:IsMoving() then
                if RevivePet:Cast(Player) then return end
            end
        end
    end

    -- 治疗宠物 (持续性关怀)
    if Pet and Pet:IsValid() and not Pet:IsDead() then
        if Pet:GetHP() <= M:GetSetting("mendPetHP") and MendPet:IsKnownAndUsable() then
            local mendAura = Pet:GetAuras():FindMy(MendPet)
            if not mendAura:IsUp() then
                if MendPet:Cast(Player) then return end
            end
        end
    end

    -- ==================================================================
    -- 2. 自身防御与自保模块 (意气风发/优胜劣汰)
    -- ==================================================================
    local currentHP = Player:GetHP()

    -- 意气风发 (强回血，防暴毙，同时可救宠物)
    if currentHP <= M:GetSetting("exhilarationHP") and Exhilaration:IsKnownAndUsable() then
        if Exhilaration:Cast(Player) then return end
    end
    -- 如果宠物濒临死境（血量低于30%），意气风发也主动交出复活宠物血量
    if Pet and Pet:IsValid() and not Pet:IsDead() and Pet:GetHP() <= 30 and Exhilaration:IsKnownAndUsable() then
        if Exhilaration:Cast(Player) then return end
    end

    -- 优胜劣汰 (被动减伤)
    if currentHP <= M:GetSetting("survivalHP") and SurvivalOfTheFittest:IsKnownAndUsable() then
        if SurvivalOfTheFittest:Cast(Player) then return end
    end

    -- ==================================================================
    -- 3. 打断与驱散逻辑 (反制射击/胁迫/宁神射击)
    -- ==================================================================
    local function TryInterrupt(unit)
        if not unit or not unit:IsValid() or unit:IsDead() or not unit:IsEnemy() then return false end

        -- 1. 反制射击 (常规法术打断)
        if M:GetSetting("useInterrupt") and CounterShot:IsKnownAndUsable() then
            if unit:IsInterruptibleAt(M:GetSetting("interruptPercent"), false) then
                if CounterShot:IsInRange(unit) and Player:IsFacing(unit) and Player:CanSee(unit) then
                    if CounterShot:Cast(unit) then return true end
                end
            end
        end

        -- 2. 胁迫 (控制打断，当反制射击冷却中或目标不可常规打断但可被控制时，使用昏迷打断)
        if M:GetSetting("useIntimidation") and Intimidation:IsKnownAndUsable() then
            -- 仅在以下两种情况使用胁迫打断：
            -- A. 目标施法不可常规打断，但可以被控制打断 (ignoreInterruptible = true)
            -- B. 目标施法可常规打断，但反制射击不可用 (如在冷却中)，且施法进度快完成了 (>= 70%)
            local isCastNonInterruptible = unit:IsInterruptibleAt(M:GetSetting("interruptPercent"), true) and not unit:IsInterruptible()
            local isCounterShotUnavailable = not CounterShot:IsKnownAndUsable() and unit:IsInterruptibleAt(70, false)

            if isCastNonInterruptible or isCounterShotUnavailable then
                local pet = Bastion.UnitManager:Get('pet')
                if pet and pet:IsValid() and not pet:IsDead() then
                    if Intimidation:IsInRange(unit) and Player:IsFacing(unit) and Player:CanSee(unit) then
                        if Intimidation:Cast(unit) then return true end
                    end
                end
            end
        end

        return false
    end

    -- 执行目标打断
    if TryInterrupt(Target) then return end

    -- 执行焦点与鼠标指向打断
    if M:GetSetting("interruptFocus") then
        local focusUnit = Bastion.UnitManager:Get('focus')
        if focusUnit and focusUnit:IsValid() then
            if TryInterrupt(focusUnit) then return end
        end

        local mouseoverUnit = Bastion.UnitManager:Get('mouseover')
        if mouseoverUnit and mouseoverUnit:IsValid() then
            if TryInterrupt(mouseoverUnit) then return end
        end
    end

    -- ==================================================================
    -- 敌对指向前置安全墙 (面向与 LoS 视野统一拦截)
    -- 所有剩余技能（除防守与独立打断外）均为对 Target 施放的远程动作，
    -- 若背对目标或卡视野，则直接拦截本次 Ticker，极大节省 CPU 射线开销
    -- ==================================================================
    if not Player:IsFacing(Target) or not Player:CanSee(Target) then return end

    -- 宁神射击 (自动驱散敌方魔法或激怒效果，使用框架原生安全检测)
    if TranquilizingShot:IsKnownAndUsable() and TranquilizingShot:IsInRange(Target) then
        if Target:GetAuras():HasAnyDispelableAura(TranquilizingShot) then
            if TranquilizingShot:Cast(Target) then return end
        end
    end

    -- 自动标记猎人印记 (仅对血量高于 80% 且没有印记的目标进行施放，避免在战斗中低血量补印记浪费 GCD)
    if HuntersMark:IsKnownAndUsable() and HuntersMark:IsInRange(Target) then
        if Target:GetHP() > 80 then
            local markAura = Target:GetAuras():FindAny(HuntersMarkDebuff)
            if not markAura:IsUp() then
                if HuntersMark:Cast(Target) then return end
            end
        end
    end

    -- ==================================================================
    -- 4. 资源状态与多目标 AOE 计数
    -- ==================================================================
    local focus = Player:GetPower(2) or 0         -- 集中值
    local enemyCount = GetEnemyCount(10)          -- 目标周围敌人数量
    local useCDs = M:GetSetting("useCooldowns")
    local useAOE = M:GetSetting("useAOE")
    local aoeThreshold = M:GetSetting("aoeTargets")
    local isAoeMode = useAOE and enemyCount >= aoeThreshold

    -- ==================================================================
    -- 5. 宠物【狂乱 (Frenzy)】维持精算核心逻辑
    -- ==================================================================
    if Pet and Pet:IsValid() and not Pet:IsDead() and BarbedShot:IsKnownAndUsable() then
        local frenzyAura = Pet:GetAuras():FindMy(FrenzyBuff)
        local frenzyStacks = frenzyAura:IsUp() and (frenzyAura:GetCount() > 0 and frenzyAura:GetCount() or 1) or 0
        local frenzyRemain = frenzyAura:IsUp() and frenzyAura:GetRemain() or 0

        local charges = BarbedShot:GetCharges()
        local chargesFractional = BarbedShot:GetChargesFractional() or 0

        -- 判定 1: 宠物身上已有狂乱且即将断档 (剩余时间小于 1.2 秒)，立即打倒刺续杯！
        if frenzyStacks > 0 and frenzyRemain < 1.2 and charges >= 1 then
            if BarbedShot:IsInRange(Target) then
                if BarbedShot:Cast(Target) then return end
            end
        end

        -- 判定 2: 起手或因机制中断，宠物身上目前完全没有狂乱，且有可充能次数，立即打一发叠加
        if frenzyStacks == 0 and charges >= 1 then
            if BarbedShot:IsInRange(Target) then
                if BarbedShot:Cast(Target) then return end
            end
        end

        -- 判定 3: 倒刺射击的充能即将溢出 (浮点充能 >= 1.85，即快充出第 2 层了)，避免溢出损失：打一发出伤害
        if chargesFractional >= 1.85 then
            if BarbedShot:IsInRange(Target) then
                if BarbedShot:Cast(Target) then return end
            end
        end
    end

    -- ==================================================================
    -- 6. 多目标模式宠物【野兽顺劈 (Beast Cleave)】横扫维持
    -- ==================================================================
    if Pet and Pet:IsValid() and not Pet:IsDead() and isAoeMode and WildLash:IsKnownAndUsable() then
        local cleaveAura = Pet:GetAuras():FindMy(BeastCleaveBuff)
        local cleaveRemain = cleaveAura:IsUp() and cleaveAura:GetRemain() or 0

        -- 判定：野兽顺劈彻底断档，或剩余时间少于 0.8 秒时，智能打狂野鞭笞重新激活
        if not cleaveAura:IsUp() or cleaveRemain < 0.8 then
            if WildLash:IsInRange(Target) then
                if WildLash:Cast(Target) then return end
            end
        end
    end

    -- ==================================================================
    -- 7. 爆发CD爆发对齐与清空手牌 (WCL 核心打法)
    -- ==================================================================
    if useCDs then
        -- 1. 群兽奔腾 (Stampede)：高伤爆发，卡 CD 释放并召唤兽群
        if Stampede:IsKnownAndUsable() and Stampede:IsInRange(Target) then
            if Stampede:Cast(Target) then return end
        end

        -- 2. 狂野怒火 (Bestial Wrath)：
        -- 重要精算：开启狂怒会送满倒刺射击充能。所以在开狂野怒火前，我们尽量把手头已有的倒刺射击充能先全部扔空！
        if BestialWrath:IsKnownAndUsable() then
            local charges = BarbedShot:GetCharges()
            if charges >= 1 and BarbedShot:IsInRange(Target) then
                -- 先消耗一发倒刺射击
                if BarbedShot:Cast(Target) then return end
            else
                -- 手里没有倒刺，或者刚刚消耗完毕，完美对齐：开狂野怒火！
                if BestialWrath:Cast(Player) then return end
            end
        end

        -- 3. 血溅十方 (Bloodshed)：极高伤害，卡 CD 释出，并使宠物流血加深
        if Bloodshed:IsKnownAndUsable() and Bloodshed:IsInRange(Target) then
            if Bloodshed:Cast(Target) then return end
        end
    end

    -- ==================================================================
    -- 8. 核心输出循环 (平稳期)
    -- ==================================================================

    -- [优先级 1] 杀戮命令 (Kill Command)
    -- 卡 CD 优先打出，高伤害绝对主力核心
    if KillCommand:IsKnownAndUsable() and KillCommand:IsInRange(Target) then
        if KillCommand:Cast(Target) then return end
    end

    -- [优先级 2] 狂野鞭笞 (Wild Lash)
    -- 卡 CD 释放核心主力输出，伤害与 AOE 连携极高
    -- 注意：在 AOE 模式下，我们需要优先让【野兽顺劈维持模块】来精准打出它，
    -- 因此在这里，如果是 AOE 模式，只有当野兽顺劈剩余时间充足（例如 >= 1.5 秒）时，才作为普通填充技能使用，
    -- 避免提前消耗掉狂野鞭笞导致后续无法及时打出维持顺劈。
    if WildLash:IsKnownAndUsable() and WildLash:IsInRange(Target) then
        local cleaveAura = Pet and Pet:IsValid() and Pet:GetAuras():FindMy(BeastCleaveBuff)
        local cleaveRemain = cleaveAura and cleaveAura:IsUp() and cleaveAura:GetRemain() or 0
        if not isAoeMode or cleaveRemain >= 1.5 then
            if WildLash:Cast(Target) then return end
        end
    end

    -- [优先级 3] 眼镜蛇射击 (Cobra Shot) - 单体集中值填充/泄能
    -- 注意：在多目标 AOE 模式下，纯单体的眼镜蛇射击收益极低且浪费集中值，我们应当完全禁用它以全力留能给狂野鞭笞与杀戮顺劈。
    -- 仅在常规单体平稳期中：当集中值充沛 (>= 70点，或在狂野怒火 Buff 期间) 时，才使用眼镜蛇填充并借以减少杀戮冷却。
    if not isAoeMode and CobraShot:IsKnownAndUsable() and CobraShot:IsInRange(Target) then
        local isBWActive = Player:GetAuras():FindMy(BestialWrathBuff):IsUp()
        if isBWActive or focus >= 70 then
            if CobraShot:Cast(Target) then return end
        end
    end
end)

Bastion:Register(M)
return M
