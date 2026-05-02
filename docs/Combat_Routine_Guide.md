# Bastion 框架战斗循环开发指南

Bastion 是一个基于 TCX 引擎的高性能 Lua 战斗框架。为了最大化发挥其 C# 层的内存读取优势，框架内部实现了 `Refreshable` (自动刷新缓存) 和 `SpellBook` (单例法术库)。

在 Bastion 中编写战斗循环（Routine），强烈建议遵循以下两套官方支持的范式：**过程式短路闭包 (Procedural)** 与 **声明式攻击优先级列表 (Declarative APL)**。

## 1. 核心基础设施导入 (必须遵守)

无论使用哪种范式，**永远不要在战斗轮询（Tick）中实时实例化对象**。所有的目标和法术必须在文件顶部或 `Init` 阶段完成单例声明。

```lua
local _, Bastion = ...

-- 【正确规范】使用 UnitManager:Get 提取带有自动刷新机制(Refreshable)的单位
local Player = Bastion.UnitManager:Get('player')
local Target = Bastion.UnitManager:Get('target')

-- 【正确规范】使用 SpellBook 单例工厂提取法术
local SpellBook = Bastion.SpellBook:New()
local Moonfire = SpellBook:GetSpell(8921)
local Wrath = SpellBook:GetSpell(5176)
```

> **警告**：绝对不要在 `M:Sync` 内部调用 `Bastion.Spell:New(id)` 或 `ObjectGUID("target")`，这会导致极其严重的内存泄漏和 CPU 性能下降！

---

## 2. 开发范式一：过程式短路闭包 (Procedural)

**适用场景**：绝大多数标准职业、需要灵活处理复杂多变条件（如距离判定、连击点动态消耗、多光环复合判断）的模块。

这种范式利用纯 Lua 的 `if ... then return end` 机制。由于魔兽世界存在公共冷却时间 (GCD)，只要某一个技能成功释放，立即 `return` 中断当前帧的运算，等待下一帧（Ticker）恢复。

### 模板示例：
```lua
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
        if Regrowth:Cast() then return end -- 一旦施放成功，直接 return 打断当前帧
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

Bastion:Register(M)
return M
```

---

## 3. 开发范式二：声明式优先级列表 (Declarative APL)

**适用场景**：模拟器 (SimulationCraft) 风格的开发者、动作极其标准且线性、希望将逻辑按模块拆分（如 `PreCombat`, `SingleTarget`, `AoE`）的庞大专精循环。

经过底层修复后的 `APL.lua`，现在完美支持 `return true` 的事件向上传导。系统会自动在每个 Tick 中按顺序 Evaluate（计算条件），并自动触发 Cast() 且处理 GCD 阻断。

### 模板示例：
```lua
local M = Bastion.Module:New("WarlockInitial")
M:SetDisplayName("Warlock Initial", "术士新手")

-- 初始化 APL 树
local CoreAPL = Bastion.APL:New("Core")

-- 语法：APL:AddSpell(法术对象, 触发条件函数)
-- 只有在 Target 身上没有腐蚀术，且满足释放条件时才会释放
CoreAPL:AddSpell(Corruption, function()
    return Target:IsValid() and not Target:IsDead() and not Target:HasAura(Corruption.id, "player")
end)

CoreAPL:AddSpell(ShadowBolt, function()
    return Target:IsValid() and not Target:IsDead()
end)

-- 挂载执行树
M:Sync(function()
    CoreAPL:Execute()
end)

Bastion:Register(M)
return M
```

### APL 高阶用法（子树嵌套）：
您可以创建多个 APL，并将它们拼接起来：
```lua
local SingleTargetAPL = Bastion.APL:New("SingleTarget")
local AoEAPL = Bastion.APL:New("AoE")

-- 当周围敌人数量 >= 3 时，打断 Core 执行，切入 AoEAPL 分支
CoreAPL:AddAPL(AoEAPL, function()
    return Player:GetEnemies(8) >= 3
end)

-- 否则进入单体分支
CoreAPL:AddAPL(SingleTargetAPL, function()
    return Player:GetEnemies(8) < 3
end)
```

---

## 4. 总结与建议

| 特性 | 过程式 (Procedural `M:Sync`) | 声明式 (Declarative `APL:New`) |
| :--- | :--- | :--- |
| **执行性能** | **极高** (纯原生 if 语句，无表遍历开销) | 中高 (每帧需要遍历 APL 列表) |
| **可读性** | 适合自上而下的阅读逻辑，代码量极简 | 适合按树状结构管理巨型逻辑 |
| **灵活性** | 极强，可随时插入极其复杂的运算 | 较弱，强依赖匿名 `function()` 返回布尔值 |

**最终指导原则**：
在当前的 TCX-Retail / Bastion 环境下，**首选过程式短路闭包 (Procedural) 方案**。只有当面对类似“三系混合德鲁伊”或拥有几十个复合状态判断的满级大秘境模块时，才建议利用 APL 的子树嵌套特性来分割代码复杂度。
