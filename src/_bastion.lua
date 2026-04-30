local addonName = ...

local TCX = C_Timer.TCX or {}

---@class Bastion
local Bastion = { DebugMode = false }
Bastion.TCX = TCX
Bastion.__index = Bastion

local loaded_modules = {}
local function custom_require(file, env_arg)
    if not file:match("%.lua$") then
        file = file .. ".lua"
    end
    
    if loaded_modules[file] then return loaded_modules[file] end
    
    local content = TCX.ReadFile(file)
    if not content then error("custom_require: Cannot find file " .. file) end
    
    local func, err = loadstring(content, file)
    if not func then error("custom_require: Error compiling " .. file .. ": " .. err) end
    
    local result = func(file, env_arg)
    loaded_modules[file] = result or true
    return result
end

function Bastion:Require(file)
    if file:sub(1, 1) == '@' then
        file = file:sub(2)
        if file:sub(1, 1) == "/" then file = file:sub(2) end
        return custom_require('scripts/Bastion/scripts/' .. file, Bastion)
    elseif file:sub(1, 1) == "~" then
        file = file:sub(2)
        if file:sub(1, 1) == "/" then file = file:sub(2) end
        return custom_require('scripts/Bastion/' .. file, Bastion)
    else
        return custom_require(file, Bastion)
    end
end

local function Load(dir)
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

    local files = TCX.ListFiles(dir)

    for i = 1, #files do
        local file = files[i]
        if file:sub(-4) == ".lua" or file:sub(-5) == '.luac' then
            Bastion:Require(dir .. file:sub(1, -5))
        end
    end
end

function Bastion.require(class)
    -- return require("scripts/bastion/src/" .. class .. "/" .. class, Bastion)
    return Bastion:Require("~/src/" .. class .. "/" .. class)
end

