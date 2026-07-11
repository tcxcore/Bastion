-- Bastion UI 主控
-- 100% 基于魔兽原生 UI API 构建，完全不依赖任何外部插件库
-- 包含：圆形贴边小地图图标、现代化宽屏双栏控制面板、扁平化自定义控件

local tcx, Bastion = ...
local TCX = tcx

---@class BastionUI
local BastionUI = {}
BastionUI.__index = BastionUI

-- 面板尺寸 (现代化宽屏模式)
local PANEL_WIDTH  = 820
local PANEL_HEIGHT = 480
local SIDEBAR_WIDTH = 240
local CONTENT_WIDTH = PANEL_WIDTH - SIDEBAR_WIDTH - 20

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

for i = 0x30, 0x39 do VK_NAMES[i] = string.char(i) end
for i = 0x41, 0x5A do VK_NAMES[i] = string.char(i) end
for i = 0x60, 0x69 do VK_NAMES[i] = "Num" .. (i - 0x60) end

local MODIFIER_VKS = { 0x12, 0x11, 0x10 }  -- Alt, Ctrl, Shift
local BINDABLE_VKS = {}
for vk, _ in pairs(VK_NAMES) do
    if vk ~= 0x10 and vk ~= 0x11 and vk ~= 0x12 then
        table.insert(BINDABLE_VKS, vk)
    end
end

local function VkName(vk)
    return VK_NAMES[vk] or string.format("0x%X", vk)
end

local function HotkeyText(hk)
    if not hk or not hk.key or hk.key == 0 then return "None" end
    if hk.mod and hk.mod > 0 then
        return VkName(hk.mod) .. "+" .. VkName(hk.key)
    else
        return VkName(hk.key)
    end
end

--- 本地化文本代理（支持 L["key"] 索引语法，自动匹配客户端与配置语言）
local L = setmetatable({}, {
    __index = function(_, key)
        if Bastion.Locale and type(Bastion.Locale.GetLocale) == "function" then
            local strings = Bastion.Locale:GetLocale()
            return strings[key] or key
        end
        return key
    end,
})

local function GetSettingLabel(def)
    -- 优先获取用户在设置里当前选定的语言，若无则回退到客户端默认语言
    local lang = (Bastion.Locale and Bastion.Locale._lang) or (GetLocale and GetLocale()) or "enUS"
    if (lang == "zhCN" or lang == "zhTW") and def.labelZh then
        return def.labelZh
    end
    return def.label or def.key
end

----------------------------------------------------------------------
-- 磨砂扁平化原生 UI 控件工厂 (Pure WoW API)
----------------------------------------------------------------------

-- 绘制扁平底面及一像素精致边框
local function ApplyFlatStyle(frame, bgColor, borderColor)
    bgColor = bgColor or { 0.12, 0.12, 0.12, 0.95 }
    borderColor = borderColor or { 0.22, 0.22, 0.22, 1 }

    -- 底色
    local bg = frame.flatBg or frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(unpack(bgColor))
    frame.flatBg = bg

    -- 四边 1px 细线
    local top = frame.flatBorderTop or frame:CreateTexture(nil, "BORDER")
    top:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    top:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(1)
    top:SetColorTexture(unpack(borderColor))
    frame.flatBorderTop = top

    local bottom = frame.flatBorderBottom or frame:CreateTexture(nil, "BORDER")
    bottom:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(1)
    bottom:SetColorTexture(unpack(borderColor))
    frame.flatBorderBottom = bottom

    local left = frame.flatBorderLeft or frame:CreateTexture(nil, "BORDER")
    left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(1)
    left:SetColorTexture(unpack(borderColor))
    frame.flatBorderLeft = left

    local right = frame.flatBorderRight or frame:CreateTexture(nil, "BORDER")
    right:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(1)
    right:SetColorTexture(unpack(borderColor))
    frame.flatBorderRight = right
end

