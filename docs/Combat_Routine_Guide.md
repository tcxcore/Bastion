# Bastion 框架战斗循环开发指南

Bastion 是一个基于 TCX 引擎的高性能 Lua 战斗框架。为了最大化发挥其 C++ 层的内存读取优势，框架内部实现了 `Refreshable` (自动刷新缓存) 和 `SpellBook` (单例法术库)。

在目前的架构中，所有战斗循环（Combat Routine，简称 CR）已改造成**外部独立注册**模式，存放在独立项目 **[Bastion-CR]** 中，不再内置于主框架目录。

编写战斗循环时，必须遵守外部独立加载范式，并首选使用 **过程式短路闭包 (Procedural)** 或 **声明式攻击优先级列表 (Declarative APL)** 范式。

---

## 1. 外部独立注册架构与职业判定 (必须遵守)

为了实现按需加载与物理隔离，每个战斗循环脚本的最顶层必须最先判断玩家职业，如果不符则直接退出，避免无效内存占用；而在文件尾部则使用 `TryRegister` 轮询注册机制，向宿主窗体进行异步安全挂载。

### 统一头部职业判定
```lua
local tcx = ...

local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then return end  -- 以德鲁伊为例，若不是当前职业则直接阻断退出
```

### 统一尾部安全注册
```lua
local function TryRegister()
    local hostFrame = GetClickFrame("BastionHostFrame")
    if hostFrame and hostFrame.RegisterModule then
        hostFrame:RegisterModule(CreateModule)
        print("|cFF00FF00[Druid]|r 守护德鲁伊战斗循环已挂载。")
        return true
    end
    return false
end

if not TryRegister() then
    local waitFrame = CreateFrame("Frame")
    local elapsed = 0
    waitFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if TryRegister() then
            self:SetScript("OnUpdate", nil)
        elseif elapsed > 15 then
            self:SetScript("OnUpdate", nil)
            print("|cFFFF0000[Druid]|r 加载超时：未检测到 Bastion 框架，模块未注册。")
        end
    end)
end
```

---

## 2. 核心基础设施导入

模块的所有实体及逻辑都包裹在 `CreateModule(Bastion)` 入口函数中。目标和法术必须在入口函数顶部进行单例声明，**绝对禁止在 `M:Sync` 轮询中实时实例化对象**。

```lua
local function CreateModule(Bastion)
    local L = Bastion.Locale

    -- 【正确规范】使用 UnitManager:Get 提取带有自动刷新机制(Refreshable)的单位
    local Player = Bastion.UnitManager:Get('player')
    local Target = Bastion.UnitManager:Get('target')

    -- 【正确规范】使用 SpellBook 单例工厂提取法术
    local SpellBook = Bastion.SpellBook:New()
    local Moonfire = SpellBook:GetSpell(8921)
    local Wrath = SpellBook:GetSpell(5176)
    
    -- 模块定义
    local M = Bastion.Module:New("DruidInitial")
    M:SetDisplayName("Druid Initial", "德鲁伊新手")
    
    -- M:DefineSettings(...) 与 M:Sync(...) 在此编写
    
    return M
end
```

> **警告**：绝对不要在 `M:Sync` 内部调用 `Bastion.Spell:New(id)` 或 `ObjectGUID("target")`，这会导致极其严重的内存泄漏和 CPU 性能下降！

---

## 3. 开发范式一：过程式短路闭包 (Procedural)

**适用场景**：绝大多数标准职业、需要灵活处理复杂多变条件（如距离判定、连击点动态消耗、多光环复合判断）的模块。

这种范式利用纯 Lua 的 `if ... then return end` 机制。由于魔兽世界存在公共冷却时间 (GCD)，只要某一个技能成功释放，立即 `return` 中断当前帧的运算，等待下一帧（Ticker）恢复。

### 模板示例：
```lua
local tcx = ...

local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then return end

local function CreateModule(Bastion)
    local L = Bastion.Locale

    local Player = Bastion.UnitManager:Get('player')
    local Target = Bastion.UnitManager:Get('target')
    local SpellBook = Bastion.SpellBook:New()
    local Regrowth = SpellBook:GetSpell(8936)
    local Moonfire = SpellBook:GetSpell(8921)
    local Wrath = SpellBook:GetSpell(5176)

    local M = Bastion.Module:New("DruidInitial")
    M:SetDisplayName("Druid Initial", "德鲁伊新手")

    M:DefineSettings({
        { type = "slider", key = "heal_hp", label = "Heal Threshold (%)", min = 10, max = 100, default = 40 }
    })

    M:Sync(function()
        -- 1. 脱战逻辑与形态管理
        if not Player:IsAffectingCombat() then return end

        -- 2. 治疗与自保 (最高优先级)
        if Player:HealthPercent() < M:GetSetting("heal_hp") then
            if Regrowth:Cast() then return end -- 一旦施放成功，直接 return
        end

        -- 3. 目标有效性阻断
        if not Target:IsValid() or Target:IsDead() then return end

        -- 4. 核心输出优先级
        if not Target:HasAura(Moonfire.id, "player") then
            if Moonfire:Cast() then return end
        end

        -- 5. 填充技能
        if Wrath:Cast() then return end
    end)

    return M
end

-- 尾部加入 TryRegister 异步安全注册代码（省略，具体见第1节）
```

