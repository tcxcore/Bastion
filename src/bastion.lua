local tcx, Bastion = ...
local TCX = (type(Bastion) == 'table' and Bastion.TCX) or tcx

-- 检测本地物理磁盘是否存在 Bastion.toc，以判定当前是本地加载还是云端内存加载
local isLocal = TCX.FileExists("scripts/Bastion/Bastion.toc")

if not Bastion then
    Bastion = { DebugMode = false }
end

Bastion.Globals = Bastion.Globals or {}
Bastion.DebugMode = false

-- 2. 挂载基础调试与打印辅助函数
function Bastion:Print(...)
    local args = {...}
    local str = "|cFFDF362D[Bastion]|r |cFFFFFFFF"
    for i = 1, #args do str = str .. tostring(args[i]) .. " " end
    print(str)
end

function Bastion:Debug(...)
    if not Bastion.DebugMode then return end
    local args = {...}
    local str = "|cFFDF6520[Bastion]|r |cFFFFFFFF"
    for i = 1, #args do str = str .. tostring(args[i]) .. " " end
    print(str)
end

-- 模块列表与注册
local MODULES = {}
Bastion._MODULES = MODULES

function Bastion:Register(module)
    table.insert(MODULES, module)
    local L = Bastion.Locale or {}
    Bastion:Print(L["Registered"] or "Registered", module.name)
end

function Bastion:FindModule(name)
    for i = 1, #MODULES do
        if MODULES[i].name == name then return MODULES[i] end
    end
    return nil
end

-- 库管理与依赖检查
local LIBRARIES = {}
function Bastion:RegisterLibrary(library)
    LIBRARIES[library.name] = library
end

function Bastion:CheckLibraryDependencies()
    for k, v in pairs(LIBRARIES) do
        if v.dependencies then
            for i = 1, #v.dependencies do
                local dep = v.dependencies[i]
                if LIBRARIES[dep] then
                    if LIBRARIES[dep].dependencies then
                        for j = 1, #LIBRARIES[dep].dependencies do
                            if LIBRARIES[dep].dependencies[j] == v.name then
                                Bastion:Print("Circular dependency detected between " .. v.name .. " and " .. dep)
                                return false
                            end
                        end
                    end
                end
            end
        end
    end
    return true
end

-- 异步加载的通用逻辑
local loaded_modules = {}
local function custom_require_async(file, env_arg, callback)
    if not file:match("%.lua$") then
        file = file .. ".lua"
    end
    
    if loaded_modules[file] then
        callback(true, unpack(loaded_modules[file]))
        return
    end
    
    TCX.LoadProtectedFile(file, function(success, ...)
        if not success then
            local err = ...
            error("custom_require_async: Error loading " .. file .. ": " .. tostring(err))
            callback(false, err)
            return
        end
        
        local results = {...}
        if #results == 0 then
            results = { true }
        end
        loaded_modules[file] = results
        callback(true, unpack(results))
    end, env_arg)
end

function Bastion:RequireAsync(file, callback)
    local actual_path
    if file:sub(1, 1) == '@' then
        actual_path = file:sub(2)
        if actual_path:sub(1, 1) == "/" then actual_path = actual_path:sub(2) end
        if isLocal then
            actual_path = 'scripts/Bastion/scripts/' .. actual_path
        else
            actual_path = 'scripts/' .. actual_path
        end
    elseif file:sub(1, 1) == "~" then
        actual_path = file:sub(2)
        if actual_path:sub(1, 1) == "/" then actual_path = actual_path:sub(2) end
        if isLocal then
            actual_path = 'scripts/Bastion/' .. actual_path
        end
        -- 在云端无盘模式下，actual_path 直接就是相对项目的相对路径，无需拼前缀
    else
        actual_path = file
    end
    custom_require_async(actual_path, Bastion, callback)
end