-- 创建现代扁平按钮
local function CreateFlatButton(parent, text, width, height, isAccent)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(width, height)

    local normalColor = isAccent and { 0.70, 0.15, 0.15, 1 } or { 0.20, 0.20, 0.20, 1 }
    local hoverColor  = isAccent and { 0.85, 0.20, 0.20, 1 } or { 0.30, 0.30, 0.30, 1 }
    local borderColor = { 0.35, 0.35, 0.35, 1 }

    ApplyFlatStyle(btn, normalColor, borderColor)

    local fontString = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fontString:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fontString:SetText(text)
    fontString:SetTextColor(1, 1, 1, 1)
    btn.fontString = fontString

    btn:SetScript("OnEnter", function(self)
        self.flatBg:SetColorTexture(unpack(hoverColor))
    end)
    btn:SetScript("OnLeave", function(self)
        self.flatBg:SetColorTexture(unpack(normalColor))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self.fontString:SetPoint("CENTER", self, "CENTER", 1, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.fontString:SetPoint("CENTER", self, "CENTER", 0, 0)
    end)

    return btn
end

-- 创建磨砂复选框
local function CreateFlatCheckbox(parent, labelText, onClickCallback)
    local cb = CreateFrame("CheckButton", nil, parent)
    cb:SetSize(18, 18)

    ApplyFlatStyle(cb, { 0.15, 0.15, 0.15, 1 }, { 0.35, 0.35, 0.35, 1 })

    -- 选中时的指示绿块
    local checkedTexture = cb:CreateTexture(nil, "OVERLAY")
    checkedTexture:SetSize(10, 10)
    checkedTexture:SetPoint("CENTER", cb, "CENTER", 0, 0)
    checkedTexture:SetColorTexture(0.0, 0.8, 0.2, 1)
    cb:SetCheckedTexture(checkedTexture)

    -- 点击音效与事件
    cb:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        if onClickCallback then
            onClickCallback(self:GetChecked() == true)
        end
    end)

    -- 标签文字
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("LEFT", cb, "RIGHT", 8, 0)
    label:SetText(labelText)
    cb.label = label

    return cb
end

-- 创建磨砂滑块
local function CreateFlatSlider(parent, labelText, width, minVal, maxVal, step)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width, 14)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    -- 轨道底色
    local bg = slider:CreateTexture(nil, "BACKGROUND")
    bg:SetHeight(4)
    bg:SetPoint("LEFT", slider, "LEFT", 0, 0)
    bg:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    bg:SetColorTexture(0.18, 0.18, 0.18, 1)

    -- 游标滑块
    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(8, 14)
    thumb:SetColorTexture(0.70, 0.15, 0.15, 1)
    slider:SetThumbTexture(thumb)

    -- 左上角名称标签
    local label = slider:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 4)
    label:SetText(labelText)
    slider.label = label

    -- 右上角数值指示
    local valueText = slider:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    valueText:SetPoint("BOTTOMRIGHT", slider, "TOPRIGHT", 0, 4)
    slider.valueText = valueText

    slider:SetScript("OnValueChanged", function(self, value)
        local fmt = (step % 1 == 0) and "%.0f" or "%.1f"
        self.valueText:SetText(string.format(fmt, value))
        if self.callback then
            self.callback(value)
        end
    end)

    slider.SetValueCallback = function(self, cb)
        self.callback = cb
    end

    return slider
end

-- 创建无污染扁平下拉列表
local function CreateFlatDropdown(parent, labelText, width)
    local dd = CreateFrame("Frame", nil, parent)
    dd:SetSize(width, 24)

    -- 主体选择按钮
    local btn = CreateFrame("Button", nil, dd)
    btn:SetAllPoints(dd)
    ApplyFlatStyle(btn, { 0.18, 0.18, 0.18, 1 }, { 0.35, 0.35, 0.35, 1 })

    local label = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOMLEFT", btn, "TOPLEFT", 0, 4)
    label:SetText(labelText)
    dd.label = label

    local valText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    valText:SetPoint("LEFT", btn, "LEFT", 8, 0)
    valText:SetText(L["Select Option"])
    dd.valText = valText

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    arrow:SetText("▼")
    arrow:SetTextColor(0.6, 0.6, 0.6, 1)

    -- 弹出项菜单（覆盖在界面上层）
    local menu = CreateFrame("Frame", nil, btn)
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width, 100)
    menu:SetFrameLevel(btn:GetFrameLevel() + 10)
    ApplyFlatStyle(menu, { 0.14, 0.14, 0.14, 0.98 }, { 0.40, 0.40, 0.40, 1 })
    menu:Hide()
    dd.menu = menu

    btn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if menu:IsShown() then menu:Hide() else menu:Show() end
    end)

    local items = {}
    dd.SetItems = function(self, newItems)
        items = newItems or {}
        -- 移除旧子项
        if self.menu.buttons then
            for _, b in ipairs(self.menu.buttons) do b:Hide() b:SetParent(nil) end
        end
        self.menu.buttons = {}

        local itemHeight = 20
        local totalHeight = #items * itemHeight + 6
        self.menu:SetHeight(totalHeight)

        for i, item in ipairs(items) do
            local b = CreateFrame("Button", nil, self.menu)
            b:SetSize(width - 6, itemHeight)
            b:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 3, -((i-1)*itemHeight + 3))

            -- 鼠标悬停高亮
            local highlight = b:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints(b)
            highlight:SetColorTexture(0.3, 0.3, 0.3, 0.5)
            highlight:Hide()
            b.highlight = highlight

            b:SetScript("OnEnter", function(self) self.highlight:Show() end)
            b:SetScript("OnLeave", function(self) self.highlight:Hide() end)

            local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            t:SetPoint("LEFT", b, "LEFT", 5, 0)
            t:SetText(item.text)

            b:SetScript("OnClick", function()
                PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
                self.valText:SetText(item.text)
                self.selectedVal = item.value
                self.menu:Hide()
                if self.onSelectCallback then
                    self.onSelectCallback(item.value)
                end
            end)

            table.insert(self.menu.buttons, b)
        end
    end

    dd.SetSelectedValue = function(self, val)
        self.selectedVal = val
        for _, item in ipairs(items) do
            if item.value == val then
                self.valText:SetText(item.text)
                return
            end
        end
        self.valText:SetText(L["Select Option"])
    end

    dd.SetOnSelect = function(self, cb)
        self.onSelectCallback = cb
    end

    return dd
