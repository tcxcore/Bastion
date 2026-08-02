-- Bastion UI 主控 (Gather-Titan-Free 美化对齐版)
-- 基于魔兽原生 UI API 与 BackdropTemplate 构建
-- 包含：1024*576 宽屏双栏控制面板、暗青发光科技风格、高精美化控件 (Dropdown / Checkbox / EditBox / CloseButton)

local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx

---@class BastionUI
local BastionUI = {}
BastionUI.__index = BastionUI

-- 面板尺寸 (对齐 Gather-Titan 1024 * 576 宽屏标准布局)
local PANEL_WIDTH   = 1024
local PANEL_HEIGHT  = 576
local SIDEBAR_WIDTH = 180
local CONTENT_WIDTH = 780
local MAIN_CONTENT_HEIGHT = 485  -- 卡片延伸至底部，保留 5px 紧凑缝隙与 26px 状态栏

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
    local lang = (Bastion.Locale and Bastion.Locale._lang) or (GetLocale and GetLocale()) or "enUS"
    if (lang == "zhCN" or lang == "zhTW") and def.labelZh then
        return def.labelZh
    end
    return def.label or def.key
end

----------------------------------------------------------------------
-- Gather-Titan-Free 高精美化 Helper 函数
----------------------------------------------------------------------

-- 统一 EditBox 美化函数 (焦点亮蓝高亮 + 文本缩进)
local function StyleEditBox(editBox, width, height)
    editBox:SetSize(width or 120, height or 26)
    editBox:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    editBox:SetBackdropColor(0.04, 0.06, 0.1, 0.85)
    editBox:SetBackdropBorderColor(0.18, 0.4, 0.75, 0.5)
    editBox:SetFontObject("GameFontHighlightMed2")
    editBox:SetTextInsets(8, 8, 0, 0)

    editBox:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(0.18, 0.65, 1.0, 0.95)
        self:SetBackdropColor(0.06, 0.09, 0.16, 0.95)
    end)
    editBox:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0.18, 0.4, 0.75, 0.5)
        self:SetBackdropColor(0.04, 0.06, 0.1, 0.85)
    end)
end

-- 强效美化原生 DropDownList 弹出层菜单面板
local function SkinSingleDropDownList(list)
    if not list then return end
    
    if list.NineSlice then list.NineSlice:SetAlpha(0) end
    if list.Border then list.Border:SetAlpha(0) end

    local listName = list:GetName()
    if listName then
        local bd = _G[listName .. "Backdrop"] or _G[listName .. "MenuBackdrop"]
        if bd then
            if bd.NineSlice then bd.NineSlice:SetAlpha(0) end
            bd:SetAlpha(0)
        end
    end

    local regions = { list:GetRegions() }
    for _, region in ipairs(regions) do
        if region:IsObjectType("Texture") then
            local texturePath = region:GetTexture()
            if texturePath then
                region:SetAlpha(0)
            end
        end
    end

    if not list.customBg then
        local bg = CreateFrame("Frame", nil, list, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", 0, 0)
        bg:SetPoint("BOTTOMRIGHT", 0, 0)
        bg:SetFrameLevel(math.max(0, list:GetFrameLevel() - 1))
        bg:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        bg:SetBackdropColor(0.03, 0.05, 0.09, 0.95)
        bg:SetBackdropBorderColor(0.18, 0.45, 0.85, 0.9)
        list.customBg = bg
    end
end

local function SkinDropDownLists()
    for i = 1, 3 do
        local list = _G["DropDownList" .. i]
        if list then
            SkinSingleDropDownList(list)
            if list:IsShown() and not list.shiftedThisShow then
                list.shiftedThisShow = true
                local point, relTo, relPoint, xOfs, yOfs = list:GetPoint()
                if point and relTo then
                    list:SetPoint(point, relTo, relPoint, (xOfs or 0) + 8, yOfs or 0)
                end
            elseif not list:IsShown() then
                list.shiftedThisShow = false
            end
        end
    end
end

if type(hooksecurefunc) == "function" and not BastionUI.dropdownHooked then
    BastionUI.dropdownHooked = true
    hooksecurefunc("ToggleDropDownMenu", SkinDropDownLists)
    hooksecurefunc("UIDropDownMenu_CreateFrames", SkinDropDownLists)
    hooksecurefunc("UIDropDownMenu_SetText", function(frame, text)
        if frame then
            if frame.customText then
                frame.customText:SetText(text or "")
                frame.customText:SetTextColor(0.4, 0.9, 1.0, 1.0)
            end
            local name = frame:GetName()
            if name and _G[name .. "Text"] then
                _G[name .. "Text"]:SetAlpha(0)
            end
        end
    end)
end

-- Dropdown 容器美化 (支持原生与自定义 Dropdown)
local function StyleDropdown(dropdown, width)
    width = width or 220
    local name = dropdown:GetName()

    if width then
        UIDropDownMenu_SetWidth(dropdown, width)
    end

    local bg = dropdown.customBg
    if not bg then
        bg = CreateFrame("Frame", nil, dropdown, "BackdropTemplate")
        bg:SetPoint("TOPLEFT", 16, -2)
        bg:SetPoint("BOTTOMRIGHT", -25, 6)
        bg:SetBackdrop({
            bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            tile = true, tileSize = 12, edgeSize = 12,
            insets = { left = 2, right = 2, top = 2, bottom = 2 }
        })
        bg:SetBackdropColor(0.04, 0.06, 0.1, 0.9)
        bg:SetBackdropBorderColor(0.18, 0.45, 0.8, 0.7)
        dropdown.customBg = bg
    end

    if not dropdown.customText then
        local ct = bg:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
        ct:SetPoint("LEFT", bg, "LEFT", 10, 0)
        ct:SetPoint("RIGHT", bg, "RIGHT", -28, 0)
        ct:SetJustifyH("LEFT")
        ct:SetTextColor(0.4, 0.9, 1.0, 1.0)
        dropdown.customText = ct
    end

    if name then
        if _G[name .. "Left"] then _G[name .. "Left"]:SetAlpha(0) end
        if _G[name .. "Middle"] then _G[name .. "Middle"]:SetAlpha(0) end
        if _G[name .. "Right"] then _G[name .. "Right"]:SetAlpha(0) end
        if _G[name .. "Text"] then _G[name .. "Text"]:SetAlpha(0) end

        local btn = _G[name .. "Button"]
        if btn then
            btn:ClearAllPoints()
            btn:SetPoint("RIGHT", bg, "RIGHT", -1, 0)
            btn:SetSize(22, 22)

            local normal = btn:GetNormalTexture()
            if normal then normal:SetAlpha(0) end
            local pushed = btn:GetPushedTexture()
            if pushed then pushed:SetAlpha(0) end
            local disabled = btn:GetDisabledTexture()
            if disabled then disabled:SetAlpha(0) end
            local highlight = btn:GetHighlightTexture()
            if highlight then highlight:SetAlpha(0) end

            if not btn.customBg then
                local btnBg = CreateFrame("Frame", nil, btn, "BackdropTemplate")
                btnBg:SetAllPoints()
                btnBg:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                    tile = true, tileSize = 12, edgeSize = 12,
                    insets = { left = 1, right = 1, top = 1, bottom = 1 }
                })
                btnBg:SetBackdropColor(0.08, 0.14, 0.25, 0.95)
                btnBg:SetBackdropBorderColor(0.25, 0.6, 0.95, 0.9)

                local arrow = btnBg:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
                arrow:SetPoint("CENTER", 0, 0)
                arrow:SetText("▼")
                arrow:SetTextColor(0.4, 0.9, 1.0)
                btnBg.arrow = arrow

                btn:SetScript("OnEnter", function()
                    btnBg:SetBackdropBorderColor(0.4, 0.85, 1.0, 1.0)
                    btnBg:SetBackdropColor(0.12, 0.22, 0.38, 0.95)
                    arrow:SetTextColor(1.0, 1.0, 1.0)
                end)
                btn:SetScript("OnLeave", function()
                    btnBg:SetBackdropBorderColor(0.25, 0.6, 0.95, 0.9)
                    btnBg:SetBackdropColor(0.08, 0.14, 0.25, 0.95)
                    arrow:SetTextColor(0.4, 0.9, 1.0)
                end)

                btn.customBg = btnBg
            end
        end
    end
