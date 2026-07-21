local tcx, Bastion = ...
-- EmmyLua 格式化定义: https://emmylua.github.io/

----------------------------------------------------------------------
-- APLTrait: 特征/条件评估函数 (包含 TTL 缓存节流与手动失效/重置)
----------------------------------------------------------------------
---@class APLTrait
local APLTrait = {}
APLTrait.__index = APLTrait

-- Constructor
---@param cb fun():boolean
---@param ttl? number 缓存生命周期 (单位: 秒, 默认 0.05s)
---@return APLTrait
function APLTrait:New(cb, ttl)
    local self = setmetatable({}, APLTrait)

    self.cb = cb
    self.ttl = ttl or 0.05
    self.lastcall = 0
    self.lastresult = nil

    return self
end

-- 评估 APL 特征条件 (带有 TTL 缓存保护，防止极高频率下的重复计算)
---@return boolean
function APLTrait:Evaluate()
    local now = GetTime()
    if self.lastresult == nil or (now - self.lastcall) > self.ttl then
        self.lastresult = (self.cb() == true)
        self.lastcall = now
    end

    return self.lastresult
end

-- 手动失效当前缓存，强制下一次 Evaluate() 重新计算
function APLTrait:Invalidate()
    self.lastresult = nil
    self.lastcall = 0
end

-- 重置 Trait 状态
function APLTrait:Reset()
    self:Invalidate()
end

---@return string
function APLTrait:__tostring()
    return "Bastion.__APLTrait"
end

----------------------------------------------------------------------
-- APLActor: 动作执行器 (支持 Spell, Item, Sequencer, Sub-APL, Action, Variable)
----------------------------------------------------------------------
---@class APLActor
local APLActor = {}
APLActor.__index = APLActor

-- Constructor
---@param actor table
---@return APLActor
function APLActor:New(actor)
    local self = setmetatable({}, APLActor)

    self.actor = actor
    self.traits = {}

    return self
end

-- 为 Actor 挂载一个或多个 Trait 特征条件
---@param ... APLTrait
---@return APLActor
function APLActor:AddTraits(...)
    for _, trait in ipairs({...}) do
        table.insert(self.traits, trait)
    end

    return self
end

-- 获取关联的底层 Actor 配置
---@return table
function APLActor:GetActor()
    return self.actor
end

-- 检查 Actor 绑定的所有 Trait 条件是否全为 true
---@return boolean
function APLActor:Evaluate()
    for _, trait in ipairs(self.traits) do
        if not trait:Evaluate() then
            return false
        end
    end

    return true
end

-- 执行 Actor 绑定的动作
---@return boolean
function APLActor:Execute()
    local act = self:GetActor()
    if not act then return false end

    -- 1. Sequencer 序列器处理
    if act.sequencer then
        local seq = act.sequencer
        local cond = act.condition
        local condPass = (not cond) or (type(cond) == "function" and cond()) or (type(cond) == "boolean" and cond)

        if condPass and not seq:Finished() then
            local executed = seq:Execute()
            if executed then
                if Bastion.DebugMode then
                    Bastion:Print(string.format("[APL Debug] Sequencer step executed in APL '%s'", act._apl and act._apl.name or "main"))
                end
                return true
            end
        end

        -- 如果序列器可重置，进行状态重置
        if seq:ShouldReset() then
            seq:Reset()
        end
    end

    -- 2. 子 APL (Sub-APL) 处理
    if act.apl then
        local cond = act.condition
        local condPass = (not cond) or (type(cond) == "function" and cond()) or (type(cond) == "boolean" and cond)
        if condPass then
            if Bastion.DebugMode then
                Bastion:Print(string.format("[APL Debug] Executing sub-APL: %s", act.apl.name))
            end
            return act.apl:Execute()
        end
    end

    -- 3. GroupSpell 团队/小队智能目标匹配处理
    if act.isGroup and act.spell then
        local spell = act.spell
        local selector = act.selector or "lowest_hp"
        local groupCond = act.groupCondition

        local friends = Bastion.UnitManager:GetSortedFriends(selector)
        local player = Bastion.UnitManager:Get('player')
        for _, friend in ipairs(friends) do
            if friend and friend:IsValid() and friend:IsAlive() then
                local canSee = (not player) or player:IsUnit(friend) or player:CanSee(friend)
                local inRange = player:IsUnit(friend) or spell:IsInRange(friend)
                if canSee and inRange then
                    local pass = not groupCond or (type(groupCond) == "function" and groupCond(friend)) or (type(groupCond) == "boolean" and groupCond)
                    if pass then
                        local castableFunc = act.castableFunc or spell.CastableIfFunc
                        local onCastFunc = act.onCastFunc or spell.OnCastFunc

                        local s = spell
                        if castableFunc then s = s:CastableIf(castableFunc) end
                        if onCastFunc then s = s:OnCast(onCastFunc) end

                        local result = s:Cast(friend)
                        if result then
                            if Bastion.DebugMode then
                                Bastion:Print(string.format("[APL Debug] Cast group spell '%s' on '%s'", spell:GetName() or tostring(spell.id), tostring(friend:GetOMToken() or friend.unit or "friend")))
                            end
                            return true
                        end
                    end
                end
            end
        end
        return false
    end

    -- 3. Spell 法术处理 (支持动态 Target 与智能属性实时捕获)
    if act.spell then
        local spell = act.spell
        -- 优先使用运行时实时获取的目标对象，保障动态切目标 100% 生效
        local target = act.target or spell:GetTarget()
        local cond = act.condition
        local castableFunc = act.castableFunc or spell.CastableIfFunc
        local onCastFunc = act.onCastFunc or spell.OnCastFunc

        local s = spell
        if castableFunc then s = s:CastableIf(castableFunc) end
        if onCastFunc then s = s:OnCast(onCastFunc) end

        local result = s:Cast(target, cond)
        if result then
            if Bastion.DebugMode then
                Bastion:Print(string.format("[APL Debug] Cast spell: %s", spell:GetName() or tostring(spell.id)))
            end
            return true
        end
        return false
    end

    -- 4. Item 物品处理
    if act.item then
        local item = act.item
        local target = act.target or item:GetTarget()
        local cond = act.condition
        local usableFunc = act.usableFunc or item.UsableIfFunc

        local it = item
        if usableFunc then it = it:UsableIf(usableFunc) end

        local result = it:Use(target, cond)
        if result then
            if Bastion.DebugMode then
                Bastion:Print(string.format("[APL Debug] Used item: %s", item:GetName() or tostring(item.id)))
            end
            return true
        end
        return false
    end

    -- 5. Action 显式回调函数处理
    if act.action then
        local result = (act.cb and act.cb(self) == true)
        if result and Bastion.DebugMode then
            Bastion:Print(string.format("[APL Debug] Executed action: %s", tostring(act.action)))
        end
        return result
    end

    -- 6. Variable 局部变量赋值处理 (赋值动作不中断 APL 控制流)
    if act.variable then
        if act._apl and act.cb then
            act._apl.variables[act.variable] = act.cb(act._apl)
        end
        return false
    end

    return false