end

-- 创建极简无边框 ScrollFrame (包含扁平指示滚动条)
local function CreateFlatScrollFrame(parent, width, height)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetSize(width, height)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(width - 8, 100)
    sf:SetScrollChild(content)
    sf.scrollContent = content

    -- 滚动条轨道 (深灰色透明背景)
    local track = sf:CreateTexture(nil, "BACKGROUND")
    track:SetSize(4, height)
    track:SetPoint("RIGHT", sf, "RIGHT", 0, 0)
    track:SetColorTexture(0.15, 0.15, 0.15, 0.3)
    sf.track = track

    -- 滚动条滑块 (暗红色扁平设计)
    local thumb = sf:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(4)
    thumb:SetColorTexture(0.70, 0.15, 0.15, 0.8)
    thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    sf.thumb = thumb

    -- 更新滚动条状态
    local function UpdateScrollbar(self)
        local range = self:GetVerticalScrollRange()
        local contentHeight = self.scrollContent:GetHeight()
        local viewHeight = self:GetHeight()

        -- 安全过滤与除零防御：内容高度不足或视口异常时一律隐藏，绝不产生长条溢出
        if range <= 0 or contentHeight <= 0 or viewHeight <= 0 or contentHeight <= viewHeight then
            self.thumb:Hide()
            self.track:Hide()
            return
        end
        self.thumb:Show()
        self.track:Show()

        local scroll = self:GetVerticalScroll()

        -- 计算滑块高度
        local thumbHeight = (viewHeight / contentHeight) * viewHeight
        if thumbHeight < 15 then thumbHeight = 15 end
        if thumbHeight > viewHeight then thumbHeight = viewHeight end
        self.thumb:SetHeight(thumbHeight)

        local percent = scroll / range
        local maxThumbY = viewHeight - thumbHeight
        local thumbY = - (percent * maxThumbY)
        
        -- 防溢出坐标锁定
        if thumbY > 0 then thumbY = 0 end
        if math.abs(thumbY) > maxThumbY then thumbY = -maxThumbY end
        
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, thumbY)
    end

    -- 极简滑轮滚动绑定
    sf:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local newScroll = current - delta * 25
        if newScroll < 0 then newScroll = 0 end
        local maxScroll = self:GetVerticalScrollRange()
        if newScroll > maxScroll then newScroll = maxScroll end
        self:SetVerticalScroll(newScroll)
        UpdateScrollbar(self)
    end)

    -- 监听魔兽垂直滚动以刷新滑块位置
    sf:SetScript("OnVerticalScroll", function(self, offset)
        UpdateScrollbar(self)
    end)

    -- 监听显示事件，延迟刷新对齐
    sf:SetScript("OnShow", function(self)
        C_Timer.After(0.02, function()
            UpdateScrollbar(self)
        end)
    end)

    sf.SetContentHeight = function(self, newHeight)
        self.scrollContent:SetSize(width - 8, newHeight)
        UpdateScrollbar(self)
        -- 延迟下一帧再次刷新，对齐魔兽底层的异步 Layout 周期！
        C_Timer.After(0.02, function()
            UpdateScrollbar(self)
        end)
    end

    return sf
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
    self.minimapDB = { hide = false, angle = 0 }
    self._keyStates = {}

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
    -- 从配置中恢复快捷键和总开关状态
    if Bastion.ConfigManager then
        local cfg = Bastion.ConfigManager:LoadFrameworkSettings()
        if cfg then
            if cfg.hotkeys then
                for k, v in pairs(cfg.hotkeys) do
                    if self.hotkeys[k] then
                        self.hotkeys[k].mod = v.mod or self.hotkeys[k].mod
                        self.hotkeys[k].key = v.key or self.hotkeys[k].key
                    end
                end
            end
            if cfg.debugMode ~= nil then
                Bastion.DebugMode = cfg.debugMode
            end
            if cfg.bastionEnabled ~= nil then
                Bastion.Enabled = cfg.bastionEnabled
            end
            if cfg.minimapAngle then
                self.minimapDB.angle = cfg.minimapAngle
            end
            if cfg.language then
                self.language = cfg.language
                if Bastion.Locale then
                    Bastion.Locale._lang = cfg.language
                end
            else
                self.language = (GetLocale and GetLocale()) or "enUS"
            end
        end
    end

    self:CreateMinimapButton()
    self:CreateMainFrame()

    Bastion:Print(L["UI system initialized"] or "UI系统初始化完毕")