end

----------------------------------------------------------------------
-- 现代化 Backdrop 控件工厂 (Pure WoW BackdropTemplate)
----------------------------------------------------------------------

-- 创建 Gather-Titan 风格按钮
local function CreateFlatButton(parent, text, width, height, isAccent, isWarning)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    btn:SetSize(width or 120, height or 28)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    local normalBgColor     = isWarning and { 0.25, 0.05, 0.05, 0.6 } or (isAccent and { 0.1, 0.3, 0.6, 0.8 } or { 0.1, 0.15, 0.28, 0.6 })
    local normalBorderColor = isWarning and { 0.8, 0.15, 0.15, 0.8 } or (isAccent and { 0.2, 0.5, 0.9, 0.9 } or { 0.25, 0.35, 0.55, 0.7 })
    local hoverBgColor      = isWarning and { 0.35, 0.08, 0.08, 0.85 } or (isAccent and { 0.15, 0.45, 0.85, 0.95 } or { 0.15, 0.25, 0.45, 0.8 })
    local hoverBorderColor  = isWarning and { 0.95, 0.25, 0.25, 0.95 } or (isAccent and { 0.3, 0.7, 1.0, 1.0 } or { 0.35, 0.55, 0.85, 0.9 })
    local textColor         = (isAccent or isWarning) and { 1.0, 1.0, 1.0, 1.0 } or { 0.8, 0.9, 1.0, 1.0 }

    btn:SetBackdropColor(unpack(normalBgColor))
    btn:SetBackdropBorderColor(unpack(normalBorderColor))

    local fontString = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    fontString:SetPoint("CENTER", btn, "CENTER", 0, 0)
    fontString:SetText(text or "")
    fontString:SetTextColor(unpack(textColor))
    btn.fontString = fontString

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(unpack(hoverBgColor))
        self:SetBackdropBorderColor(unpack(hoverBorderColor))
        self.fontString:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(unpack(normalBgColor))
        self:SetBackdropBorderColor(unpack(normalBorderColor))
        self.fontString:SetTextColor(unpack(textColor))
    end)
    btn:SetScript("OnMouseDown", function(self)
        self.fontString:SetPoint("CENTER", self, "CENTER", 1, -1)
    end)
    btn:SetScript("OnMouseUp", function(self)
        self.fontString:SetPoint("CENTER", self, "CENTER", 0, 0)
    end)

    return btn
end

