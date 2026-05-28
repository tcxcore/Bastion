-- Bastion UI 主控
-- 基于 AbstractFramework 构建游戏内 UI 管理界面
-- 包含：小地图图标、Tab 标签页（战斗模块 + 框架设置）、快捷键系统

local _, Bastion = ...
local TCX = Bastion.TCX
local AF = _G.AbstractFramework

---@class BastionUI
local BastionUI = {}
BastionUI.__index = BastionUI

-- 面板尺寸
local PANEL_WIDTH  = 520
local PANEL_HEIGHT = 580
local CONTENT_WIDTH = PANEL_WIDTH - 20

-- 默认快捷键配置（虚拟键码）
local DEFAULT_HOTKEYS = {
    toggleBastion  = { mod = 0x12, key = 0x70 },  -- Alt+F1
    toggleUI       = { mod = 0x12, key = 0x71 },  -- Alt+F2
    toggleModule   = { mod = 0x12, key = 0x72 },  -- Alt+F3
}

-- VK 码 → 显示名称映射
local VK_NAMES = {
    [0x10] = "Shift", [0x11] = "Ctrl", [0x12] = "Alt",
    [0x70] = "F1",  [0x71] = "F2",  [0x72] = "F3",  [0x73] = "F4",
    [0x74] = "F5",  [0x75] = "F6",  [0x76] = "F7",  [0x77] = "F8",
    [0x78] = "F9",  [0x79] = "F10", [0x7A] = "F11", [0x7B] = "F12",
    [0x09] = "Tab", [0x20] = "Space", [0x0D] = "Enter", [0x1B] = "Esc", [0x08] = "Backspace",
    [0x21] = "PgUp", [0x22] = "PgDn", [0x23] = "End", [0x24] = "Home",
    [0x25] = "Left", [0x26] = "Up", [0x27] = "Right", [0x28] = "Down",
    [0x2D] = "Insert", [0x2E] = "Delete", [0x14] = "CapsLock",
    [0xC0] = "~", [0xBD] = "-", [0xBB] = "=", [0xDB] = "[", [0xDD] = "]", [0xDC] = "\\",
    [0xBA] = ";", [0xDE] = "'", [0xBC] = ",", [0xBE] = ".", [0xBF] = "/",
}

-- 自动填充 0-9 和 A-Z
for i = 0x30, 0x39 do VK_NAMES[i] = string.char(i) end
for i = 0x41, 0x5A do VK_NAMES[i] = string.char(i) end
-- Numpad 0-9
for i = 0x60, 0x69 do VK_NAMES[i] = "Num" .. (i - 0x60) end

-- 修饰键 VK 列表（用于录制检测）
local MODIFIER_VKS = { 0x12, 0x11, 0x10 }  -- Alt, Ctrl, Shift

-- 可绑定的非修饰键 VK 列表（动态生成）
local BINDABLE_VKS = {}
for vk, _ in pairs(VK_NAMES) do
    if vk ~= 0x10 and vk ~= 0x11 and vk ~= 0x12 then
        table.insert(BINDABLE_VKS, vk)
    end
end

--- 根据 VK 码获取显示名
local function VkName(vk)
    return VK_NAMES[vk] or string.format("0x%X", vk)
end

--- 获取快捷键组合的显示文本
local function HotkeyText(hk)
    if not hk or not hk.key or hk.key == 0 then return "None" end
    if hk.mod and hk.mod > 0 then
        return VkName(hk.mod) .. "+" .. VkName(hk.key)
    else
        return VkName(hk.key)
    end
end

--- 本地化文本代理（支持 L["key"] 索引语法）
local L = setmetatable({}, {
    __index = function(_, key)
        return Bastion.Locale and Bastion.Locale[key] or key
    end,
})

--- 获取设置项的本地化标签
local function GetSettingLabel(def)
    local lang = (GetLocale and GetLocale()) or "enUS"
    if (lang == "zhCN" or lang == "zhTW") and def.labelZh then
        return def.labelZh
    end
    return def.label or def.key
end