---

## 4. 开发范式二：声明式优先级列表 (Declarative APL)

**适用场景**：模拟器 (SimulationCraft) 风格的开发者、动作极其标准且线性、希望将逻辑按模块拆分的庞大专精循环。

### 4.1 APL 高级特性与团队治疗支持 (v1.0.6)
1. **`APL:AddGroupSpell` 团队智能目标判定**：专门针对治疗与小队/团队辅助设计。支持语法：`APL:AddGroupSpell(spell, function(friend) ... end, "lowest_hp")`。它会自动检索全队有效成员，按 `"lowest_hp"` (最残血) 或 `"most_deficit"` (缺血绝对值最多) 进行排序，**直接下发 `CastSpellByName(spellName, token)`** 施法，无需切换玩家目标！
2. **`UnitManager:GetGroupUnits()` 3D+Token 双重保障**：自动结合 3D 内存对象池与原生 `party1~4`/`raid1~40` 索引，彻底避免远距离超视距队友漏检。
3. **动态目标绑定**：`APL:AddSpell` / `AddItem` 会在运行时动态实时读取 `spell:GetTarget()`，完全支持在战斗中通过 `spell:SetTarget(newUnit)` 动态切换目标。
4. **`APLTrait` 节流与缓存失效**：高频条件可通过 `Bastion.APLTrait:New(cb, ttl)` 包装（默认 0.05s 节流），并可通过 `trait:Invalidate()` 手动显式失效缓存。
5. **Sequencer 安全降级**：当内嵌的 `Sequencer` 动作因 CD/能量不足未能成功释放时，APL 智能降级并自动下刷后续优先级动作，不会导致整帧死锁。
6. **`APL:Reset()` 生命周期**：支持在脱战或重置模块时自动清空变量与重置内嵌序列器、Traits 状态。

### 模板示例 (治疗 APL 范例)：
```lua
local tcx = ...

local _, englishClass = UnitClass("player")
if englishClass ~= "DRUID" then return end

local function CreateModule(Bastion)
    local L = Bastion.Locale

    local Player = Bastion.UnitManager:Get('player')
    local SpellBook = Bastion.SpellBook:New()
    local Rejuvenation = SpellBook:GetSpell(774)  -- 回春术
    local Regrowth     = SpellBook:GetSpell(8936) -- 愈合

    local M = Bastion.Module:New("RestoDruidAPL")
    M:SetDisplayName("Resto Druid APL", "恢复德鲁伊 APL")

    -- 初始化 APL 树
    local HealAPL = Bastion.APL:New("HealCore")

    -- 规则 1：给血量 < 85% 且没有回春术的队友挂【回春术】 (最残血优先)
    HealAPL:AddGroupSpell(Rejuvenation, function(friend)
        return friend:IsAlive() and friend:HealthPercent() < 85 and not friend:HasAura(Rejuvenation.id, "player")
    end, "lowest_hp")

    -- 规则 2：给血量 < 50% 的队友读【愈合】 (最缺血绝对值优先)
    HealAPL:AddGroupSpell(Regrowth, function(friend)
        return friend:IsAlive() and friend:HealthPercent() < 50
    end, "most_deficit")

    -- 挂载执行树 (脱战或重置时可调用 HealAPL:Reset())
    M:Sync(function()
        if not Player:IsAffectingCombat() then return end
        HealAPL:Execute()
    end)

    return M
end

-- 尾部加入 TryRegister 异步安全注册代码（省略，具体见第1节）
```

---

## 5. 总结与建议

| 特性 | 过程式 (Procedural `M:Sync`) | 声明式 (Declarative `APL:New`) |
| :--- | :--- | :--- |
| **执行性能** | **极高** (纯原生 if 语句，无表遍历开销) | 中高 (包含 APL 树遍历、排序与 Trait 缓存机制) |
| **可读性** | 适合自上而外的阅读逻辑，代码量极简 | 适合按树状结构管理巨型逻辑或团队治疗优先级 |
| **灵活性** | 极强，可随时插入极其复杂的运算 | 强，支持 APL 子树嵌套、团队智能目标 (`AddGroupSpell`) 与 Sequencer 下刷 |

**最终指导原则**：
在当前的 TCX-Retail / Bastion 环境下，**输出与坦克专精首选过程式短路闭包 (Procedural) 方案**；而在开发**团队治疗（奶德/奶骑/神牧/增辉）模块**或拥有复合逻辑的大型专精时，推荐利用 `AddGroupSpell` 声明式 APL 树来分割代码复杂度。