-- 创建 Gather-Titan 精密青蓝复选框
local function CreateFlatCheckbox(parent, labelText, onClickCallback)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    cb:SetSize(20, 20)

    cb:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })

    local checkMark = cb:CreateTexture(nil, "OVERLAY")
    checkMark:SetSize(12, 12)
    checkMark:SetPoint("CENTER", 0, 0)
    checkMark:SetColorTexture(0.18, 0.65, 1.0, 1.0)
    cb.checkMark = checkMark

    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    label:SetPoint("LEFT", cb, "RIGHT", 10, 0)
    label:SetText(labelText or "")
    label:SetTextColor(0.8, 0.9, 1.0)
    cb.label = label

    local function updateCheckState()
        if cb:GetChecked() then
            cb.checkMark:Show()
            cb:SetBackdropBorderColor(0.18, 0.65, 1.0, 0.95)
            cb:SetBackdropColor(0.08, 0.16, 0.28, 0.9)
        else
            cb.checkMark:Hide()
            cb:SetBackdropBorderColor(0.18, 0.4, 0.7, 0.6)
            cb:SetBackdropColor(0.04, 0.06, 0.1, 0.85)
        end
    end

    cb:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(0.3, 0.7, 1.0, 0.9)
    end)
    cb:SetScript("OnLeave", function(self)
        updateCheckState()
    end)

    cb:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
        updateCheckState()
        if onClickCallback then
            onClickCallback(self:GetChecked() == true)
        end
    end)

    local origSetChecked = cb.SetChecked
    cb.SetChecked = function(self, val)
        origSetChecked(self, val)
        updateCheckState()
    end

    updateCheckState()
    return cb
end

-- 创建 Gather-Titan 炫蓝滑动条
local function CreateFlatSlider(parent, labelText, width, minVal, maxVal, step)
    local sliderFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    sliderFrame:SetSize(width or 220, 50)
    sliderFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    sliderFrame:SetBackdropColor(0.03, 0.05, 0.08, 0.5)
    sliderFrame:SetBackdropBorderColor(0.12, 0.35, 0.7, 0.4)

    local label = sliderFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    label:SetPoint("TOPLEFT", sliderFrame, "TOPLEFT", 10, -6)
    label:SetText(labelText or "")
    label:SetTextColor(0.8, 0.9, 1.0)
    sliderFrame.label = label

    local valueText = sliderFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalMed2")
    valueText:SetPoint("TOPRIGHT", sliderFrame, "TOPRIGHT", -10, -6)
    valueText:SetTextColor(0.18, 0.65, 1.0)
    sliderFrame.valueText = valueText

    local slider = CreateFrame("Slider", nil, sliderFrame)
    slider:SetOrientation("HORIZONTAL")
    slider:SetSize(width - 24, 10)
    slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -8)
    slider:SetMinMaxValues(minVal or 0, maxVal or 100)
    slider:SetValueStep(step or 1)
    slider:SetObeyStepOnDrag(true)

    local bg = slider:CreateTexture(nil, "BACKGROUND")
    bg:SetHeight(4)
    bg:SetPoint("LEFT", slider, "LEFT", 0, 0)
    bg:SetPoint("RIGHT", slider, "RIGHT", 0, 0)
    bg:SetColorTexture(0.08, 0.14, 0.25, 0.8)

    local thumb = slider:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(10, 16)
    thumb:SetColorTexture(0.18, 0.65, 1.0, 1.0)
    slider:SetThumbTexture(thumb)

    slider:SetScript("OnValueChanged", function(self, value)
        local fmt = ((step or 1) % 1 == 0) and "%.0f" or "%.1f"
        sliderFrame.valueText:SetText(string.format(fmt, value))
        if sliderFrame.callback then
            sliderFrame.callback(value)
        end
    end)

    sliderFrame.SetValue = function(self, val) slider:SetValue(val) end
    sliderFrame.GetValue = function(self) return slider:GetValue() end
    sliderFrame.SetValueCallback = function(self, cb) self.callback = cb end

    return sliderFrame
end

-- 创建 Gather-Titan 风格下拉选择框 (自包含菜单，解决标题与按钮重叠问题)
local function CreateFlatDropdown(parent, labelText, width)
    local dd = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    dd:SetSize(width or 220, 52)
    dd:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    dd:SetBackdropColor(0.03, 0.05, 0.08, 0.5)
    dd:SetBackdropBorderColor(0.12, 0.35, 0.7, 0.4)

    -- 标题 Label 精确置顶
    local label = dd:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    label:SetPoint("TOPLEFT", dd, "TOPLEFT", 10, -6)
    label:SetText(labelText or "")
    label:SetTextColor(0.8, 0.9, 1.0)
    dd.label = label

    -- 选择按钮精确锚定在 Label 正下方 4px 处，彻底消除重叠
    local btn = CreateFrame("Button", nil, dd, "BackdropTemplate")
    btn:SetSize(width - 20, 24)
    btn:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -4)
    btn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    btn:SetBackdropColor(0.04, 0.06, 0.1, 0.9)
    btn:SetBackdropBorderColor(0.18, 0.45, 0.8, 0.7)

    local valText = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    valText:SetPoint("LEFT", btn, "LEFT", 10, 0)
    valText:SetText(L["Select Option"] or "选择选项")
    valText:SetTextColor(0.4, 0.9, 1.0, 1.0)
    dd.valText = valText

    local arrow = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    arrow:SetPoint("RIGHT", btn, "RIGHT", -8, 0)
    arrow:SetText("▼")
    arrow:SetTextColor(0.4, 0.9, 1.0)

    local menu = CreateFrame("Frame", nil, btn, "BackdropTemplate")
    menu:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -2)
    menu:SetSize(width - 20, 100)
    menu:SetFrameLevel(btn:GetFrameLevel() + 20)
    menu:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    menu:SetBackdropColor(0.03, 0.05, 0.09, 0.95)
    menu:SetBackdropBorderColor(0.18, 0.45, 0.85, 0.9)
    menu:Hide()
    dd.menu = menu

    btn:SetScript("OnEnter", function()
        btn:SetBackdropBorderColor(0.3, 0.7, 1.0, 0.9)
        arrow:SetTextColor(1, 1, 1)
    end)
    btn:SetScript("OnLeave", function()
        btn:SetBackdropBorderColor(0.18, 0.45, 0.8, 0.7)
        arrow:SetTextColor(0.4, 0.9, 1.0)
    end)
    btn:SetScript("OnClick", function(self)
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION)
        if menu:IsShown() then menu:Hide() else menu:Show() end
    end)

    local items = {}
    dd.SetItems = function(self, newItems)
        items = newItems or {}
        if self.menu.buttons then
            for _, b in ipairs(self.menu.buttons) do b:Hide() b:SetParent(nil) end
        end
        self.menu.buttons = {}

        local itemHeight = 22
        local totalHeight = #items * itemHeight + 6
        self.menu:SetHeight(totalHeight)

        for i, item in ipairs(items) do
            local b = CreateFrame("Button", nil, self.menu, "BackdropTemplate")
            b:SetSize(width - 26, itemHeight)
            b:SetPoint("TOPLEFT", self.menu, "TOPLEFT", 3, -((i-1)*itemHeight + 3))

            local highlight = b:CreateTexture(nil, "BACKGROUND")
            highlight:SetAllPoints(b)
            highlight:SetColorTexture(0.15, 0.3, 0.55, 0.6)
            highlight:Hide()
            b.highlight = highlight

            b:SetScript("OnEnter", function(self) self.highlight:Show() end)
            b:SetScript("OnLeave", function(self) self.highlight:Hide() end)

            local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
            t:SetPoint("LEFT", b, "LEFT", 8, 0)
            t:SetText(item.text)
            t:SetTextColor(0.8, 0.9, 1.0)

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
        self.valText:SetText(L["Select Option"] or "选择选项")
    end

    dd.SetOnSelect = function(self, cb)
        self.onSelectCallback = cb
    end

    return dd