end

----------------------------------------------------------------------
-- 贴边小地图图标（100% 手动拖动计算）
----------------------------------------------------------------------

function BastionUI:CreateMinimapButton()
    local btn = CreateFrame("Button", "BastionMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:RegisterForClicks("AnyUp") -- 开启右键点击等所有事件注册支持
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    btn:SetMovable(true)

    -- 图标贴图（使用 Kyrian 图标，引入圆形 Mask 彻底切除方形黑角）
    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(25, 25)
    background:SetPoint("CENTER", btn, "CENTER", 0, 0)
    background:SetTexture("Interface\\Icons\\UI_Sigil_Kyrian")

    local mask = btn:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(background)
    background:AddMaskTexture(mask)

    -- 银质圆框（经精密物理坐标换算，采用黄金偏心拉正：向右下偏移 2px）
    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    -- 鼠标悬停高亮淡光
    btn:SetHighlightTexture("Interface\\Minimap\\RegularMinimap-Highlight")

    -- 圆周定位函数
    local function UpdatePosition(angle)
        local radius = (Minimap:GetWidth() / 2) + 12 -- 动态根据小地图宽度计算半径，确保完美贴在最外圈
        local x = radius * math.cos(angle)
        local y = radius * math.sin(angle)
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    -- 初始化位置
    UpdatePosition(self.minimapDB.angle or 0)

    -- 拖拽交互
    btn:RegisterForDrag("LeftButton")
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function(self)
            local mx, my = GetCursorPosition()
            local cx, cy = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()
            local x = (mx / scale) - cx
            local y = (my / scale) - cy
            local angle = math.atan2(y, x)
            btn.angle = angle
            UpdatePosition(angle)
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        if self.angle then
            self:GetParent().BastionUIObj.minimapDB.angle = self.angle
            self:GetParent().BastionUIObj:SaveFrameworkConfig()
        end
    end)

    -- 挂载反向引用方便拖动取回 DB
    Minimap.BastionUIObj = self

    -- 点击响应
    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            self:Toggle()
        elseif button == "RightButton" then
            Bastion.Enabled = not Bastion.Enabled
            if Bastion.Enabled then
                Bastion:Print(L["Enabled"] or "开启")
            else
                Bastion:Print(L["Disabled"] or "关闭")
            end
            self:UpdateStatusBar()
            self:SaveFrameworkConfig()
        end
    end)

    -- 悬停提示
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFDF362DBas|r|cFFFFFFFFtion|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Left-Click"] or "左键点击", L["Toggle UI panel"] or "控制面板显示/隐藏", 1,1,1, 0.8,0.8,0.8)
        GameTooltip:AddDoubleLine(L["Right-Click"] or "右键点击", L["Toggle Bastion on/off"] or "开关主框架", 1,1,1, 0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
end

----------------------------------------------------------------------
-- 现代化双栏宽屏主面板
----------------------------------------------------------------------

function BastionUI:CreateMainFrame()
    -- 主窗口
    local frame = CreateFrame("Frame", "BastionMainFrame", UIParent)
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameLevel(100)
    ApplyFlatStyle(frame, { 0.10, 0.10, 0.10, 0.96 }, { 0.22, 0.22, 0.22, 1 })
    self.frame = frame

    -- 右上角关闭按钮 (现代化扁平风格)
    local closeBtn = CreateFrame("Button", nil, frame)
    closeBtn:SetSize(22, 22)
    closeBtn:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 20)
    
    ApplyFlatStyle(closeBtn, { 0.15, 0.15, 0.15, 1 }, { 0.35, 0.35, 0.35, 1 })
    
    local closeText = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    closeText:SetPoint("CENTER", closeBtn, "CENTER", 0, 0)
    closeText:SetText("X")
    closeText:SetTextColor(0.7, 0.7, 0.7, 1)
    
    closeBtn:SetScript("OnEnter", function(self)
        self.flatBg:SetColorTexture(0.85, 0.20, 0.20, 1)
        closeText:SetTextColor(1, 1, 1, 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self.flatBg:SetColorTexture(0.15, 0.15, 0.15, 1)
        closeText:SetTextColor(0.7, 0.7, 0.7, 1)
    end)
    closeBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self:Toggle()
    end)

    -- ============================================================
    -- 左侧边栏 (Sidebar - 220px)
    -- ============================================================
    local sidebar = CreateFrame("Frame", nil, frame)
    sidebar:SetSize(SIDEBAR_WIDTH, PANEL_HEIGHT)
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    ApplyFlatStyle(sidebar, { 0.08, 0.08, 0.08, 0.98 }, { 0.20, 0.20, 0.20, 1 })

    -- 现代化 Logo
    local logo = sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    logo:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 15, -20)
    logo:SetText("|cFFDF362DBas|r|cFFFFFFFFtion|r")

    local logoSub = sidebar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    logoSub:SetPoint("LEFT", logo, "RIGHT", 6, 0)
    logoSub:SetText("|cFF666666Control|r")

    -- Tab 页选按钮
    local tabModules = CreateFlatButton(sidebar, L["Module Management"] or "模块管理", SIDEBAR_WIDTH - 20, 26, true)
    tabModules:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 10, -60)
    self.tabModulesBtn = tabModules

    local tabFramework = CreateFlatButton(sidebar, L["Framework Settings"] or "设置项", SIDEBAR_WIDTH - 20, 26, false)
    tabFramework:SetPoint("TOPLEFT", tabModules, "BOTTOMLEFT", 0, -8)
    self.tabFrameworkBtn = tabFramework

    tabModules:SetScript("OnClick", function() self:SwitchTab("modules") end)
    tabFramework:SetScript("OnClick", function() self:SwitchTab("framework") end)

    -- ============================================================
    -- 右侧主内容展示区 (480px)
    -- ============================================================
    local mainArea = CreateFrame("Frame", nil, frame)
    mainArea:SetSize(PANEL_WIDTH - SIDEBAR_WIDTH, PANEL_HEIGHT)
    mainArea:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    self.mainArea = mainArea

    -- 模块选择展示页
    self.modulesPage = CreateFrame("Frame", nil, mainArea)
    self.modulesPage:SetAllPoints(mainArea)

    -- 全局设置项页
    self.frameworkPage = CreateFrame("Frame", nil, mainArea)
    self.frameworkPage:SetAllPoints(mainArea)
    self.frameworkPage:Hide()

    -- ============================================================
    -- 页面内容渲染与构建
    -- ============================================================
    self:BuildModulesPage()
    self:BuildFrameworkPage()
    self:BuildStatusBar()

    frame:Hide()