end

---@return boolean
function APLActor:HasTraits()
    return #self.traits > 0
end

---@return string
function APLActor:__tostring()
    return "Bastion.__APLActor"
end

----------------------------------------------------------------------
-- APL: 动作优先级列表类 (Action Priority List)
----------------------------------------------------------------------
---@class APL
local APL = {}
APL.__index = APL

-- Constructor
---@param name string
---@return APL
function APL:New(name)
    local self = setmetatable({}, APL)

    self.apl = {}
    self.variables = {}
    self.name = name or "Unnamed_APL"

    return self
end

-- 设置 APL 变量
---@param name string
---@param value any
function APL:SetVariable(name, value)
    self.variables[name] = value
end

-- 获取并评估 APL 变量
---@param name string
---@return any
function APL:GetVariable(name)
    return self.variables[name]
end

-- 添加动态变量求值 Actor
---@param name string
---@param cb fun(...):any
---@return APLActor
function APL:AddVariable(name, cb)
    local actor = APLActor:New({
        variable = name,
        cb = cb,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 添加显式动作 Actor
---@param action string
---@param cb fun(...):any
---@return APLActor
function APL:AddAction(action, cb)
    local actor = APLActor:New({
        action = action,
        cb = cb,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 添加法术 Actor
---@param spell Spell
---@param condition? string|fun(...):boolean
---@return APLActor
function APL:AddSpell(spell, condition)
    local actor = APLActor:New({
        spell = spell,
        condition = condition,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 添加团队/小队智能目标法术 Actor (适合治疗/辅助技能)
---@param spell Spell 法术对象
---@param condition fun(friend: Unit):boolean 针对每个队友的筛选判定条件
---@param selector? string "lowest_hp" | "most_deficit" | "highest_hp" 目标选择策略 (默认 lowest_hp)
---@return APLActor
function APL:AddGroupSpell(spell, condition, selector)
    local actor = APLActor:New({
        spell = spell,
        groupCondition = condition,
        selector = selector or "lowest_hp",
        isGroup = true,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 添加物品 Actor
---@param item Item
---@param condition? fun(...):boolean
---@return APLActor
function APL:AddItem(item, condition)
    local actor = APLActor:New({
        item = item,
        condition = condition,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 添加子 APL
---@param apl APL
---@param condition fun(...):boolean
---@return APLActor
function APL:AddAPL(apl, condition)
    if not condition then
        error("Bastion: APL:AddAPL: No condition for APL " .. tostring(apl and apl.name))
    end
    local actor = APLActor:New({
        apl = apl,
        condition = condition,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 添加序列器 Sequencer
---@param sequencer Sequencer
---@param condition? fun(...):boolean
---@return APLActor
function APL:AddSequence(sequencer, condition)
    local actor = APLActor:New({
        sequencer = sequencer,
        condition = condition,
        _apl = self
    })
    table.insert(self.apl, actor)
    return actor
end

-- 执行 APL 列表 (从上至下优先级测试，短路返回首个执行成功的动作)
---@return boolean
function APL:Execute()
    for _, actor in ipairs(self.apl) do
        if actor:HasTraits() then
            if actor:Evaluate() and actor:Execute() then
                return true
            end
        else
            if actor:Execute() then
                return true
            end
        end
    end
    return false
end

-- 重置 APL 生命周期 (清空变量、重置内嵌 Traits 与 Sequencer 状态)
function APL:Reset()
    self.variables = {}
    for _, actor in ipairs(self.apl) do
        if actor.traits then
            for _, trait in ipairs(actor.traits) do
                if trait.Reset then trait:Reset() end
            end
        end
        local act = actor:GetActor()
        if act then
            if act.sequencer and act.sequencer.Reset then
                act.sequencer:Reset()
            end
            if act.apl and act.apl.Reset then
                act.apl:Reset()
            end
        end
    end
end

---@return string
function APL:__tostring()
    return "Bastion.__APL(" .. self.name .. ")"
end

Bastion.APL = APL
Bastion.APLActor = APLActor
Bastion.APLTrait = APLTrait
return APL, APLActor, APLTrait