-- fenv for all required files
function Bastion.Bootstrap()

    Bastion.Globals = {}
    
    -- 首先加载底层适配层，注入诸如 ObjectGUID, Unwrap, Objects 等全局兼容性依赖
    Bastion.require("TCXAdapter")

    ---@type ClassMagic
    Bastion.ClassMagic = Bastion.require("ClassMagic")
    ---@type List
    Bastion.List = Bastion.require("List")
    ---@type Library
    Bastion.Library = Bastion.require("Library")
    ---@type NotificationsList, Notification
    Bastion.NotificationsList, Bastion.Notification = Bastion.require(
                                                          "NotificationsList")
    ---@type Vector3
    Bastion.Vector3 = Bastion.require("Vector3")
    ---@type Sequencer
    Bastion.Sequencer = Bastion.require("Sequencer")
    ---@type Command
    Bastion.Command = Bastion.require("Command")
    
    -- 初始化本地化支持
    Bastion.Locale = Bastion.require("Locale"):GetLocale()
    local L = Bastion.Locale
    ---@type Cache
    Bastion.Cache = Bastion.require("Cache")
    ---@type Cacheable
    Bastion.Cacheable = Bastion.require("Cacheable")
    ---@type Refreshable
    Bastion.Refreshable = Bastion.require("Refreshable")
    ---@type Unit
    Bastion.Unit = Bastion.require("Unit")
    ---@type Aura
    Bastion.Aura = Bastion.require("Aura")
    ---@type APL, APLActor, APLTrait
    Bastion.APL, Bastion.APLActor, Bastion.APLTrait = Bastion.require("APL")
    ---@type Module
    Bastion.Module = Bastion.require("Module")
    ---@type UnitManager
    Bastion.UnitManager = Bastion.require("UnitManager"):New()
    ---@type ObjectManager
    Bastion.ObjectManager = Bastion.require("ObjectManager"):New()
    ---@type EventManager
    Bastion.EventManager = Bastion.require("EventManager")
    Bastion.Globals.EventManager = Bastion.EventManager:New()
    ---@type Spell
    Bastion.Spell = Bastion.require("Spell")
    ---@type SpellBook
    Bastion.SpellBook = Bastion.require("SpellBook")
    Bastion.Globals.SpellBook = Bastion.SpellBook:New()
    ---@type Item
    Bastion.Item = Bastion.require("Item")
    ---@type ItemBook
    Bastion.ItemBook = Bastion.require("ItemBook")
    Bastion.Globals.ItemBook = Bastion.ItemBook:New()
    ---@type AuraTable
    Bastion.AuraTable = Bastion.require("AuraTable")
    ---@type Class
    Bastion.Class = Bastion.require("Class")
    ---@type Timer
    Bastion.Timer = Bastion.require("Timer")
    ---@type Timer
    Bastion.CombatTimer = Bastion.Timer:New('combat')
    ---@type MythicPlusUtils
    Bastion.MythicPlusUtils = Bastion.require("MythicPlusUtils"):New()
    ---@type NotificationsList
    Bastion.Notifications = Bastion.NotificationsList:New()

    local LIBRARIES = {}
    local MODULES = {}

    Bastion.Enabled = false

    Bastion.Globals.EventManager:RegisterWoWEvent('UNIT_AURA',
                                                  function(unit, auras)
        local u = Bastion.UnitManager[unit]

        if u then u:GetAuras():OnUpdate(auras) end
    end)

    Bastion.Globals.EventManager:RegisterWoWEvent("UNIT_SPELLCAST_SUCCEEDED",
                                                  function(...)
        local unit, castGUID, spellID = ...

        local spell = Bastion.Globals.SpellBook:GetIfRegistered(spellID)

        if unit == "player" and spell then
            spell.lastCastAt = GetTime()

            if spell:GetPostCastFunction() then
                spell:GetPostCastFunction()(spell)
            end
        end
    end)

    local pguid = UnitGUID("player")
    local missed = {}

    Bastion.Ticker = C_Timer.NewTicker(0.1, function()
        -- 12.0 替代机制：通过轮询周围单位的 UnitAffectingCombat 状态来粗略更新战斗时间
        local t = GetTime()
        Bastion.UnitManager:EnumUnits(function(unit)
            if unit and unit:IsAffectingCombat() then
                unit:SetLastCombatTime(t)
            end
        end)

        if not Bastion.CombatTimer:IsRunning() and UnitAffectingCombat("player") then
            Bastion.CombatTimer:Start()
        elseif Bastion.CombatTimer:IsRunning() and
            not UnitAffectingCombat("player") then
            Bastion.CombatTimer:Reset()
        end

        if Bastion.Enabled then
            Bastion.ObjectManager:Refresh()
            for i = 1, #MODULES do MODULES[i]:Tick() end
        end
    end)

    function Bastion:Register(module)
        table.insert(MODULES, module)
        Bastion:Print("Registered", module)
    end

    -- Find a module by name
    function Bastion:FindModule(name)
        for i = 1, #MODULES do
            if MODULES[i].name == name then return MODULES[i] end
        end

        return nil
    end

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

    local Command = Bastion.Command:New('bastion')

    Command:Register('toggle', L['Toggle bastion on/off'], function()
        Bastion.Enabled = not Bastion.Enabled
        if Bastion.Enabled then
            Bastion:Print(L["Enabled"])
        else
            Bastion:Print(L["Disabled"])
        end
    end)

    Command:Register('debug', L['Toggle debug mode on/off'], function()
        Bastion.DebugMode = not Bastion.DebugMode
        if Bastion.DebugMode then
            Bastion:Print(L["Debug mode enabled"])
        else
            Bastion:Print(L["Debug mode disabled"])
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

            if not spellName then do break end end

            -- use spellName and spellSubName here
            local spellID

            if C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellName)
                spellID = info.spellID
            else
                spellID = select(7, GetSpellInfo(spellName))
            end

            if spellID then
                spellName = spellName:gsub("[%W%s]", "")
                TCX.WriteFile('bastion-' .. UnitClass('player') .. '-' .. rand ..
                              '.lua',
                          "local " .. spellName ..
                              " = Bastion.Globals.SpellBook:GetSpell(" ..
                              spellID .. ")\n", true)
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
            Bastion:Print(L["Debuff logging"], Bastion.MythicPlusUtils
                              .debuffLogging and L["enabled"] or L["disabled"])
            return
        end

        if cmd == 'casts' then
            Bastion.MythicPlusUtils:ToggleCastLogging()
            Bastion:Print(L["Cast logging"],
                          Bastion.MythicPlusUtils.castLogging and L["enabled"] or
                              L["disabled"])
            return
        end

        Bastion:Print(L["[MythicPlusUtils] Unknown command"])
        Bastion:Print(L["Available commands:"])
        Bastion:Print(L["debuffs"])
        Bastion:Print(L["casts"])
    end)

    Command:Register('missed', L['Dump the list of immune kidney shot spells'],
                     function()
        for k, v in pairs(missed) do Bastion:Print(k) end
    end)

    ---@param library Library
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
                                    Bastion:Print(
                                        "Circular dependency detected between " ..
                                            v.name .. " and " .. dep)
                                    return false
                                end
                            end
                        end
                    else
                        Bastion:Print("Library " .. v.name .. " depends on " ..
                                          dep .. " but it's not registered")
                        return false
                    end
                end
            end
        end

        return true
    end

    function Bastion:Import(library)
        local lib = self:GetLibrary(library)

        if not lib then error("Library " .. library .. " not found") end

        return lib:Resolve()
    end

    function Bastion:GetLibrary(name)
        if not LIBRARIES[name] then
            error("Library " .. name .. " not found")
        end

        local library = LIBRARIES[name]

        -- if library.dependencies then
        --     for i = 1, #library.dependencies do
        --         local dep = library.dependencies[i]
        --         if LIBRARIES[dep] then
        --             if LIBRARIES[dep].dependencies then
        --                 for j = 1, #LIBRARIES[dep].dependencies do
        --                     if LIBRARIES[dep].dependencies[j] == library.name then
        --                         Bastion:Print("Circular dependency detected between " .. library.name .. " and " .. dep)
        --                         return false
        --                     end
        --                 end
        --             end
        --         else
        --             Bastion:Print("Library " .. v.name .. " depends on " .. dep .. " but it's not registered")
        --             return false
        --         end
        --     end
        -- end

        return library
    end

    -- if not Bastion:CheckLibraryDependencies() then
    --     return
    -- end

    Load("@Libraries/")
    Load("@Modules/")
    Load("@")
end

Bastion.Bootstrap()