end

-- Tab 页面切换
function BastionUI:SwitchTab(tab)
    self.currentTab = tab
    if tab == "modules" then
        self.tabModulesBtn.flatBg:SetColorTexture(0.70, 0.15, 0.15, 1) -- 高亮红
        self.tabFrameworkBtn.flatBg:SetColorTexture(0.20, 0.20, 0.20, 1) -- 暗灰色
        self.modulesPage:Show()
        self.frameworkPage:Hide()
    elseif tab == "framework" then
        self.tabModulesBtn.flatBg:SetColorTexture(0.20, 0.20, 0.20, 1)
        self.tabFrameworkBtn.flatBg:SetColorTexture(0.70, 0.15, 0.15, 1)
        self.modulesPage:Hide()
        self.frameworkPage:Show()
    end
end

----------------------------------------------------------------------
-- 模块管理页构建
----------------------------------------------------------------------

function BastionUI:BuildModulesPage()
    local page = self.modulesPage

    -- 模块切换下拉选择框
    local ddWidth = CONTENT_WIDTH - 20
    local moduleDropdown = CreateFlatDropdown(page, L["Select Module"] or "选择战斗模块", ddWidth)
    moduleDropdown:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -40)
    self.moduleDropdown = moduleDropdown

    moduleDropdown:SetOnSelect(function(value)
        self:OnModuleSelected(value)
    end)

    -- 滚动区
    local scrollFrame = CreateFlatScrollFrame(page, CONTENT_WIDTH - 10, PANEL_HEIGHT - 95)
    scrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -80)
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

    if self.selectedModule then
        self.moduleDropdown:SetSelectedValue(self.selectedModule.name)
    elseif #modules == 1 then
        self.moduleDropdown:SetSelectedValue(modules[1].name)
        self:OnModuleSelected(modules[1].name)
    end
end

