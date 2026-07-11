local tcx = ...

local TCX = tcx

---@class Bastion
local Bastion = { DebugMode = false }
Bastion.TCX = TCX
Bastion.__index = Bastion

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
        actual_path = 'scripts/Bastion/scripts/' .. actual_path
    elseif file:sub(1, 1) == "~" then
        actual_path = file:sub(2)
        if actual_path:sub(1, 1) == "/" then actual_path = actual_path:sub(2) end
        actual_path = 'scripts/Bastion/' .. actual_path
    else
        actual_path = file
    end
    custom_require_async(actual_path, Bastion, callback)
end

local function LoadAsync(dir, callback)
    local dir = dir

    if dir:sub(1, 1) == '@' then
        dir = dir:sub(2)
        if dir:sub(1, 1) == "/" then dir = dir:sub(2) end
        dir = 'scripts/Bastion/scripts/' .. dir
    end

    if dir:sub(1, 1) == '~' then
        dir = dir:sub(2)
        if dir:sub(1, 1) == "/" then dir = dir:sub(2) end
        dir = 'scripts/Bastion/' .. dir
    end

    -- 确保目录以斜杠结尾
    if dir:sub(-1) ~= "/" then
        dir = dir .. "/"
    end

    -- 收集所有的 .lua 文件（包含子目录）
    local lua_files = {}

    -- 首先，列出当前目录下的所有 .lua 文件
    local files = TCX.ListFiles(dir)
    for i = 1, #files do
        local file = files[i]
        if file:sub(-4) == ".lua" or file:sub(-5) == '.luac' then
            table.insert(lua_files, dir .. file:sub(1, -5))
        end
    end

    -- 然后，列出当前目录下的所有子目录，并列出它们下面的所有 .lua 文件
    local subdirs = TCX.ListFolders(dir)
    for s = 1, #subdirs do
        local subdir = subdirs[s]
        local subdir_path = dir .. subdir .. "/"
        local subfiles = TCX.ListFiles(subdir_path)
        for i = 1, #subfiles do
            local file = subfiles[i]
            if file:sub(-4) == ".lua" or file:sub(-5) == '.luac' then
                table.insert(lua_files, subdir_path .. file:sub(1, -5))
            end
        end
    end

    -- 递归异步加载收集到的所有 Lua 文件
    local function load_next(index)
        if index > #lua_files then
            if callback then callback() end
            return
        end
        Bastion:RequireAsync(lua_files[index], function(success)
            load_next(index + 1)
        end)
    end

    load_next(1)
end

function Bastion.requireAsync(class, callback)
    return Bastion:RequireAsync("~/src/" .. class .. "/" .. class, callback)
end

-- fenv for all required files
function Bastion.Bootstrap()

    Bastion.Globals = {}
    
    local core_libs = {
        "TCXAdapter", "ClassMagic", "List", "Library", "NotificationsList",
        "Vector3", "Sequencer", "Command", "Locale", "Cache", "Cacheable",
        "Refreshable", "Unit", "Aura", "APL", "Module", "UnitManager",
        "ObjectManager", "EventManager", "Spell", "SpellBook", "Item",
        "ItemBook", "AuraTable", "Class", "Timer", "MythicPlusUtils"
    }

    local LIBRARIES = {}
    local MODULES = {}

    Bastion.Enabled = false
    Bastion._MODULES = MODULES  -- UI 需要访问模块列表

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

    function Bastion:Register(module)
        table.insert(MODULES, module)
        local L = Bastion.Locale or {}
        Bastion:Print(L["Registered"] or "Registered", module.name)
    end

    -- Find a module by name
    function Bastion:FindModule(name)
        for i = 1, #MODULES do
            if MODULES[i].name == name then return MODULES[i] end
        end
        return nil
    end

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

    local function load_core_libs(index, on_complete)
        if index > #core_libs then
            on_complete()
            return
        end
        local lib_name = core_libs[index]
        Bastion.requireAsync(lib_name, function(success, ...)
            if success then
                local results = {...}

                if lib_name == "NotificationsList" then
                    Bastion.NotificationsList = results[1]
                    Bastion.Notification = results[2]
                elseif lib_name == "APL" then
                    Bastion.APL = results[1]
                    Bastion.APLActor = results[2]
                    Bastion.APLTrait = results[3]
                else
                    Bastion[lib_name] = results[1]
                end
                load_core_libs(index + 1, on_complete)
            else
                error("Failed to load core library: " .. lib_name)
            end
        end)
    end

    load_core_libs(1, function()
        -- 核心库全部加载完成，下面接着加载 BastionUI 组件
        Bastion:RequireAsync("~/src/BastionUI/ConfigManager", function(success, config_cls)
            if not success then error("Failed to load ConfigManager") end
            Bastion.ConfigManager = config_cls

            Bastion:RequireAsync("~/src/BastionUI/BastionUI", function(success, ui_cls)
                if not success then error("Failed to load BastionUI") end
                Bastion.BastionUI = ui_cls

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

                    -- 2. 判定并异步加载当前职业脚本
                    local classMap = {
                        ["DEATHKNIGHT"] = "DeathKnight",
                        ["DEMONHUNTER"] = "DemonHunter",
                        ["DRUID"]       = "Druid",
                        ["EVOKER"]      = "Evoker",
                        ["HUNTER"]      = "Hunter",
                        ["MAGE"]        = "Mage",
                        ["MONK"]        = "Monk",
                        ["PALADIN"]     = "Paladin",
                        ["PRIEST"]      = "Priest",
                        ["ROGUE"]       = "Rogue",
                        ["SHAMAN"]      = "Shaman",
                        ["WARLOCK"]     = "Warlock",
                        ["WARRIOR"]     = "Warrior"
                    }
                    local _, classFilename = UnitClass("player")
                    local classFolder = classMap[classFilename]
                    local loadPath = "@/" .. Bastion.Build
                    if classFolder then
                        loadPath = loadPath .. "/" .. classFolder
                    end

                    LoadAsync(loadPath, function()
                        Bastion:Print("LoadAsync complete! Path: " .. tostring(loadPath))

                        -- 3. 职业脚本加载完成，启动 Ticker，初始化命令，启动 UI
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

                            if not Bastion.CombatTimer:IsRunning() and UnitAffectingCombat("player") then
                                Bastion.CombatTimer:Start()
                            elseif Bastion.CombatTimer:IsRunning() and not UnitAffectingCombat("player") then
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

                        -- 实例化配置与 UI
                        Bastion.Config = Bastion.ConfigManager:New()
                        Bastion.Config:LoadAll(MODULES)
                        Bastion.UI = Bastion.BastionUI:New()
                        Bastion.UI:Init()
                    end)
                end

                -- 监听或判定直接进入
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
                end
            end)
        end)
    end)
end

Bastion.Bootstrap()