-- ==================== 最终的游戏内初始化 ====================
local function InitializeInGame()
    Bastion:Print("InitializeInGame called!")

    -- 1. 此时玩家已完全进入游戏世界，所有 API 就绪，进行核心类库实例化
    Bastion.UnitManager = Bastion.UnitManager:New()
    Bastion.ObjectManager = Bastion.ObjectManager:New()
    
    Bastion.Globals.EventManager = Bastion.EventManager:New()
    Bastion.Globals.SpellBook = Bastion.SpellBook:New()
    Bastion.Globals.ItemBook = Bastion.ItemBook:New()
    Bastion.CombatTimer = Bastion.Timer:New('combat')
    Bastion.MythicPlusUtils = Bastion.MythicPlusUtils:New()
    Bastion.Notifications = Bastion.NotificationsList:New()
    
    local L = Bastion.Locale

    -- 2. 职业脚本已被解耦为独立脚本自我注册，框架不再需要动态扫描及加载 class 脚本
    -- 直接执行后续的 Ticker 启动、命令注册及 UI 展示

    -- 启动 Ticker 监控
    local pguid = UnitGUID("player")
    local missed = {}

    Bastion.Ticker = C_Timer.NewTicker(0.1, function()
        -- 轮询周围单位的 UnitAffectingCombat 状态来更新战斗时间
        local t = GetTime()
        Bastion.UnitManager:EnumUnits(function(unit)
            if unit and unit:IsAffectingCombat() then
                unit:SetLastCombatTime(t)
            end
        end)

        if not Bastion.CombatTimer:IsRunning() and TCX.ObjectIsInCombat("player") then
            Bastion.CombatTimer:Start()
        elseif Bastion.CombatTimer:IsRunning() and not TCX.ObjectIsInCombat("player") then
            Bastion.CombatTimer:Reset()
        end

        if Bastion.Enabled then
            Bastion.ObjectManager:Refresh()
            for i = 1, #MODULES do MODULES[i]:Tick() end
        end

        -- 快捷键轮询
        if Bastion.UI then
            Bastion.UI:ProcessHotkeys()
        end
    end)

    -- 初始化并注册 Slash 命令
    local Command = Bastion.Command:New('bastion')

    Command:Register('toggle', L['Toggle bastion on/off'], function()
        Bastion.Enabled = not Bastion.Enabled
        if Bastion.Enabled then
            Bastion:Print(L["Enabled"])
        else
            Bastion:Print(L["Disabled"])
        end
        if Bastion.UI then
            Bastion.UI:UpdateStatusBar()
            Bastion.UI:SaveFrameworkConfig()
        end
    end)

    Command:Register('debug', L['Toggle debug mode on/off'], function()
        Bastion.DebugMode = not Bastion.DebugMode
        if Bastion.DebugMode then
            Bastion:Print(L["Debug mode enabled"])
        else
            Bastion:Print(L["Debug mode disabled"])
        end
        if Bastion.UI then
            Bastion.UI:SaveFrameworkConfig()
        end
    end)

    Command:Register('dumpspells', L['Dump spells to a file'], function()
        local i = 1
        local rand = math.random(100000, 999999)
        local BOOKTYPE_SPELL = BOOKTYPE_SPELL or (Enum.SpellBookSpellBank.Player and Enum.SpellBookSpellBank.Player or 'spell')
        while true do
            local spellName, spellSubName

            if C_SpellBook.GetSpellBookItemName then
                spellName, spellSubName = C_SpellBook.GetSpellBookItemName(i, BOOKTYPE_SPELL)
            else
                spellName, spellSubName = GetSpellBookItemName(i, BOOKTYPE_SPELL)
            end

            if not spellName then break end

            local spellID

            if C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellName)
                spellID = info.spellID
            else
                spellID = select(7, GetSpellInfo(spellName))
            end

            if spellID then
                spellName = spellName:gsub("[%W%s]", "")
                TCX.WriteFile('bastion-' .. UnitClass('player') .. '-' .. rand .. '.lua',
                          "local " .. spellName .. " = Bastion.Globals.SpellBook:GetSpell(" .. spellID .. ")\n", true)
            end
            i = i + 1
        end
    end)

    Command:Register('module', L['Toggle a module on/off'], function(args)
        local module = Bastion:FindModule(args[2])
        if module then
            module:Toggle()
            if module.enabled then
                Bastion:Print(L["Enabled"], module.name)
            else
                Bastion:Print(L["Disabled"], module.name)
            end
        else
            Bastion:Print(L["Module not found"])
        end
    end)

    Command:Register('mplus', L['Toggle m+ module on/off'], function(args)
        local cmd = args[2]
        if cmd == 'debuffs' then
            Bastion.MythicPlusUtils:ToggleDebuffLogging()
            Bastion:Print(L["Debuff logging"], Bastion.MythicPlusUtils.debuffLogging and L["enabled"] or L["disabled"])
            return
        end

        if cmd == 'casts' then
            Bastion.MythicPlusUtils:ToggleCastLogging()
            Bastion:Print(L["Cast logging"], Bastion.MythicPlusUtils.castLogging and L["enabled"] or L["disabled"])
            return
        end

        Bastion:Print(L["[MythicPlusUtils] Unknown command"])
        Bastion:Print(L["Available commands:"])
        Bastion:Print(L["debuffs"])
        Bastion:Print(L["casts"])
    end)

    Command:Register('missed', L['Dump the list of immune kidney shot spells'], function()
        for k, v in pairs(missed) do Bastion:Print(k) end
    end)

    Command:Register('ui', L['Toggle UI panel'], function()
        if Bastion.UI then Bastion.UI:Toggle() end
    end)

    -- 实例化配置与加载设置
    Bastion.Config = Bastion.ConfigManager:New()
    Bastion.Config:LoadAll(MODULES)

    -- 消费可能在 Bastion 完全初始化前就已经加载的外部模块挂起队列
    local hostFrame = GetClickFrame("BastionHostFrame")
    if hostFrame then
        hostFrame.RegisterModule = function(self, createFunc)
            local module = createFunc(Bastion)
            if module then
                Bastion:Register(module)
            end
        end

        if hostFrame.pendingModules then
            for _, createFunc in ipairs(hostFrame.pendingModules) do
                hostFrame:RegisterModule(createFunc)
            end
            hostFrame.pendingModules = nil
        end
    end

    -- 初始化 UI 展现
    Bastion.UI = Bastion.BastionUI:New()
    Bastion.UI:Init()
end

-- 启动初始化链
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:SetScript("OnEvent", function(self, event, ...)
    Bastion:Print("PLAYER_ENTERING_WORLD event fired!")
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:SetScript("OnEvent", nil)
    InitializeInGame()
end)

if TCX.IsInGame() then
    Bastion:Print("Already in game (TCX.IsInGame), forcing direct initialization...")
    f:UnregisterEvent("PLAYER_ENTERING_WORLD")
    f:SetScript("OnEvent", nil)
    InitializeInGame()
else
    Bastion:Print("Not in game yet, waiting for PLAYER_ENTERING_WORLD event...")
end