function BastionUI:OnModuleSelected(moduleName)
    local modules = Bastion._MODULES or {}
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

    self:RefreshModules(modules)
    self:BuildModuleSettings(selectedModule)
    self:UpdateStatusBar()
    self:SaveConfig()
end

----------------------------------------------------------------------
-- 模块配置项动态手绘渲染
----------------------------------------------------------------------

function BastionUI:BuildModuleSettings(module)
    self:ClearSettingsWidgets()
    if not module then return end

    local scrollFrame = self.moduleScrollFrame
    local content = scrollFrame.scrollContent
    local defs = module:GetSettingDefinitions()

    if #defs == 0 then
        local noSettings = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        noSettings:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -15)
        noSettings:SetText(L["No settings available"] or "无可用配置项")
        noSettings:SetTextColor(0.5, 0.5, 0.5, 1)
        table.insert(self.settingsWidgets, noSettings)
        scrollFrame:SetContentHeight(40)
        return
    end

    -- 模块名总标题
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    title:SetText(module:GetDisplayName() .. " " .. (L["Settings"] or "配置项"))
    title:SetTextColor(0.9, 0.2, 0.2, 1)
    table.insert(self.settingsWidgets, title)

    -- 恢复默认值按钮
    local resetBtn = CreateFlatButton(content, L["Reset to Default"] or "恢复默认", 130, 20, false)
    resetBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -15, -5)
    resetBtn:SetScript("OnClick", function()
        module:ResetSettings()
        self:BuildModuleSettings(module)
        self:SaveConfig()
        Bastion:Print(L["Settings reset to default"] or "配置已重置为默认值")
    end)
    table.insert(self.settingsWidgets, resetBtn)

    local yOffset = 35
    local lastWidget = nil

    for _, def in ipairs(defs) do
        if def.type == "header" then
            -- 分组分割线
            local pane = CreateFrame("Frame", nil, content)
            pane:SetSize(CONTENT_WIDTH - 25, 20)
            if lastWidget then
                pane:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -15)
            else
                pane:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -(yOffset + 5))
            end

            local bgTex = pane:CreateTexture(nil, "BACKGROUND")
            bgTex:SetHeight(1)
            bgTex:SetPoint("LEFT", pane, "LEFT", 0, 0)
            bgTex:SetPoint("RIGHT", pane, "RIGHT", 0, 0)
            bgTex:SetColorTexture(0.2, 0.2, 0.2, 1)

            local txt = pane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            txt:SetPoint("LEFT", pane, "LEFT", 5, 0)
            txt:SetText(GetSettingLabel(def))
            txt:SetTextColor(0.7, 0.7, 0.7, 1)

            yOffset = yOffset + 25
            lastWidget = pane
            table.insert(self.settingsWidgets, pane)

        elseif def.type == "slider" then
            local slider = CreateFlatSlider(content, GetSettingLabel(def), CONTENT_WIDTH - 30, def.min or 0, def.max or 100, def.step or 1)
            if lastWidget then
                slider:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -28)
            else
                slider:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 15))
            end
            slider:SetValue(module:GetSetting(def.key) or def.default or def.min or 0)
            slider:SetValueCallback(function(value)
                module:SetSetting(def.key, value)
                self:SaveConfig()
            end)
            yOffset = yOffset + 48
            lastWidget = slider
            table.insert(self.settingsWidgets, slider)

        elseif def.type == "toggle" then
            local cb = CreateFlatCheckbox(content, GetSettingLabel(def), function(checked)
                module:SetSetting(def.key, checked)
                self:SaveConfig()
            end)
            if lastWidget then
                cb:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -10)
            else
                cb:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 5))
            end
            cb:SetChecked(module:GetSetting(def.key) or false)
            yOffset = yOffset + 26
            lastWidget = cb
            table.insert(self.settingsWidgets, cb)

        elseif def.type == "dropdown" then
            local dd = CreateFlatDropdown(content, GetSettingLabel(def), CONTENT_WIDTH - 30)
            if lastWidget then
                dd:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -24)
            else
                dd:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 15))
            end
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
            yOffset = yOffset + 45
            lastWidget = dd
            table.insert(self.settingsWidgets, dd)

        elseif def.type == "button" then
            local btn = CreateFlatButton(content, GetSettingLabel(def), CONTENT_WIDTH - 30, 22, true)
            if lastWidget then
                btn:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -10)
            else
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 5))
            end
            btn:SetScript("OnClick", function()
                if def.onClick then def.onClick() end
            end)
            yOffset = yOffset + 32
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
-- 框架全局设置页构建
----------------------------------------------------------------------