end

-- 创建 Gather-Titan 极简 ScrollFrame (包含暗蓝发光轨道)
local function CreateFlatScrollFrame(parent, width, height)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    sf:SetSize(width, height)

    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(width - 12, 100)
    sf:SetScrollChild(content)
    sf.scrollContent = content

    local track = sf:CreateTexture(nil, "BACKGROUND")
    track:SetSize(4, height)
    track:SetPoint("RIGHT", sf, "RIGHT", 0, 0)
    track:SetColorTexture(0.08, 0.14, 0.25, 0.4)
    sf.track = track

    local thumb = sf:CreateTexture(nil, "ARTWORK")
    thumb:SetWidth(4)
    thumb:SetColorTexture(0.18, 0.65, 1.0, 0.85)
    thumb:SetPoint("TOPRIGHT", sf, "TOPRIGHT", 0, 0)
    sf.thumb = thumb

    local function UpdateScrollbar(self)
        local range = self:GetVerticalScrollRange()
        local contentHeight = self.scrollContent:GetHeight()
        local viewHeight = self:GetHeight()

        if range <= 0 or contentHeight <= 0 or viewHeight <= 0 or contentHeight <= viewHeight then
            self.thumb:Hide()
            self.track:Hide()
            return
        end
        self.thumb:Show()
        self.track:Show()

        local scroll = self:GetVerticalScroll()
        local thumbHeight = (viewHeight / contentHeight) * viewHeight
        if thumbHeight < 15 then thumbHeight = 15 end
        if thumbHeight > viewHeight then thumbHeight = viewHeight end
        self.thumb:SetHeight(thumbHeight)

        local percent = scroll / range
        local maxThumbY = viewHeight - thumbHeight
        local thumbY = - (percent * maxThumbY)
        
        if thumbY > 0 then thumbY = 0 end
        if math.abs(thumbY) > maxThumbY then thumbY = -maxThumbY end
        
        self.thumb:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, thumbY)
    end

    sf:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local newScroll = current - delta * 25
        if newScroll < 0 then newScroll = 0 end
        local maxScroll = self:GetVerticalScrollRange()
        if newScroll > maxScroll then newScroll = maxScroll end
        self:SetVerticalScroll(newScroll)
        UpdateScrollbar(self)
    end)

    sf:SetScript("OnVerticalScroll", function(self, offset)
        UpdateScrollbar(self)
    end)

    sf:SetScript("OnShow", function(self)
        C_Timer.After(0.02, function()
            UpdateScrollbar(self)
        end)
    end)

    sf.SetContentHeight = function(self, newHeight)
        self.scrollContent:SetSize(width - 12, newHeight)
        UpdateScrollbar(self)
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
    self.minimapDB = { hide = false, angle = 225 }
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
            if cfg.updateFrequency then
                Bastion:SetUpdateFrequency(cfg.updateFrequency)
            else
                Bastion:SetUpdateFrequency("2Hz")
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
    local ui = self
    if _G["BastionMinimapButton"] then return end

    local btn = CreateFrame("Button", "BastionMinimapButton", Minimap)
    btn:SetSize(31, 31)
    btn:SetFrameStrata("MEDIUM")
    btn:SetFixedFrameStrata(true)
    btn:SetFrameLevel(Minimap:GetFrameLevel() + 5)
    btn:SetFixedFrameLevel(true)
    btn:EnableMouse(true)
    btn:SetMovable(true)
    btn:RegisterForDrag("LeftButton")
    btn:RegisterForClicks("AnyUp")

    local function UpdatePosition(deg)
        local rad = math.rad(deg)
        local w = (Minimap:GetWidth() / 2) + 5
        local h = (Minimap:GetHeight() / 2) + 5
        local x = math.cos(rad) * w
        local y = math.sin(rad) * h
        btn:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    local background = btn:CreateTexture(nil, "BACKGROUND")
    background:SetSize(25, 25)
    background:SetPoint("CENTER", btn, "CENTER", 0, 0)
    background:SetTexture("Interface\\Icons\\UI_Sigil_Kyrian")

    local mask = btn:CreateMaskTexture()
    mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask")
    mask:SetAllPoints(background)
    background:AddMaskTexture(mask)

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", btn, "TOPLEFT", -2, 1)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    btn:SetHighlightTexture("Interface\\Minimap\\RegularMinimap-Highlight")

    btn:SetScript("OnDragStart", function(self)
        self:LockHighlight()
        self:SetScript("OnUpdate", function(self)
            local px, py = GetCursorPosition()
            local mx, my = Minimap:GetCenter()
            local scale = Minimap:GetEffectiveScale()

            local dx = px - (mx * scale)
            local dy = py - (my * scale)
            
            local angle = math.atan2(dy, dx)
            local deg = math.deg(angle) % 360

            ui.minimapDB.angle = deg
            ui:SaveFrameworkConfig()

            UpdatePosition(deg)
        end)
    end)

    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        self:UnlockHighlight()
    end)

    Minimap.BastionUIObj = ui

    btn:SetScript("OnClick", function(_, button)
        if button == "LeftButton" then
            ui:Toggle()
        elseif button == "RightButton" then
            Bastion.Enabled = not Bastion.Enabled
            if not Bastion.Enabled and Bastion.ObjectManager then
                Bastion.ObjectManager:Refresh()
            end
            if Bastion.Enabled then
                Bastion:Print(L["Enabled"] or "开启")
            else
                Bastion:Print(L["Disabled"] or "关闭")
            end
            ui:UpdateStatusBar()
            ui:SaveFrameworkConfig()
        end
    end)

    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cFFDF362DBas|r|cFFFFFFFFtion|r")
        GameTooltip:AddLine(" ")
        GameTooltip:AddDoubleLine(L["Left-Click"] or "左键点击", L["Toggle UI panel"] or "控制面板显示/隐藏", 1,1,1, 0.8,0.8,0.8)
        GameTooltip:AddDoubleLine(L["Right-Click"] or "右键点击", L["Toggle Bastion on/off"] or "开关主框架", 1,1,1, 0.8,0.8,0.8)
        GameTooltip:AddDoubleLine(L["Drag"] or "按住拖拽", L["Adjust minimap button position"] or "调整图标位置", 1,1,1, 0.8,0.8,0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local initialDeg = ui.minimapDB.angle or 225
    if initialDeg ~= 225 and math.abs(initialDeg) <= 2 * math.pi then
        initialDeg = math.deg(initialDeg) % 360
    end
    UpdatePosition(initialDeg)
end

----------------------------------------------------------------------
-- 现代化 Gather-Titan 风格 1024 * 576 主面板 (无重叠修正版)
----------------------------------------------------------------------

function BastionUI:CreateMainFrame()
    -- 主窗口
    local frame = CreateFrame("Frame", "BastionMainFrame", UIParent, "BackdropTemplate")
    frame:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetFrameLevel(100)

    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    frame:SetBackdropColor(0.04, 0.05, 0.08, 0.92)
    frame:SetBackdropBorderColor(0.15, 0.45, 0.85, 0.95)
    self.frame = frame

    -- 顶部 Header 标题
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -14)
    title:SetText("BASTION v1.1.1")
    title:SetTextColor(0.18, 0.65, 1.0)

    -- 顶部 976px 蓝紫发光分隔线
    local topDivider = frame:CreateTexture(nil, "BACKGROUND")
    topDivider:SetColorTexture(0.15, 0.45, 0.85, 0.3)
    topDivider:SetSize(976, 2)
    topDivider:SetPoint("TOPLEFT", 24, -40)

    -- 右上角关闭按钮 (Gather-Titan 专属暗红 × 发光样式)
    local closeBtn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeBtn:SetSize(24, 24)
    closeBtn:SetPoint("TOPRIGHT", -12, -10)
    closeBtn:SetFrameLevel(frame:GetFrameLevel() + 20)
    closeBtn:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    closeBtn:SetBackdropColor(0.12, 0.05, 0.06, 0.85)
    closeBtn:SetBackdropBorderColor(0.55, 0.2, 0.2, 0.7)

    local closeTxt = closeBtn:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    closeTxt:SetSize(24, 24)
    closeTxt:SetPoint("CENTER", -0.5, 0.5)
    closeTxt:SetJustifyH("CENTER")
    closeTxt:SetJustifyV("MIDDLE")
    closeTxt:SetText("×")
    closeTxt:SetTextColor(0.9, 0.35, 0.35, 1.0)

    closeBtn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(0.3, 0.08, 0.09, 0.95)
        self:SetBackdropBorderColor(0.9, 0.25, 0.25, 0.95)
        closeTxt:SetTextColor(1.0, 1.0, 1.0, 1.0)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(0.12, 0.05, 0.06, 0.85)
        self:SetBackdropBorderColor(0.55, 0.2, 0.2, 0.7)
        closeTxt:SetTextColor(0.9, 0.35, 0.35, 1.0)
    end)
    closeBtn:SetScript("OnClick", function()
        PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        self:Toggle()
    end)

    -- ============================================================
    -- 左侧导航侧边栏 (navBg - 180px x 450px) - 为底部状态栏留下空间
    -- ============================================================
    local navBg = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    navBg:SetSize(SIDEBAR_WIDTH, MAIN_CONTENT_HEIGHT)
    navBg:SetPoint("TOPLEFT", 24, -48)
    navBg:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    navBg:SetBackdropColor(0.02, 0.03, 0.05, 0.6)
    navBg:SetBackdropBorderColor(0.1, 0.25, 0.45, 0.4)

    -- Tab 页签按钮 (160x36 Backdrop 动态发光按钮)
    local tabModules = CreateFrame("Button", nil, navBg, "BackdropTemplate")
    tabModules:SetSize(160, 36)
    tabModules:SetPoint("TOP", 0, -16)
    tabModules:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    local t1Text = tabModules:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t1Text:SetPoint("CENTER", 0, 0)
    t1Text:SetText(L["Module Management"] or "模块管理")
    tabModules.tText = t1Text
    self.tabModulesBtn = tabModules

    local tabFramework = CreateFrame("Button", nil, navBg, "BackdropTemplate")
    tabFramework:SetSize(160, 36)
    tabFramework:SetPoint("TOP", 0, -60)
    tabFramework:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    local t2Text = tabFramework:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    t2Text:SetPoint("CENTER", 0, 0)
    t2Text:SetText(L["Framework Settings"] or "设置项")
    tabFramework.tText = t2Text
    self.tabFrameworkBtn = tabFramework

    tabModules:SetScript("OnClick", function() self:SwitchTab("modules") end)
    tabFramework:SetScript("OnClick", function() self:SwitchTab("framework") end)

    -- ============================================================
    -- 右侧主内容展示区 (780px x 450px) - 为底部状态栏留下空间
    -- ============================================================
    local mainArea = CreateFrame("Frame", nil, frame)
    mainArea:SetSize(CONTENT_WIDTH, MAIN_CONTENT_HEIGHT)
    mainArea:SetPoint("TOPLEFT", navBg, "TOPRIGHT", 16, 0)
    self.mainArea = mainArea

    -- 模块选择展示页 (780x450 Backdrop 卡片)
    self.modulesPage = CreateFrame("Frame", nil, mainArea, "BackdropTemplate")
    self.modulesPage:SetAllPoints(mainArea)
    self.modulesPage:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    self.modulesPage:SetBackdropColor(0.02, 0.03, 0.05, 0.4)
    self.modulesPage:SetBackdropBorderColor(0.1, 0.25, 0.45, 0.4)

    -- 全局设置项页 (780x450 Backdrop 卡片)
    self.frameworkPage = CreateFrame("Frame", nil, mainArea, "BackdropTemplate")
    self.frameworkPage:SetAllPoints(mainArea)
    self.frameworkPage:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    self.frameworkPage:SetBackdropColor(0.02, 0.03, 0.05, 0.4)
    self.frameworkPage:SetBackdropBorderColor(0.1, 0.25, 0.45, 0.4)
    self.frameworkPage:Hide()

    -- ============================================================
    -- 页面内容渲染与构建
    -- ============================================================
    self:BuildModulesPage()
    self:BuildFrameworkPage()
    self:BuildStatusBar()

    self:SwitchTab("modules")
    frame:Hide()