----------------------------------------------------------------------
-- 构造
----------------------------------------------------------------------

function BastionUI:New()
    local self = setmetatable({}, BastionUI)

    self.frame = nil
    self.currentTab = "modules"
    self.selectedModule = nil
    self.settingsWidgets = {}
    self.minimapDB = { hide = false }
    self._keyStates = {}

    -- 快捷键配置（可通过 UI 修改）
    self.hotkeys = {
        toggleBastion  = { mod = DEFAULT_HOTKEYS.toggleBastion.mod,  key = DEFAULT_HOTKEYS.toggleBastion.key },
        toggleUI       = { mod = DEFAULT_HOTKEYS.toggleUI.mod,       key = DEFAULT_HOTKEYS.toggleUI.key },
        toggleModule   = { mod = DEFAULT_HOTKEYS.toggleModule.mod,   key = DEFAULT_HOTKEYS.toggleModule.key },
    }

    return self
end

----------------------------------------------------------------------
-- 初始化
----------------------------------------------------------------------

function BastionUI:Init()
    if not AF then
        Bastion:Print("|cFFFF4444[UI]|r AbstractFramework 未找到，UI 功能不可用")
        return
    end

    -- 从配置中恢复快捷键设置
    if Bastion.ConfigManager then
        local cfg = Bastion.ConfigManager:LoadFrameworkSettings()
        if cfg and cfg.hotkeys then
            for k, v in pairs(cfg.hotkeys) do
                if self.hotkeys[k] then
                    self.hotkeys[k].mod = v.mod or self.hotkeys[k].mod
                    self.hotkeys[k].key = v.key or self.hotkeys[k].key
                end
            end
        end
        if cfg and cfg.debugMode ~= nil then
            Bastion.DebugMode = cfg.debugMode
        end
        if cfg and cfg.bastionEnabled ~= nil then
            Bastion.Enabled = cfg.bastionEnabled
        end
    end

    self:CreateMinimapButton()
    self:CreateMainFrame()

    Bastion:Print(L["UI system initialized"])
end

----------------------------------------------------------------------
-- 小地图图标
----------------------------------------------------------------------

function BastionUI:CreateMinimapButton()
    local icon = "Interface\\Icons\\UI_Sigil_Kyrian"

    AF.NewMinimapButton("Bastion", icon, self.minimapDB,
        function(_, button)
            if button == "LeftButton" then
                self:Toggle()
            elseif button == "RightButton" then
                Bastion.Enabled = not Bastion.Enabled
                if Bastion.Enabled then
                    Bastion:Print(L["Enabled"])
                else
                    Bastion:Print(L["Disabled"])
                end
                self:UpdateStatusBar()
                self:SaveFrameworkConfig()
            end
        end,
        function(tt)
            tt:AddLine("|cFFDF362DBas|r|cFFFFFFFFtion|r")
            tt:AddLine(" ")
            tt:AddDoubleLine(L["Left-Click"], L["Toggle UI panel"], 1,1,1, 0.8,0.8,0.8)
            tt:AddDoubleLine(L["Right-Click"], L["Toggle Bastion on/off"], 1,1,1, 0.8,0.8,0.8)
            tt:AddLine(" ")
            tt:AddLine("|cFF888888" .. self:GetHotkeyDisplayText() .. "|r")
        end
    )
end

function BastionUI:GetHotkeyDisplayText()
    local hk = self.hotkeys
    return HotkeyText(hk.toggleBastion) .. ": " .. L["Toggle on/off"] .. "  |  " ..
           HotkeyText(hk.toggleUI) .. ": " .. L["Toggle UI panel"] .. "  |  " ..
           HotkeyText(hk.toggleModule) .. ": " .. L["Toggle current module"]
end

----------------------------------------------------------------------
-- 主面板
----------------------------------------------------------------------