function BastionUI:BuildFrameworkPage()
    local page = self.frameworkPage

    local scrollFrame = CreateFlatScrollFrame(page, CONTENT_WIDTH - 10, PANEL_HEIGHT - 65)
    scrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -15)
    self.fwScrollFrame = scrollFrame
    local content = scrollFrame.scrollContent

    -- 快捷键分组分割线
    local hkPane = CreateFrame("Frame", nil, content)
    hkPane:SetSize(CONTENT_WIDTH - 25, 20)
    hkPane:SetPoint("TOPLEFT", content, "TOPLEFT", 5, -5)
    local l1 = hkPane:CreateTexture(nil, "BACKGROUND")
    l1:SetHeight(1) l1:SetPoint("LEFT", hkPane, "LEFT", 0, 0) l1:SetPoint("RIGHT", hkPane, "RIGHT", 0, 0)
    l1:SetColorTexture(0.2, 0.2, 0.2, 1)

    local txt1 = hkPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt1:SetPoint("LEFT", hkPane, "LEFT", 5, 0)
    txt1:SetText(L["Hotkey Settings"] or "全局快捷键设置")
    txt1:SetTextColor(0.7, 0.7, 0.7, 1)

    local tipText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    tipText:SetPoint("TOPLEFT", hkPane, "BOTTOMLEFT", 5, -8)
    tipText:SetText(L["Click button then press key combo"] or "点击按钮后按下组合键进行绑定：")
    tipText:SetTextColor(0.5, 0.5, 0.5, 1)

    local hotkeyEntries = {
        { id = "toggleBastion",  label = L["Toggle on/off"] or "主框架开关" },
        { id = "toggleUI",       label = L["Toggle UI panel"] or "面板显示/隐藏" },
        { id = "toggleModule",   label = L["Toggle current module"] or "当前模块开关" },
    }

    self._hotkeyButtons = {}
    local lastAnchor = tipText

    for _, entry in ipairs(hotkeyEntries) do
        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        lbl:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -16)
        lbl:SetWidth(150)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(entry.label)

        local btn = CreateFlatButton(content, HotkeyText(self.hotkeys[entry.id]), 150, 22, true)
        btn:SetPoint("LEFT", lbl, "RIGHT", 15, 0)

        local hotkeyId = entry.id
        btn:SetScript("OnClick", function()
            self:StartRecording(hotkeyId, btn)
        end)

        self._hotkeyButtons[entry.id] = btn
        lastAnchor = lbl
    end

    -- 通用设置线
    local generalPane = CreateFrame("Frame", nil, content)
    generalPane:SetSize(CONTENT_WIDTH - 25, 20)
    generalPane:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -25)
    local l2 = generalPane:CreateTexture(nil, "BACKGROUND")
    l2:SetHeight(1) l2:SetPoint("LEFT", generalPane, "LEFT", 0, 0) l2:SetPoint("RIGHT", generalPane, "RIGHT", 0, 0)
    l2:SetColorTexture(0.2, 0.2, 0.2, 1)

    local txt2 = generalPane:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    txt2:SetPoint("LEFT", generalPane, "LEFT", 5, 0)
    txt2:SetText(L["General Settings"] or "常规调试设置")
    txt2:SetTextColor(0.7, 0.7, 0.7, 1)

    -- 调试模式复选框
    local debugCB = CreateFlatCheckbox(content, L["Debug Mode"] or "调试模式输出", function(checked)
        Bastion.DebugMode = checked
        self:SaveFrameworkConfig()
        if checked then
            Bastion:Print(L["Debug mode enabled"] or "调试模式已开启")
        else
            Bastion:Print(L["Debug mode disabled"] or "调试模式已关闭")
        end
    end)
    debugCB:SetPoint("TOPLEFT", generalPane, "BOTTOMLEFT", 5, -15)
    debugCB:SetChecked(Bastion.DebugMode or false)
    self.debugCB = debugCB
 
    -- 语言设置下拉选择框
    local langDD = CreateFlatDropdown(content, L["Language"] or "界面语言", 180)
    langDD:SetPoint("TOPLEFT", debugCB, "BOTTOMLEFT", 0, -25)
    langDD:SetItems({
        { text = "简体中文 (zhCN)", value = "zhCN" },
        { text = "English (enUS)", value = "enUS" }
    })
    langDD:SetSelectedValue(self.language or (GetLocale and GetLocale()) or "enUS")
    langDD:SetOnSelect(function(val)
        self.language = val
        if Bastion.Locale then
            Bastion.Locale._lang = val
        end
        self:SaveFrameworkConfig()
        Bastion:Print(L["Language changed. Please Reload UI (/reload) to apply changes."] or "语言设置已修改，请重载界面（在聊天框输入 /reload）以应用更改。")
    end)
    self.langDD = langDD
 
    scrollFrame:SetContentHeight(350)