end

-- Tab 页面切换 (Gather-Titan 蓝发光选中态转换)
function BastionUI:SwitchTab(tab)
    self.currentTab = tab
    if tab == "modules" then
        self.tabModulesBtn:SetBackdropColor(0.1, 0.3, 0.6, 0.8)
        self.tabModulesBtn:SetBackdropBorderColor(0.2, 0.5, 0.9, 0.9)
        self.tabModulesBtn.tText:SetTextColor(1.0, 1.0, 1.0)

        self.tabFrameworkBtn:SetBackdropColor(0.1, 0.15, 0.28, 0.6)
        self.tabFrameworkBtn:SetBackdropBorderColor(0.25, 0.35, 0.55, 0.7)
        self.tabFrameworkBtn.tText:SetTextColor(0.8, 0.9, 1.0)

        self.modulesPage:Show()
        self.frameworkPage:Hide()
    elseif tab == "framework" then
        self.tabModulesBtn:SetBackdropColor(0.1, 0.15, 0.28, 0.6)
        self.tabModulesBtn:SetBackdropBorderColor(0.25, 0.35, 0.55, 0.7)
        self.tabModulesBtn.tText:SetTextColor(0.8, 0.9, 1.0)

        self.tabFrameworkBtn:SetBackdropColor(0.1, 0.3, 0.6, 0.8)
        self.tabFrameworkBtn:SetBackdropBorderColor(0.2, 0.5, 0.9, 0.9)
        self.tabFrameworkBtn.tText:SetTextColor(1.0, 1.0, 1.0)

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
    local ddWidth = CONTENT_WIDTH - 40
    local moduleDropdown = CreateFlatDropdown(page, L["Select Module"] or "选择战斗模块", ddWidth)
    moduleDropdown:SetPoint("TOPLEFT", page, "TOPLEFT", 20, -15)
    self.moduleDropdown = moduleDropdown

    moduleDropdown:SetOnSelect(function(value)
        self:OnModuleSelected(value)
    end)

    -- 动态配置滚轮展示区
    local scrollFrame = CreateFlatScrollFrame(page, CONTENT_WIDTH - 30, 395)
    scrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -75)
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
        local noSettings = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
        noSettings:SetPoint("TOPLEFT", content, "TOPLEFT", 15, -20)
        noSettings:SetText(L["No settings available"] or "无可用配置项")
        noSettings:SetTextColor(0.5, 0.6, 0.7, 1)
        table.insert(self.settingsWidgets, noSettings)
        scrollFrame:SetContentHeight(60)
        return
    end

    -- 模块名总标题
    local title = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    title:SetText(module:GetDisplayName() .. " " .. (L["Settings"] or "配置项"))
    title:SetTextColor(0.18, 0.65, 1.0)
    table.insert(self.settingsWidgets, title)

    -- 恢复默认值按钮 (Gather-Titan 警告红框按钮)
    local resetBtn = CreateFlatButton(content, L["Reset to Default"] or "恢复默认", 130, 24, false, true)
    resetBtn:SetPoint("TOPRIGHT", content, "TOPRIGHT", -20, -8)
    resetBtn:SetScript("OnClick", function()
        module:ResetSettings()
        self:BuildModuleSettings(module)
        self:SaveConfig()
        Bastion:Print(L["Settings reset to default"] or "配置已重置为默认值")
    end)
    table.insert(self.settingsWidgets, resetBtn)

    local yOffset = 45
    local lastWidget = nil

    for _, def in ipairs(defs) do
        if def.type == "header" then
            -- 分组卡片分割线
            local pane = CreateFrame("Frame", nil, content, "BackdropTemplate")
            pane:SetSize(CONTENT_WIDTH - 50, 24)
            if lastWidget then
                pane:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -15)
            else
                pane:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 5))
            end
            pane:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
                tile = true, tileSize = 12, edgeSize = 12,
                insets = { left = 2, right = 2, top = 2, bottom = 2 }
            })
            pane:SetBackdropColor(0.02, 0.04, 0.08, 0.6)
            pane:SetBackdropBorderColor(0.12, 0.35, 0.7, 0.4)

            local txt = pane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            txt:SetPoint("LEFT", pane, "LEFT", 10, 0)
            txt:SetText(GetSettingLabel(def))
            txt:SetTextColor(0.18, 0.65, 1.0)

            yOffset = yOffset + 34
            lastWidget = pane
            table.insert(self.settingsWidgets, pane)

        elseif def.type == "slider" then
            local slider = CreateFlatSlider(content, GetSettingLabel(def), CONTENT_WIDTH - 55, def.min or 0, def.max or 100, def.step or 1)
            if lastWidget then
                slider:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -12)
            else
                slider:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 5))
            end
            slider:SetValue(module:GetSetting(def.key) or def.default or def.min or 0)
            slider:SetValueCallback(function(value)
                module:SetSetting(def.key, value)
                self:SaveConfig()
            end)
            yOffset = yOffset + 58
            lastWidget = slider
            table.insert(self.settingsWidgets, slider)

        elseif def.type == "toggle" or def.type == "checkbox" then
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
            yOffset = yOffset + 30
            lastWidget = cb
            table.insert(self.settingsWidgets, cb)

        elseif def.type == "dropdown" then
            local dd = CreateFlatDropdown(content, GetSettingLabel(def), CONTENT_WIDTH - 55)
            if lastWidget then
                dd:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -12)
            else
                dd:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 5))
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
            yOffset = yOffset + 60
            lastWidget = dd
            table.insert(self.settingsWidgets, dd)

        elseif def.type == "button" then
            local btn = CreateFlatButton(content, GetSettingLabel(def), CONTENT_WIDTH - 55, 26, true)
            if lastWidget then
                btn:SetPoint("TOPLEFT", lastWidget, "BOTTOMLEFT", 0, -10)
            else
                btn:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -(yOffset + 5))
            end
            btn:SetScript("OnClick", function()
                if def.onClick then def.onClick() end
            end)
            yOffset = yOffset + 36
            lastWidget = btn
            table.insert(self.settingsWidgets, btn)
        end
    end

    scrollFrame:SetContentHeight(yOffset + 30)
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

    local scrollFrame = CreateFlatScrollFrame(page, CONTENT_WIDTH - 30, 455)
    scrollFrame:SetPoint("TOPLEFT", page, "TOPLEFT", 15, -15)
    self.fwScrollFrame = scrollFrame
    local content = scrollFrame.scrollContent

    -- 快捷键分组卡片
    local hkPane = CreateFrame("Frame", nil, content, "BackdropTemplate")
    hkPane:SetSize(CONTENT_WIDTH - 50, 26)
    hkPane:SetPoint("TOPLEFT", content, "TOPLEFT", 10, -10)
    hkPane:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    hkPane:SetBackdropColor(0.02, 0.04, 0.08, 0.6)
    hkPane:SetBackdropBorderColor(0.12, 0.35, 0.7, 0.4)

    local txt1 = hkPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt1:SetPoint("LEFT", hkPane, "LEFT", 10, 0)
    txt1:SetText(L["Hotkey Settings"] or "全局快捷键设置")
    txt1:SetTextColor(0.18, 0.65, 1.0)

    local tipText = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    tipText:SetPoint("TOPLEFT", hkPane, "BOTTOMLEFT", 10, -10)
    tipText:SetText(L["Click button then press key combo"] or "点击按钮后按下组合键进行绑定：")
    tipText:SetTextColor(0.6, 0.7, 0.8, 1)

    local hotkeyEntries = {
        { id = "toggleBastion",  label = L["Toggle on/off"] or "主框架开关" },
        { id = "toggleUI",       label = L["Toggle UI panel"] or "面板显示/隐藏" },
        { id = "toggleModule",   label = L["Toggle current module"] or "当前模块开关" },
    }

    self._hotkeyButtons = {}
    local lastAnchor = tipText

    for _, entry in ipairs(hotkeyEntries) do
        local lbl = content:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
        lbl:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -16)
        lbl:SetWidth(180)
        lbl:SetJustifyH("LEFT")
        lbl:SetText(entry.label)
        lbl:SetTextColor(0.8, 0.9, 1.0)

        local btn = CreateFlatButton(content, HotkeyText(self.hotkeys[entry.id]), 160, 24, true)
        btn:SetPoint("LEFT", lbl, "RIGHT", 15, 0)

        local hotkeyId = entry.id
        btn:SetScript("OnClick", function()
            self:StartRecording(hotkeyId, btn)
        end)

        self._hotkeyButtons[entry.id] = btn
        lastAnchor = lbl
    end

    -- 通用设置分组卡片
    local generalPane = CreateFrame("Frame", nil, content, "BackdropTemplate")
    generalPane:SetSize(CONTENT_WIDTH - 50, 26)
    generalPane:SetPoint("TOPLEFT", lastAnchor, "BOTTOMLEFT", 0, -25)
    generalPane:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    generalPane:SetBackdropColor(0.02, 0.04, 0.08, 0.6)
    generalPane:SetBackdropBorderColor(0.12, 0.35, 0.7, 0.4)

    local txt2 = generalPane:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    txt2:SetPoint("LEFT", generalPane, "LEFT", 10, 0)
    txt2:SetText(L["General Settings"] or "常规调试设置")
    txt2:SetTextColor(0.18, 0.65, 1.0)

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
    debugCB:SetPoint("TOPLEFT", generalPane, "BOTTOMLEFT", 10, -15)
    debugCB:SetChecked(Bastion.DebugMode or false)
    self.debugCB = debugCB

    -- 数据更新频率下拉选择框 (默认 10Hz)
    local freqDD = CreateFlatDropdown(content, L["Update Frequency"] or "数据更新频率", 260)
    freqDD:SetPoint("TOPLEFT", debugCB, "BOTTOMLEFT", 0, -20)
    freqDD:SetItems({
        { text = L["1Hz (Low power - 1000ms)"] or "1Hz (节能 - 1000ms)", value = "1Hz" },
        { text = L["2Hz (Recommended - 500ms)"] or "2Hz (推荐 - 500ms)", value = "2Hz" },
        { text = L["5Hz (Standard - 200ms)"] or "5Hz (标准 - 200ms)", value = "5Hz" },
        { text = L["10Hz (Responsive - 100ms)"] or "10Hz (流畅 - 100ms)", value = "10Hz" },
        { text = L["20Hz (High speed - 50ms)"] or "20Hz (高频 - 50ms)", value = "20Hz" },
        { text = L["60Hz (Extreme - 16.6ms)"] or "60Hz (极速 - 16.6ms)", value = "60Hz" }
    })
    freqDD:SetSelectedValue(Bastion.UpdateFrequency or "2Hz")
    freqDD:SetOnSelect(function(val)
        Bastion:SetUpdateFrequency(val)
        self:SaveFrameworkConfig()
        Bastion:Print((L["Update frequency set to "] or "数据更新频率已设置为 ") .. val)
    end)
    self.freqDD = freqDD

    -- 语言设置下拉选择框
    local langDD = CreateFlatDropdown(content, L["Language"] or "界面语言", 260)
    langDD:SetPoint("TOPLEFT", freqDD, "BOTTOMLEFT", 0, -20)
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

    scrollFrame:SetContentHeight(450)