function BastionUI:CreateMainFrame()
    local frame = AF.CreateHeaderedFrame(AF.UIParent, "BastionMainFrame",
        "|cFFDF362DBas|r|cFFFFFFFFtion|r " ..
        AF.WrapTextInColor(L["Control Panel"], "gray"),
        PANEL_WIDTH, PANEL_HEIGHT)
    AF.SetPoint(frame, "CENTER")
    frame:SetFrameLevel(100)
    frame:SetTitleJustify("LEFT")
    self.frame = frame

    -- ============================================================
    -- Tab 按钮
    -- ============================================================
    local halfW = (PANEL_WIDTH - 15) / 2

    local tabModules = AF.CreateButton(frame, L["Module Management"], "accent", halfW, 26)
    AF.SetPoint(tabModules, "TOPLEFT", 5, -5)
    self.tabModulesBtn = tabModules

    local tabFramework = AF.CreateButton(frame, L["Framework Settings"], "static", halfW, 26)
    AF.SetPoint(tabFramework, "TOPLEFT", tabModules, "TOPRIGHT", 5, 0)
    self.tabFrameworkBtn = tabFramework

    -- Tab 内容容器
    local contentFrame = AF.CreateBorderedFrame(frame, nil, PANEL_WIDTH - 10, PANEL_HEIGHT - 70)
    AF.SetPoint(contentFrame, "TOPLEFT", 5, -36)
    self.contentFrame = contentFrame

    -- 页面容器
    self.modulesPage = AF.CreateFrame(contentFrame)
    AF.SetPoint(self.modulesPage, "TOPLEFT")
    AF.SetPoint(self.modulesPage, "BOTTOMRIGHT")

    self.frameworkPage = AF.CreateFrame(contentFrame)
    AF.SetPoint(self.frameworkPage, "TOPLEFT")
    AF.SetPoint(self.frameworkPage, "BOTTOMRIGHT")
    self.frameworkPage:Hide()

    tabModules:SetOnClick(function() self:SwitchTab("modules") end)
    tabFramework:SetOnClick(function() self:SwitchTab("framework") end)

    -- ============================================================
    -- 页面构建
    -- ============================================================
    self:BuildModulesPage()
    self:BuildFrameworkPage()
    self:BuildStatusBar()

    frame:Hide()
end

----------------------------------------------------------------------
-- Tab 切换
----------------------------------------------------------------------

function BastionUI:SwitchTab(tab)
    self.currentTab = tab
    if tab == "modules" then
        self.tabModulesBtn:SetColor("accent")
        self.tabFrameworkBtn:SetColor("static")
        self.modulesPage:Show()
        self.frameworkPage:Hide()
    elseif tab == "framework" then
        self.tabModulesBtn:SetColor("static")
        self.tabFrameworkBtn:SetColor("accent")
        self.modulesPage:Hide()
        self.frameworkPage:Show()
    end
end

----------------------------------------------------------------------
-- Tab 1: 战斗模块页
----------------------------------------------------------------------

function BastionUI:BuildModulesPage()
    local page = self.modulesPage

    -- 模块选择下拉框
    local moduleDropdown = AF.CreateDropdown(page, CONTENT_WIDTH - 10)
    AF.SetPoint(moduleDropdown, "TOPLEFT", 10, -40)
    moduleDropdown:SetLabel(L["Select Module"])
    self.moduleDropdown = moduleDropdown

    -- 选中模块回调：切换激活 + 自动渲染设置
    moduleDropdown:SetOnSelect(function(value)
        self:OnModuleSelected(value)
    end)

    -- 模块设置滚动区域（直接在模块选择下方）
    local scrollFrame = AF.CreateScrollFrame(page, nil, CONTENT_WIDTH - 10, PANEL_HEIGHT - 175)
    AF.SetPoint(scrollFrame, "TOPLEFT", 10, -90)
    self.moduleScrollFrame = scrollFrame
end

function BastionUI:RefreshModules(modules)
    if not self.moduleDropdown then return end

    local items = {}
    for i = 1, #modules do
        local m = modules[i]
        local name = m:GetDisplayName()
        local statusDot = m.enabled and "|cFF00FF00●|r" or "|cFFFF4444○|r"
        table.insert(items, {
            ["text"] = statusDot .. " " .. name,
            ["value"] = m.name,
        })
    end

    self.moduleDropdown:SetItems(items)

    -- 保持当前选中
    if self.selectedModule then
        self.moduleDropdown:SetSelectedValue(self.selectedModule.name)
    elseif #modules == 1 then
        self.moduleDropdown:SetSelectedValue(modules[1].name)
        self:OnModuleSelected(modules[1].name)
    end