end

----------------------------------------------------------------------
-- 快捷键录制状态机
----------------------------------------------------------------------

function BastionUI:StartRecording(hotkeyId, btn)
    if self._recording then
        local oldBtn = self._hotkeyButtons[self._recording]
        if oldBtn then
            oldBtn.fontString:SetText(HotkeyText(self.hotkeys[self._recording]))
            oldBtn.flatBg:SetColorTexture(0.70, 0.15, 0.15, 1)
        end
    end

    self._recording = hotkeyId
    btn.fontString:SetText("|cFFFFFF00" .. (L["Press key combo..."] or "按下按键...") .. "|r")
    btn.flatBg:SetColorTexture(0.85, 0.20, 0.20, 1) -- 醒目红高亮
end

function BastionUI:StopRecording(mod, key)
    if not self._recording then return end

    local id = self._recording
    self.hotkeys[id].mod = mod
    self.hotkeys[id].key = key

    local btn = self._hotkeyButtons[id]
    if btn then
        btn.fontString:SetText(HotkeyText(self.hotkeys[id]))
        btn.flatBg:SetColorTexture(0.70, 0.15, 0.15, 1)
    end

    self._recording = nil
    self:SaveFrameworkConfig()
    self:UpdateStatusBar()
    Bastion:Print((L["Hotkey updated"] or "快捷键修改成功") .. ": " .. HotkeyText(self.hotkeys[id]))
end

function BastionUI:PollRecording()
    if not self._recording then return end
    if not TCX.GetKeyState then return end

    local activeMod = 0
    for _, modVK in ipairs(MODIFIER_VKS) do
        if select(1, TCX.GetKeyState(modVK)) then
            activeMod = modVK
            break
        end
    end

    for _, keyVK in ipairs(BINDABLE_VKS) do
        if select(1, TCX.GetKeyState(keyVK)) then
            if keyVK == 0x1B then -- Esc 取消绑定
                self:StopRecording(0, 0)
            else
                self:StopRecording(activeMod, keyVK)
            end
            return
        end
    end
end

----------------------------------------------------------------------
-- 现代化底部状态栏
----------------------------------------------------------------------

function BastionUI:BuildStatusBar()
    local bar = CreateFrame("Frame", nil, self.frame)
    bar:SetSize(PANEL_WIDTH - 20, 24)
    bar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 10, 8)
    ApplyFlatStyle(bar, { 0.08, 0.08, 0.08, 0.98 }, { 0.20, 0.20, 0.20, 1 })
    self.statusBar = bar

    self.statusText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.statusText:SetPoint("LEFT", bar, "LEFT", 10, 0)

    self.hotkeyHint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    self.hotkeyHint:SetPoint("RIGHT", bar, "RIGHT", -10, 0)
    self.hotkeyHint:SetTextColor(0.5, 0.5, 0.5, 1)

    self:UpdateStatusBar()
end

function BastionUI:UpdateStatusBar()
    if not self.statusText then return end

    local status
    if Bastion.Enabled then
        status = "|cFF00FF00●|r |cFF00FF00" .. (L["Enabled"] or "主系统开启") .. "|r"
    else
        status = "|cFFFF4444○|r |cFFFF4444" .. (L["Disabled"] or "主系统关闭") .. "|r"
    end
    if self.selectedModule and self.selectedModule.enabled then
        status = status .. "  |cFF555555|||r  |cFFDF362D" .. self.selectedModule:GetDisplayName() .. "|r"
    end
    self.statusText:SetText(status)

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

-- 快捷入口，用于在其他地方强制显示 UI
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
-- 配置保存持久化
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
            bastionEnabled = Bastion.Enabled or false,
            minimapAngle = self.minimapDB.angle or 0,
            language = self.language or (GetLocale and GetLocale()) or "enUS"
        })
    end
end

----------------------------------------------------------------------
-- 周期键盘快捷键轮询 (由主_bastion Ticker每0.1秒调用)
----------------------------------------------------------------------

function BastionUI:ProcessHotkeys()
    if not TCX.GetKeyState then return end

    if self._recording then
        self:PollRecording()
        return
    end

    self:_CheckHotkey("toggleBastion", function()
        Bastion.Enabled = not Bastion.Enabled
        if Bastion.Enabled then
            Bastion:Print(L["Enabled"] or "主系统开启")
        else
            Bastion:Print(L["Disabled"] or "主系统关闭")
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
                Bastion:Print(L["Enabled"] or "开启", self.selectedModule:GetDisplayName())
            else
                Bastion:Print(L["Disabled"] or "关闭", self.selectedModule:GetDisplayName())
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