end

----------------------------------------------------------------------
-- 快捷键录制状态机
----------------------------------------------------------------------

function BastionUI:StartRecording(hotkeyId, btn)
    if self._recording then
        local oldBtn = self._hotkeyButtons[self._recording]
        if oldBtn then
            oldBtn.fontString:SetText(HotkeyText(self.hotkeys[self._recording]))
            oldBtn:SetBackdropColor(0.1, 0.3, 0.6, 0.8)
            oldBtn:SetBackdropBorderColor(0.2, 0.5, 0.9, 0.9)
        end
    end

    self._recording = hotkeyId
    btn.fontString:SetText("|cFFFFFF00" .. (L["Press key combo..."] or "按下按键...") .. "|r")
    btn:SetBackdropColor(0.35, 0.08, 0.08, 0.85)
    btn:SetBackdropBorderColor(0.95, 0.25, 0.25, 0.95)
end

function BastionUI:StopRecording(mod, key)
    if not self._recording then return end

    local id = self._recording
    self.hotkeys[id].mod = mod
    self.hotkeys[id].key = key

    local btn = self._hotkeyButtons[id]
    if btn then
        btn.fontString:SetText(HotkeyText(self.hotkeys[id]))
        btn:SetBackdropColor(0.1, 0.3, 0.6, 0.8)
        btn:SetBackdropBorderColor(0.2, 0.5, 0.9, 0.9)
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
            if keyVK == 0x1B then
                self:StopRecording(0, 0)
            else
                self:StopRecording(activeMod, keyVK)
            end
            return
        end
    end