end

function BastionUI:OnModuleSelected(moduleName)
    local modules = Bastion._MODULES or {}

    -- 互斥激活：禁用所有模块，仅启用选中的
    local selectedModule = nil
    for i = 1, #modules do
        if modules[i].name == moduleName then
            modules[i]:Enable()
            selectedModule = modules[i]
        else
            modules[i]:Disable()
        end
    end

    if not selectedModule then return end
    self.selectedModule = selectedModule

    -- 刷新下拉框状态图标
    self:RefreshModules(modules)

    -- 绘制设置项
    self:BuildModuleSettings(selectedModule)

    -- 更新状态栏
    self:UpdateStatusBar()

    -- 保存配置
    self:SaveConfig()
end

----------------------------------------------------------------------
-- 模块设置项自动渲染
----------------------------------------------------------------------

function BastionUI:BuildModuleSettings(module)
    -- 清除旧控件
    self:ClearSettingsWidgets()

    if not module then return end

    local scrollFrame = self.moduleScrollFrame
    if not scrollFrame then return end

    local content = scrollFrame.scrollContent
    local defs = module:GetSettingDefinitions()

    if #defs == 0 then
        local noSettings = AF.CreateFontString(content, L["No settings available"], "gray")
        AF.SetPoint(noSettings, "TOPLEFT", 10, -15)
        table.insert(self.settingsWidgets, noSettings)
        scrollFrame:SetContentHeight(40)
        return
    end

    -- 模块标题
    local title = AF.CreateFontString(content,
        module:GetDisplayName() .. " " .. L["Settings"], "accent")
    AF.SetPoint(title, "TOPLEFT", 5, -5)
    table.insert(self.settingsWidgets, title)

    -- 恢复默认按钮
    local resetBtn = AF.CreateButton(content, L["Reset to Default"], "red", 100, 20)
    AF.SetPoint(resetBtn, "TOPRIGHT", content, -5, -5)
    resetBtn:SetOnClick(function()
        module:ResetSettings()
        self:BuildModuleSettings(module)
        self:SaveConfig()
        Bastion:Print(L["Settings reset to default"])
    end)
    table.insert(self.settingsWidgets, resetBtn)

    local yOffset = 30
    local lastWidget = nil

    for _, def in ipairs(defs) do
        if def.type == "header" then
            local pane = AF.CreateTitledPane(content, GetSettingLabel(def), CONTENT_WIDTH - 30, 20)
            if lastWidget then
                AF.SetPoint(pane, "TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -15)
            else
                AF.SetPoint(pane, "TOPLEFT", 0, -(yOffset + 5))
            end
            yOffset = yOffset + 35
            lastWidget = pane
            table.insert(self.settingsWidgets, pane)

        elseif def.type == "slider" then
            local slider = AF.CreateSlider(content, GetSettingLabel(def),
                CONTENT_WIDTH - 50,
                def.min or 0, def.max or 100, def.step or 1)
            if lastWidget then
                AF.SetPoint(slider, "TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -40)
            else
                AF.SetPoint(slider, "TOPLEFT", 10, -(yOffset + 25))
            end
            slider:SetValue(module:GetSetting(def.key) or def.default or def.min or 0)
            slider:SetAfterValueChanged(function(value)
                module:SetSetting(def.key, value)
                self:SaveConfig()
            end)
            yOffset = yOffset + 55
            lastWidget = slider
            table.insert(self.settingsWidgets, slider)

        elseif def.type == "toggle" then
            local cb = AF.CreateCheckButton(content, GetSettingLabel(def), function(checked)
                module:SetSetting(def.key, checked)
                self:SaveConfig()
            end)
            if lastWidget then
                AF.SetPoint(cb, "TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -10)
            else
                AF.SetPoint(cb, "TOPLEFT", 10, -(yOffset + 5))
            end
            cb:SetChecked(module:GetSetting(def.key) or false)
            yOffset = yOffset + 25
            lastWidget = cb
            table.insert(self.settingsWidgets, cb)

        elseif def.type == "dropdown" then
            local dd = AF.CreateDropdown(content, CONTENT_WIDTH - 50)
            if lastWidget then
                AF.SetPoint(dd, "TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -30)
            else
                AF.SetPoint(dd, "TOPLEFT", 10, -(yOffset + 20))
            end
            dd:SetLabel(GetSettingLabel(def))
            if def.options then
                dd:SetItems(def.options)
            end
            local currentVal = module:GetSetting(def.key)
            if currentVal then
                dd:SetSelectedValue(currentVal)
            end
            dd:SetOnSelect(function(value)
                module:SetSetting(def.key, value)
                self:SaveConfig()
            end)
            yOffset = yOffset + 50
            lastWidget = dd
            table.insert(self.settingsWidgets, dd)

        elseif def.type == "button" then
            local btn = AF.CreateButton(content, GetSettingLabel(def), "accent", def.width or 280, def.height or 22)
            if lastWidget then
                AF.SetPoint(btn, "TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -10)
            else
                AF.SetPoint(btn, "TOPLEFT", 10, -(yOffset + 5))
            end
            btn:SetOnClick(function()
                if def.onClick then
                    def.onClick()
                end
            end)
            yOffset = yOffset + 25
            lastWidget = btn
            table.insert(self.settingsWidgets, btn)
        end
    end

    scrollFrame:SetContentHeight(yOffset + 20)
end

function BastionUI:ClearSettingsWidgets()
    for _, w in ipairs(self.settingsWidgets) do
        if w.Hide then w:Hide() end
        if w.SetParent then w:SetParent(nil) end
    end
    self.settingsWidgets = {}
end

----------------------------------------------------------------------
-- Tab 2: 框架设置页
----------------------------------------------------------------------

function BastionUI:BuildFrameworkPage()
    local page = self.frameworkPage

    local scrollFrame = AF.CreateScrollFrame(page, nil, CONTENT_WIDTH - 10, PANEL_HEIGHT - 115)
    AF.SetPoint(scrollFrame, "TOPLEFT", 10, -10)
    self.fwScrollFrame = scrollFrame

    local content = scrollFrame.scrollContent

    -- ============================================================
    -- 快捷键设置
    -- ============================================================
    local hotkeyPane = AF.CreateTitledPane(content, L["Hotkey Settings"], CONTENT_WIDTH - 30, 20)
    AF.SetPoint(hotkeyPane, "TOPLEFT", 0, -5)

    -- 提示文字
    local tipText = AF.CreateFontString(content, L["Click button then press key combo"], "gray")
    AF.SetPoint(tipText, "TOPLEFT", hotkeyPane, "BOTTOMLEFT", 5, -8)

    local hotkeyEntries = {
        { id = "toggleBastion",  label = L["Toggle on/off"] },
        { id = "toggleUI",       label = L["Toggle UI panel"] },
        { id = "toggleModule",   label = L["Toggle current module"] },
    }

    self._hotkeyButtons = {}
    local lastAnchor = tipText

    for _, entry in ipairs(hotkeyEntries) do
        -- 功能名标签（固定宽度，左对齐）
        local lbl = AF.CreateFontString(content, entry.label, "white")
        AF.SetPoint(lbl, "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -18)
        lbl:SetWidth(130)
        lbl:SetJustifyH("LEFT")

        -- 录制按钮（显示当前快捷键，点击进入录制模式）
        local btn = AF.CreateButton(content, HotkeyText(self.hotkeys[entry.id]), "accent", 150, 22)
        AF.SetPoint(btn, "LEFT", lbl, "RIGHT", 15, 0)

        local hotkeyId = entry.id
        btn:SetOnClick(function()
            self:StartRecording(hotkeyId, btn)
        end)

        self._hotkeyButtons[entry.id] = btn
        lastAnchor = lbl
    end

    -- ============================================================
    -- 通用设置
    -- ============================================================
    local generalPane = AF.CreateTitledPane(content, L["General Settings"], CONTENT_WIDTH - 30, 20)
    AF.SetPoint(generalPane, "TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -25)

    -- 调试模式
    local debugCB = AF.CreateCheckButton(content, L["Debug Mode"], function(checked)
        Bastion.DebugMode = checked
        self:SaveFrameworkConfig()
        if checked then
            Bastion:Print(L["Debug mode enabled"])
        else
            Bastion:Print(L["Debug mode disabled"])
        end
    end)
    AF.SetPoint(debugCB, "TOPLEFT", generalPane, "BOTTOMLEFT", 5, -15)
    debugCB:SetChecked(Bastion.DebugMode or false)
    self.debugCB = debugCB

    scrollFrame:SetContentHeight(280)
end

----------------------------------------------------------------------
-- 快捷键录制
----------------------------------------------------------------------

function BastionUI:StartRecording(hotkeyId, btn)
    -- 如果已在录制另一个，先取消
    if self._recording then
        local oldBtn = self._hotkeyButtons[self._recording]
        if oldBtn then
            oldBtn:SetText(HotkeyText(self.hotkeys[self._recording]))
            oldBtn:SetColor("accent")
        end
    end

    self._recording = hotkeyId
    btn:SetText("|cFFFFFF00" .. L["Press key combo..."] .. "|r")
    btn:SetColor("red")
end

function BastionUI:StopRecording(mod, key)
    if not self._recording then return end

    local id = self._recording
    self.hotkeys[id].mod = mod
    self.hotkeys[id].key = key

    local btn = self._hotkeyButtons[id]
    if btn then
        btn:SetText(HotkeyText(self.hotkeys[id]))
        btn:SetColor("accent")
    end

    self._recording = nil
    self:SaveFrameworkConfig()
    self:UpdateStatusBar()
    Bastion:Print(L["Hotkey updated"] .. ": " .. HotkeyText(self.hotkeys[id]))
end

--- 在 ProcessHotkeys 中调用，检测录制状态下的按键
function BastionUI:PollRecording()
    if not self._recording then return end
    if not TCX.GetKeyState then return end

    -- 检测修饰键
    local activeMod = 0
    for _, modVK in ipairs(MODIFIER_VKS) do
        if select(1, TCX.GetKeyState(modVK)) then
            activeMod = modVK
            break
        end
    end

    -- 检测非修饰键
    for _, keyVK in ipairs(BINDABLE_VKS) do
        if select(1, TCX.GetKeyState(keyVK)) then
            if keyVK == 0x1B then -- Esc
                self:StopRecording(0, 0)
            else
                self:StopRecording(activeMod, keyVK)
            end
            return
        end
    end
end

----------------------------------------------------------------------
-- 状态栏
----------------------------------------------------------------------

function BastionUI:BuildStatusBar()
    local bar = AF.CreateBorderedFrame(self.frame, nil, PANEL_WIDTH - 10, 24)
    AF.SetPoint(bar, "BOTTOMLEFT", self.frame, 5, 5)
    self.statusBar = bar

    self.statusText = AF.CreateFontString(bar, "", "white")
    AF.SetPoint(self.statusText, "LEFT", 8, 0)
    self.statusText:SetJustifyH("LEFT")

    self.hotkeyHint = AF.CreateFontString(bar, "", "gray")
    AF.SetPoint(self.hotkeyHint, "RIGHT", -8, 0)

    self:UpdateStatusBar()
end

function BastionUI:UpdateStatusBar()
    if not self.statusText then return end

    -- 左侧：Bastion 状态 + 当前模块
    local status
    if Bastion.Enabled then
        status = "|cFF00FF00●|r " .. AF.WrapTextInColor("Bastion: " .. L["Enabled"], "green")
    else
        status = "|cFFFF4444○|r " .. AF.WrapTextInColor("Bastion: " .. L["Disabled"], "red")
    end
    if self.selectedModule and self.selectedModule.enabled then
        status = status .. "  |cFF888888|||r  " .. AF.WrapTextInColor(self.selectedModule:GetDisplayName(), "accent")
    end
    self.statusText:SetText(status)

    -- 右侧：快捷键提示
    if self.hotkeyHint then
        local hk = self.hotkeys
        self.hotkeyHint:SetText(
            HotkeyText(hk.toggleBastion) .. " / " ..
            HotkeyText(hk.toggleUI) .. " / " ..
            HotkeyText(hk.toggleModule)
        )
    end
end

----------------------------------------------------------------------
-- 显示/隐藏
----------------------------------------------------------------------

function BastionUI:Toggle()
    if not self.frame then return end
    if self.frame:IsShown() then
        self.frame:Hide()
    else
        self:RefreshModules(Bastion._MODULES or {})
        self:UpdateStatusBar()
        self.frame:Show()
    end
end

function BastionUI:Show()
    if self.frame then
        self:RefreshModules(Bastion._MODULES or {})
        self:UpdateStatusBar()
        self.frame:Show()
    end
end

function BastionUI:Hide()
    if self.frame then self.frame:Hide() end
end

function BastionUI:IsShown()
    return self.frame and self.frame:IsShown()
end

----------------------------------------------------------------------
-- 配置保存
----------------------------------------------------------------------

function BastionUI:SaveConfig()
    if Bastion.ConfigManager and Bastion._MODULES then
        Bastion.ConfigManager:SaveAll(Bastion._MODULES, Bastion.Enabled)
    end
end

function BastionUI:SaveFrameworkConfig()
    if Bastion.ConfigManager then
        Bastion.ConfigManager:SaveFrameworkSettings({
            hotkeys = self.hotkeys,
            debugMode = Bastion.DebugMode or false,
            bastionEnabled = Bastion.Enabled or false
        })
    end
end

----------------------------------------------------------------------
-- 快捷键系统
----------------------------------------------------------------------

function BastionUI:ProcessHotkeys()
    if not TCX.GetKeyState then return end

    -- 如果正在录制，优先处理录制逻辑
    if self._recording then
        self:PollRecording()
        return
    end

    -- 检测三组快捷键
    self:_CheckHotkey("toggleBastion", function()
        Bastion.Enabled = not Bastion.Enabled
        if Bastion.Enabled then
            Bastion:Print(L["Enabled"])
        else
            Bastion:Print(L["Disabled"])
        end
        self:UpdateStatusBar()
        self:SaveConfig()
        self:SaveFrameworkConfig()
    end)

    self:_CheckHotkey("toggleUI", function()
        self:Toggle()
    end)

    self:_CheckHotkey("toggleModule", function()
        if self.selectedModule then
            self.selectedModule:Toggle()
            if self.selectedModule.enabled then
                Bastion:Print(L["Enabled"], self.selectedModule:GetDisplayName())
            else
                Bastion:Print(L["Disabled"], self.selectedModule:GetDisplayName())
            end
            self:RefreshModules(Bastion._MODULES or {})
            self:UpdateStatusBar()
            self:SaveConfig()
        end
    end)
end

function BastionUI:_CheckHotkey(id, callback)
    local hk = self.hotkeys[id]
    if not hk or not hk.key or hk.key == 0 then return end

    local keyDown = select(1, TCX.GetKeyState(hk.key))
    if not keyDown then 
        self._keyStates[id] = nil
        return 
    end

    local modDown = true
    if hk.mod and hk.mod > 0 then
        modDown = select(1, TCX.GetKeyState(hk.mod))
    end

    local anyModDown = false
    for _, modVK in ipairs(MODIFIER_VKS) do
        if select(1, TCX.GetKeyState(modVK)) then
            anyModDown = true
            break
        end
    end

    local isValid = false
    if hk.mod and hk.mod > 0 then
        isValid = modDown and keyDown
    else
        isValid = (not anyModDown) and keyDown
    end

    if isValid and not self._keyStates[id] then
        self._keyStates[id] = true
        callback()
    end
end

return BastionUI
