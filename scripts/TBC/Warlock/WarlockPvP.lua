local _, Bastion = ...
local L = Bastion.Locale

local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')

---@class TBCWarlockPvP : Module
local M = Bastion.Module:New("TBCWarlockPvP")
M:SetDisplayName("Warlock PvP Pet Logic", "术士PVP宠物逻辑(TBC)")

M:DefineSettings({
    {
        type = "toggle",
        key = "autoPetTotem",
        label = "Auto Pet Attack Totems",
        labelZh = "自动控制宠物打图腾",
        default = true
    }
})

-- 封装宠物攻击目标的通用方法
local function OrderPetAttack(unit)
    if not unit or not unit:IsValid() then return end
    
    -- 如果目标已经是正确的，并且宠物攻击状态已经是开启的，则跳过
    if IsPetAttackActive() then
        return
    end

    -- 直接使用框架封装好的获取原生字符串 Token（"target", "mouseover" 等）方法
    local token = type(unit.GetOMToken) == "function" and unit:GetOMToken() or nil

    -- 严格检查类型：防止底层返回了空值(nil)或未经翻译的指针，直接塞给 PetAttack 导致 C++ 崩溃
    if type(token) == "string" then
        print(">> 发送命令：宠物攻击 -> " .. (unit:GetName() or "未知目标") .. " [Token: " .. token .. "]")
        Unlock("PetAttack", token)
    end
end

M:Sync(function()
    if Player:IsDead() then return end

    local Pet = Bastion.UnitManager:Get('pet')
    if not Pet or not Pet:IsValid() or Pet:IsDead() then return end

    -- ==================================================================
    -- 宠物攻击逻辑：优先打图腾，否则打焦点/当前目标
    -- ==================================================================
    local targetToAttack = Target
    
    -- 检查并使用焦点作为主要攻击目标（如果存在有效焦点）
    local focus = Bastion.UnitManager:Get("focus")
    if focus and focus:IsValid() and focus:IsAlive() and focus:IsEnemy() then
        targetToAttack = focus
    end

    if M:GetSetting("autoPetTotem") then
        local totemUnit = nil
        -- 查找周围的敌对单位（使用 EnumUnits 代替 EnumEnemies，因为中立怪物或未进战的图腾不在 Active 列表里）
        Bastion.UnitManager:EnumUnits(function(unit)
            if unit:IsAlive() and unit:IsEnemy() and Player:GetDistance(unit) <= 40 then
                local name = unit:GetName()
                if name and (name:find("Totem") or name:find("图腾")) then
                    totemUnit = unit
                end
            end
            return false
        end)

        if totemUnit then
            OrderPetAttack(totemUnit)
            return
        end
    end

    -- 未开启打图腾功能，或者没找到图腾，只打焦点或当前目标
    if targetToAttack and targetToAttack:IsValid() and targetToAttack:IsEnemy() and targetToAttack:IsAlive() then
        OrderPetAttack(targetToAttack)
    end
end)

Bastion:Register(M)
return M