end

----------------------------------------------------------------------
-- 现代化底部状态监察面板 (Gather-Titan Backdrop 风格，底边精确对齐)
----------------------------------------------------------------------

function BastionUI:BuildStatusBar()
    local bar = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
    bar:SetSize(976, 26)
    bar:SetPoint("BOTTOMLEFT", self.frame, "BOTTOMLEFT", 24, 12)
    bar:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 12, edgeSize = 12,
        insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    bar:SetBackdropColor(0.02, 0.03, 0.05, 0.6)
    bar:SetBackdropBorderColor(0.12, 0.35, 0.7, 0.5)
    self.statusBar = bar

    self.statusText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    self.statusText:SetPoint("LEFT", bar, "LEFT", 12, 0)

    self.hotkeyHint = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightMed2")
    self.hotkeyHint:SetPoint("RIGHT", bar, "RIGHT", -12, 0)
    self.hotkeyHint:SetTextColor(0.6, 0.7, 0.8, 1)

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
        status = status .. "  |cFF555555|||r  |cFF00E5FF" .. self.selectedModule:GetDisplayName() .. "|r"
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
        Bastion.ConfigManager:SaveAll(Bastion._MODULES)
    end
end

function BastionUI:SaveFrameworkConfig()
    if Bastion.ConfigManager then
        Bastion.ConfigManager:SaveFrameworkSettings({
            hotkeys = self.hotkeys,
            debugMode = Bastion.DebugMode or false,
            bastionEnabled = Bastion.Enabled or false,
            minimapAngle = self.minimapDB.angle or 0,
            language = self.language or (GetLocale and GetLocale()) or "enUS",
            updateFrequency = Bastion.UpdateFrequency or "2Hz"
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
        if not Bastion.Enabled and Bastion.ObjectManager then
            Bastion.ObjectManager:Refresh()
        end
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

Bastion.BastionUI = BastionUI
return BastionUI
