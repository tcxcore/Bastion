# TCX-Retail 扩展 Lua API 开发文档
# 版本: 2.0.3
本文档整理了 `TCX-Retail` 目前在 Lua 虚拟机中注入的所有底层扩展 API。这些 API 大部分是为了兼容 Tinkr 规范而设计，并对底层内存机制进行了安全封装。

所有扩展 API 均挂载在 `C_Timer.TCX` 表下。

---

## 1. 核心系统执行 (System Execution)

### `Unlock(fnName, ...)`
- **说明**: 突破硬件保护，执行被保护（Protected）的原生 WoW API 而不会触发 Taint（污染）。
  **【自动解密特性】**：此方法在执行底层 API 时，会**自动清理所有返回值的 `secret` 加密标志位**。对于那些原生环境会返回加密值（Secret Value）的函数（例如某些坐标获取、底层状态函数等），你**必须**通过此函数进行调用，才能获取到解密后的真实可用数据。
  > **性能提示**: `Unlock` 内部涉及环境切换和拦截，开销相对较高。如果该原生 API **没有被暴雪设为受保护（Protected）**，仅仅是因为返回了 Secret 加密值，**强烈建议直接调用原生函数然后用 `Unwrap` 进行解密**以提高执行性能。
- **参数**: 
  - `fnName` (string): 全局函数的名称（如 `"CastSpellByName"`）。
  - `...`: 传递给该函数的参数。
- **返回**: 原生函数执行后的所有解密返回值。
- **示例**: 
  ```lua
  C_Timer.TCX.Unlock("CastSpellByName", "回春术")
  ```

### `RunScript(scriptStr)`
- **说明**: 直接使用底层执行缓冲区运行任意宏/脚本字符串，完美绕过原生环境的降级限制。全局的 `RunScript` 也会被重写为此方法。
- **参数**: 
  - `scriptStr` (string): Lua 代码字符串。
- **示例**: 
  ```lua
  C_Timer.TCX.RunScript("print('Hello from TCX!')")
  ```

### `IsInGame()`
- **说明**: 检查当前玩家是否已完全加载进游戏世界并且未处于蓝条/过图加载画面中。此方法通过底层 `LoadingScreenPtr` 偏移进行高精度判定，用于防止在场景切换时发生 API 竞争或崩溃。
- **返回**: `boolean` (是否完全进入游戏)
- **示例**: 
  ```lua
  if C_Timer.TCX.IsInGame() then
      print("玩家已完全加载进世界中，可以安全执行脚本")
  end
  ```

---

## 2. 对象系统 (Object System)

> [!WARNING]
> **绝对实时数据，禁止缓存！**
> 本系统提供的所有对象属性访问 API（如 `Objects`、`ObjectPosition`、`ObjectHealth`、`ObjectFlags` 等）在底层均是**无延迟直接读取当前内存**。
> 这些数据具有极高的时效性，但也极易发生变化。**严禁在 Lua 中将这些返回值缓存为全局或长生命周期的变量！**
> 任何需要使用状态的地方，都必须实时调用接口进行获取（Poll），否则你将得到过期（Stale）的甚至可能导致逻辑崩溃的旧数据。

TCX 的对象 API 全面支持 **多态传参**，所有接受 `obj` 的参数均支持以下三种形式：
1. **原生 Token** (string)：如 `'player'`, `'target'`, `'focus'`, `'party1'` 等。
2. **原生 GUID 字符串** (string)：格式与魔兽世界原生 API（如 `UnitGUID("target")` 或 `ObjectGUID(obj)`）返回的字符串完全一致，如 `'Player-970-00108A83'` 或 `'Creature-0-3113-0-0-12345-0000000000'`。
3. **底层对象指针句柄** (userdata)：通过调用 `C_Timer.TCX.Objects()` 遍历返回的内存引用或`C_Timer.TCX.Object()` 返回的内存引用.

### `Object(val)`
- **说明**: 根据传入的标志或 GUID，获取对象引用句柄。
- **参数**: `val` (string): 可以是 Token (如 `"target"`, `"player"`) 或者是 GUID (如 `"Player-970-00108A83"`)。
- **返回**: `object` (对象底层句柄，获取失败返回 nil)
- **示例**: 
  ```lua
  local myTarget = C_Timer.TCX.Object("target")
  if myTarget then
      print("目标存在:", C_Timer.TCX.ObjectName(myTarget))
  end
  ```

### `Objects([filterType])`
- **说明**: 遍历当前对象管理器（ObjectManager）中的所有对象，返回一个包含所有符合条件对象的数组表。
- **参数**: 
  - `filterType` (number, 可选): 对象类型 ID。如果不传或传 0，则返回所有对象。
    - `5` = Unit (NPC/怪物)
    - `6` = Player (其他玩家)
    - `7` = ActivePlayer (当前玩家自身)
    - `8` = GameObject (游戏物品/矿石/鱼漂等)
- **返回**: `table` (对象数组)
- **示例**: 
  ```lua
  -- 获取周围所有的单位(Unit)
  local units = C_Timer.TCX.Objects(5)
  for i, obj in ipairs(units) do
      print(C_Timer.TCX.ObjectName(obj))
  end
  ```

### `ObjectPosition(obj)`
- **说明**: 获取对象的 3D 坐标。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `x, y, z` (numbers)
- **示例**: 
  ```lua
  local px, py, pz = C_Timer.TCX.ObjectPosition('player')
  print("玩家坐标:", px, py, pz)
  ```

### `ObjectName(obj)`
- **说明**: 获取对象的名称。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `string`
- **示例**: 
  ```lua
  local name = C_Timer.TCX.ObjectName('target')
  print("目标的名字是:", name)
  ```

### `ObjectHealth(obj)` / `ObjectMaxHealth(obj)`
- **说明**: 获取目标当前的生命值 / 最大生命值。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local hp = C_Timer.TCX.ObjectHealth('target')
  local maxHp = C_Timer.TCX.ObjectMaxHealth('target')
  print("目标血量比例: " .. (hp / maxHp * 100) .. "%")
  ```

### `ObjectPower(obj)` / `ObjectMaxPower(obj)`
- **说明**: 获取目标当前的能量值 / 最大能量值（如法力、怒气、能量等）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local power = C_Timer.TCX.ObjectPower('player')
  local maxPower = C_Timer.TCX.ObjectMaxPower('player')
  print("玩家当前主资源比例: " .. (power / maxPower * 100) .. "%")
  ```

### `ObjectPower2(obj)` / `ObjectMaxPower2(obj)`
- **说明**: 获取目标当前的副能量值 / 最大副能量值（如死亡骑士的符文、德鲁伊的连击点等）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local power2 = C_Timer.TCX.ObjectPower2('player')
  print("玩家当前副资源: ", power2)
  ```

### `ObjectDisplayId(obj)`
- **说明**: 获取目标的外观 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local displayId = C_Timer.TCX.ObjectDisplayId('target')
  print("当前目标外观ID: ", displayId)
  ```

### `ObjectCreatureId(obj)`
- **说明**: 获取目标的生物 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local creatureId = C_Timer.TCX.ObjectCreatureId('target')
  print("当前目标生物ID: ", creatureId)
  ```

### `ObjectId(obj)`
- **说明**: 获取目标的底层实体 ID (Entry ID)。对于 NPC 或怪物，它代表 `CreatureID`（如 12345）；对于物品或游戏对象，代表 `ItemID` 或 `GameObject ID`。底层通过直接读取 `Descriptor_EntryID` 偏移获取，具有极高精度。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (Entry ID)
- **示例**: 
  ```lua
  local entryId = C_Timer.TCX.ObjectId('target')
  print("当前目标的实体 ID: ", entryId)
  ```

### `ObjectMountDisplayId(obj)`
- **说明**: 获取目标坐骑的外观 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local mountId = C_Timer.TCX.ObjectMountDisplayId('target')
  if mountId > 0 then print("目标正骑在坐骑上, 外观ID: ", mountId) end
  ```

### `ObjectRace(obj)`
- **说明**: 获取目标的种族 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local raceId = C_Timer.TCX.ObjectRace('player')
  print("玩家种族ID: ", raceId)
  ```

### `ObjectClass(obj)`
- **说明**: 获取目标的职业 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local classId = C_Timer.TCX.ObjectClass('player')
  if classId == 1 then print("玩家是战士") end
  ```

### `ObjectGender(obj)`
- **说明**: 获取目标的性别 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local genderId = C_Timer.TCX.ObjectGender('player')
  print("玩家性别ID: ", genderId)
  ```

### `ObjectCreatureType(obj)`
- **说明**: 获取目标的生物类型（如野兽、恶魔等）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local creatureType = C_Timer.TCX.ObjectCreatureType('target')
  print("目标生物类型ID: ", creatureType)
  ```

### `ObjectPowerType(obj)`
- **说明**: 获取目标的能量类型（如法力、怒气等）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local powerType = C_Timer.TCX.ObjectPowerType('player')
  print("玩家主能量类型ID: ", powerType)
  ```

### `ObjectLevel(obj)`
- **说明**: 获取目标的等级。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local level = C_Timer.TCX.ObjectLevel('target')
  print("目标等级: ", level)
  ```

### `ObjectFactionTemplate(obj)`
- **说明**: 获取目标的阵营模板 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local faction = C_Timer.TCX.ObjectFactionTemplate('target')
  print("目标阵营模板: ", faction)
  ```

### `ObjectDynamicFlags(obj)`
- **说明**: 获取目标的动态状态掩码 (DynamicFlags)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local dynamicFlags = C_Timer.TCX.ObjectDynamicFlags('target')
  print("动态Flags: ", dynamicFlags)
  ```

### `ObjectAuraState(obj)`
- **说明**: 获取目标底层光环状态掩码 (AuraState)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local auraState = C_Timer.TCX.ObjectAuraState('target')
  print("光环State: ", auraState)
  ```

### `ObjectNpcFlags(obj)`
- **说明**: 获取目标底层的 NPC 交互标志位 (NpcFlags)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local npcFlags = C_Timer.TCX.ObjectNpcFlags('target')
  -- 检查是否可以对话/任务
  if bit.band(npcFlags, 0x01) ~= 0 then print("可对话NPC") end
  ```

### `ObjectUnitFlags(obj)`
- **说明**: 获取目标底层的单位标志位 (UnitFlags)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local unitFlags = C_Timer.TCX.ObjectUnitFlags('target')
  -- 检查目标是否不可攻击
  if bit.band(unitFlags, 0x02) ~= 0 then print("目标不可攻击") end
  ```

### `ObjectSpeed(obj)`
- **说明**: 获取目标的当前奔跑速度。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数)
- **示例**: 
  ```lua
  local speed = C_Timer.TCX.ObjectSpeed('player')
  print("当前移动速度: ", speed)
  ```

### `ObjectIsInCombat(obj)`
- **说明**: 快捷判断单位是否处于战斗中。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean`
- **示例**: 
  ```lua
  if C_Timer.TCX.ObjectIsInCombat('player') then
      print("玩家正在战斗中！")
  end
  ```

### `ObjectIsMounted(obj)`
- **说明**: 快捷判断单位是否在坐骑上。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean`
- **示例**: 
  ```lua
  if C_Timer.TCX.ObjectIsMounted('player') then
      print("玩家正在骑乘状态")
  end
  ```

### `ObjectHasPaladinAura(obj)`
- **说明**: 快捷判断单位是否拥有圣骑士光环。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean`
- **示例**: 
  ```lua
  if C_Timer.TCX.ObjectHasPaladinAura('player') then
      print("玩家受到圣骑士光环影响")
  end
  ```

### `ObjectTargetGuid(obj)`
- **说明**: 获取目标当前正在锁定的目标 GUID 字符串（如敌对怪物锁定的第一仇恨）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `string` (GUID) 或者 `nil`。
- **示例**: 
  ```lua
  local targetOfTarget = C_Timer.TCX.ObjectTargetGuid('target')
  if targetOfTarget then print("目标的目标是: ", targetOfTarget) end
  ```

### `ObjectType(obj)`
- **说明**: 获取目标的类型 ID（参考 `Objects` 参数）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local typeId = C_Timer.TCX.ObjectType('target')
  if typeId == 5 then
      print("目标是一个 NPC 或怪物")
  end
  ```

### `ObjectGUID(obj)`
- **说明**: 获取目标对象的 GUID 字符串（与原生 `UnitGUID()` 格式完全一致）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `string`
- **示例**: 
  ```lua
  local guid = C_Timer.TCX.ObjectGUID('player')
  print("玩家GUID:", guid)
  ```

### `ObjectToken(obj)`
- **说明**: 高性能反向查找对象的 UnitToken。给定一个对象引用（`Object()` 返回的 lightuserdata 或 `ObjectGUID()` 返回的 GUID 字符串），返回该对象在引擎 Token 系统中对应的原生 Token 字符串。如果该对象没有匹配的原生 Token，则**自动将其设置为 Mouseover** 并返回 `"mouseover"`。
- **查找优先级**（按顺序匹配，命中即返回）：
  1. `"player"` — ActivePlayerSession GUID 比较
  2. `"target"` / `"focus"` / `"npc"` / `"softinteract"` / `"softenemy"` / `"softfriend"` / `"mouseover"` — 7 个固定全局槽位
  3. `"party1"` ~ `"party4"` — 小队成员
  4. `"raid1"` ~ `"raid40"` — 团队成员（仅团队模式下遍历）
  5. `"nameplate1"` ~ `"nameplate150"` — 姓名板全局数组
  6. **Fallback**: 自动调用 `SetMouseover(obj)` 并返回 `"mouseover"`
- **参数**: `obj` (多态): 目标对象 (GUID 字符串 / 指针句柄)。
- **返回**: `string` (Token 字符串，如 `"player"`, `"target"`, `"party1"`, `"nameplate5"`, `"mouseover"` 等)；对象无效时返回 `nil`。
- **示例**: 
  ```lua
  -- 用法: 遍历对象管理器中的单位，自动获取可用 Token
  local units = C_Timer.TCX.Objects(5)
  for _, obj in ipairs(units) do
      local token = C_Timer.TCX.ObjectToken(obj)
      -- token 保证非 nil（最差情况返回 "mouseover" 并自动设置 Mouseover）
      -- 可直接传给原生暴雪 API，无需手动 SetMouseover/清理
      local hp = UnitHealth(token)
      print(C_Timer.TCX.ObjectName(obj), "HP:", hp, "Token:", token)
  end
  ```
  > **与 `SetMouseover` 的区别**: `ObjectToken` 是一个**一站式 Token 解析器**。传统做法需要手动判断对象类型、调用 `SetMouseover`、使用 `"mouseover"` 执行原生 API、最后再 `SetMouseover(nil)` 清理，共 4 步操作。`ObjectToken` 将这一切简化为单次调用，并且在对象已有原生 Token 时**完全零副作用**（不修改 Mouseover 槽位）。

### `ObjectDistance(obj1, obj2)`
- **说明**: 计算两个对象之间的直线距离。
- **参数**: 
  - `obj1` (多态): 起点对象 (Token / GUID 字符串 / 指针句柄)。
  - `obj2` (多态): 终点对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local dist = C_Timer.TCX.ObjectDistance('player', 'target')
  print("距离目标:", dist, "码")
  ```

### `ObjectCreator(obj)`
- **说明**: 获取该对象的创建者对象引用（常用于判断图腾/宠物归属）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `object` (与 Objects() 遍历出来的底层对象句柄相同)
- **示例**: 
  ```lua
  local creatorObj = C_Timer.TCX.ObjectCreator('pet')
  if creatorObj and C_Timer.TCX.ObjectGUID(creatorObj) == C_Timer.TCX.ObjectGUID('player') then
      print("这是我的宠物")
  end
  ```

### `ObjectRotation(obj)`
- **说明**: 获取目标对象的朝向角（弧度，0 ~ 2π）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
### `ObjectFlags(obj)`
- **说明**: 获取目标对象的各类标志位，保持与 Tinkr 兼容的接口行为。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: 
  - 如果是 **Unit/Player**: 返回 7 个值 `(flags1, flags2, flags3, flags4, unitFlags1, unitFlags2, dynamicFlags)`
    - `flags1`: 映射为底层 `NpcFlags` (如 `0x01` 允许对话, `0x02` 任务发布者, `0x80` 商人)。
    - `unitFlags1`: 映射为底层 `UnitFlags` (如 `0x02` 不可攻击, `0x04` 无法移动)。
    - `dynamicFlags`: 映射为底层 `StateFlags` (状态/交互标志)。
    - *注: 为保证接口兼容性，部分 Retail 弱化使用的标志位（如 flags2-4）补零返回。*
  - 如果是 **GameObject**: 返回 2 个值 `(flags, animationFlags)`
    - `flags`: 映射为底层 `GameObjectFlags` (如 `0x01` 使用中, `0x02` 锁定, `0x04` 无法交互)。
    - `animationFlags`: 映射为底层 `AnimState` 动画状态标志（如 `0x02` 表示鱼漂正在跳动/咬钩）。
- **示例**: 
  ```lua
  -- 判断鱼漂是否处于动画跳动(咬钩)状态
  local _, animationFlags = C_Timer.TCX.ObjectFlags(bobberObj)
  if animationFlags and bit.band(animationFlags, 0x02) ~= 0 then
      print("鱼咬钩了！")
  end
  ```

### `ObjectCastingTarget(obj)`
- **说明**: 获取任意单位当前的施法目标/选中目标对象指针。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: 成功返回 `lightuserdata` (目标对象的原生底层指针)；如果无目标或无效则返回 `nil`。
- **示例**: 
  ```lua
  local targetObj = C_Timer.TCX.ObjectCastingTarget("player")
  if targetObj then
      local name = C_Timer.TCX.ObjectName(targetObj)
      print("你当前的底层交互目标是: " .. (name or "未知"))
  end
  ```

### `ObjectBoundingRadius(obj)`
- **说明**: 获取对象的物理边界半径（Bounding Radius）。决定角色或怪物实际占地面积和被 AOE 命中的物理体积大小。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数) 表示碰撞体积半径；无效返回 `false`。
- **示例**: 
  ```lua
  local radius = C_Timer.TCX.ObjectBoundingRadius("player")
  if radius then
      print("玩家自身的物理边界半径为:", radius)
  end
  ```

### `ObjectCombatReach(obj)`
- **说明**: 获取对象的战斗距离（Combat Reach）。用于计算两实体之间是否满足近战交互或攻击范围，计算互动距离时需包含此值。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数) 表示战斗有效距离；无效返回 `false`。
- **示例**: 
  ```lua
  local reach = C_Timer.TCX.ObjectCombatReach("target")
  if reach then
      print("当前目标的战斗范围 (CombatReach) 为:", reach)
  end
  ```

### `ObjectMovementFlag(obj)`
- **说明**: 获取对象的当前移动状态标志位。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (uint32) 对应底层的 MovementFlags 位掩码；若无效返回 `0`。
- **示例**: 
  ```lua
  local flags = C_Timer.TCX.ObjectMovementFlag("player")
  -- 根据实际标志位进行与操作，例如 0x01 可能表示正在向前移动
  if bit.band(flags, 0x01) ~= 0 then
      print("玩家当前正在移动")
  end
  ```

### `ObjectAuras(obj)`
- **说明**: 获取目标身上所有的动态光环（Buff/Debuff）列表。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `table` (包含光环信息的 Lua 数组表，每项包含 `spellId`, `flags`, `duration`, `endTime`, `stackCount`, `casterGuid` 字段)。
- **示例**: 
  ```lua
  local auras = C_Timer.TCX.ObjectAuras('target')
  for i, aura in ipairs(auras) do
      print("光环ID:", aura.spellId, "层数:", aura.stackCount)
  end
  ```

### `ObjectHasAura(obj, auraId)`
- **说明**: 快速检查目标身上是否包含指定的光环（法术ID）。
- **参数**: 
  - `obj` (多态): 目标对象。
  - `auraId` (number): 要检查的光环法术 ID。
- **返回**: `boolean` (是否拥有该光环)
- **示例**: 
  ```lua
  if C_Timer.TCX.ObjectHasAura('player', 774) then
      print("玩家身上有回春术")
  end
  ```

### `ObjectIsOutdoors(obj)`
- **说明**: 判断目标对象是否处于室外。通过向上方发射高精度的物理碰撞射线检测是否有屋顶或遮挡（World 或 WMO）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean` (是否在室外)
- **示例**: 
  ```lua
  if C_Timer.TCX.ObjectIsOutdoors("player") then
      print("玩家处于室外，可以骑乘飞行坐骑！")
  end
  ```

### `ObjectIsSubmerged(obj)`
- **说明**: 判断目标对象是否浸泡在水中（被水面淹没）。对于单位对象直接使用底层引擎判定；对于游戏对象（如水下草药/矿脉），通过发射向下射线高精度检测水面碰撞。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean` (是否在水中)
- **示例**: 
  ```lua
  if C_Timer.TCX.ObjectIsSubmerged("target") then
      print("目标在水下，请注意呼吸条！")
  end
  ```

### `ObjectLootable(obj)`
- **说明**: 判断目标对象是否可被拾取。针对12.0.5更新，通过直接读取 Descriptor 的 DynamicFlags 高精度判定单位尸体是否有“发光/闪光”掉落物；对于游戏对象则判定其是否包含战利品。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean` (是否可拾取)
- **示例**: 
  ```lua
  if UnitIsDead("target") and C_Timer.TCX.ObjectLootable("target") then
      print("发现闪光的尸体，快去摸尸！")
  end
  ```

### `ObjectHeight(obj)`
- **说明**: 获取目标对象的实际物理 Z 轴模型高度（融合了 BaseHeight 和动态 Scale 缩放比例）。常用于计算挂载姓名板的实际 3D 坐标，或在复杂地形进行精准视线与技能覆盖检测。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数，模型高度)
- **示例**: 
  ```lua
  local height = C_Timer.TCX.ObjectHeight("target")
  print("目标模型高度为:", height)
  ```

---

## 3. 交互与控制 (Interaction & Targeting)

### `RightClickObject(obj, [mode])`
- **说明**: 模拟鼠标右键点击对象。可以用于自动攻击、对话 NPC、拾取尸体、采集草药/矿物等。
- **参数**:
  - `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
  - `mode` (number, 默认为 1): 交互模式。
- **返回**: `boolean` (是否执行成功)
- **示例**: 
  ```lua
  -- 拾取尸体或对话
  if UnitIsDeadOrGhost('target') then
      C_Timer.TCX.RightClickObject('target')
  end
  ```

### `LeftClickObject(obj)`
- **说明**: 模拟鼠标左键点击对象。通常用于将对象设置为当前目标。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `boolean` (是否执行成功)
- **示例**: 
  ```lua
  -- 选中鼠标悬停的单位
  C_Timer.TCX.LeftClickObject('mouseover')
  ```

### `SetTargetObject(obj, [mode])`
- **说明**: 强制将本地玩家的目标设置为该对象。
- **参数**: 
  - `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
  - `mode` (number, 默认为 1): 交互模式 (如 5=软目标)。
- **示例**: 
  ```lua
  -- 将焦点目标设置为当前目标
  C_Timer.TCX.SetTargetObject('focus')
  ```

### `SetMouseover(obj)`
- **说明**: 临时将一个对象设置为本地玩家的悬停目标（Mouseover），而不会触发屏幕高光或 UI 闪烁。这是一种高级内存劫持技巧，常用于对**没有原生 Token 的任意内存实体**执行底层 API 查询。传入 `nil` 可清空该状态。
- **参数**: `obj` (多态 | nil): 目标对象 (Token / GUID 字符串 / 指针句柄)，或者 `nil` 来清空伪装状态。
- **示例**: 
  ```lua
  -- 遍历周围所有的单位(Unit, 枚举值为 5)
  local units = C_Timer.TCX.Objects(5)
  for _, obj in ipairs(units) do
      if C_Timer.TCX.ObjectName(obj) == "德纳修斯大帝" then
          -- 找到特定 Boss 后，将其临时劫持为 mouseover
          -- 这样即使你没有选中它，也能对其使用 WoW 原生 API
          C_Timer.TCX.SetMouseover(obj)
          
          -- 完美利用原生 API 获取其复杂属性（无需重新造轮子）
          local hp = UnitHealth("mouseover")
          local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("mouseover")
          
          if name and notInterruptible then
              print("警告：" .. name .. " 是不可打断的技能！")
          end
          
          -- 用完后立刻清理内存槽位，不留痕迹
          C_Timer.TCX.SetMouseover(nil)
          break
      end
  end
  ```

### `ClickPosition(x, y, z)`
- **说明**: 面向地面的范围技能（如暴风雪、烈焰风暴）点击释放。在法术处于“鼠标瞄准”状态时，调用此函数将在指定坐标立刻施法。
- **返回**: `boolean` (成功或失败)
- **示例**: 
  ```lua
  -- 对目标脚下释放地毯技能 (需先 CastSpellByName("暴风雪"))
  local tx, ty, tz = C_Timer.TCX.ObjectPosition('target')
  C_Timer.TCX.ClickPosition(tx, ty, tz)
  ```

---

## 4. 移动与空间感知 (Movement & Vision)

### `GetCorpsePosition()`
- **说明**: 获取玩家死亡后尸体的全局世界坐标。如果找不到尸体（例如存活状态或跨服等特殊环境异常），将返回 false。
- **返回**: `x, y, z` (numbers) 或 `false`
- **示例**: 
  ```lua
  if UnitIsDeadOrGhost('player') then
      local cx, cy, cz = C_Timer.TCX.GetCorpsePosition()
      if cx then
          print("尸体坐标:", cx, cy, cz)
      end
  end
  ```

### `TraceLine(sx, sy, sz, ex, ey, ez, [flags])`
- **说明**: 执行底层的视线（Line of Sight）和物理碰撞检测（Raycast）。
- **参数**:
  - `sx, sy, sz` (numbers): 射线起点。
  - `ex, ey, ez` (numbers): 射线终点。
  - `flags` (number, 可选): 碰撞标志位掩码，默认使用内部完整的 LOS 标志。常用如 `0x100000` (实体碰撞)。
- **返回**: `x, y, z` 
  - 如果**发生碰撞**：返回实际发生碰撞击中点的 `x, y, z` 坐标。
  - 如果**无遮挡（视线畅通）**：返回您传入的终点原始坐标 `ex, ey, ez`。
- **示例**: 
  ```lua
  local px, py, pz = C_Timer.TCX.ObjectPosition('player')
  local tx, ty, tz = C_Timer.TCX.ObjectPosition('target')
  -- 检查视线和实体碰撞
  local hitFlags = bit.bor(0x1, 0x10, 0x100, 0x100000)
  local cx, cy, cz = C_Timer.TCX.TraceLine(px, py, pz, tx, ty, tz, hitFlags)
  -- cx, cy, cz 为最终返回的探测点,无碰撞时返回0,0,0
  ```

### `SetHeading(facing)`
- **说明**: 瞬间改变本地玩家角色的朝向 (底层直接写入)。
- **参数**: `facing` 为目标朝向的弧度角 (0 ~ 2π)。
- **示例**: 
  ```lua
  -- 瞬间转向到指定角度
  local theta = C_Timer.TCX.ObjectRotation('player') + 1.0
  C_Timer.TCX.SetHeading(theta)
  ```

### `SetFacing(facing)` / `FaceDirection(dir, [update])`
- **说明**: 异步平滑地改变本地玩家角色的朝向。该机制通过 `OnUpdate` 帧循环实现 0.75 秒 360 度的平滑转向。如果在转向过程中重复调用，会自动将最新的角度设为目标并平滑过渡，不会造成动作卡顿。
- **参数**: `facing` 或 `dir` 为目标朝向的弧度角 (0 ~ 2π)。
- **示例**: 
  ```lua
  -- 平滑转向到指定角度
  local theta = C_Timer.TCX.ObjectRotation('player') + 1.0
  C_Timer.TCX.SetFacing(theta)
  ```

### `FaceObject(obj)`
- **说明**: 自动计算本地玩家到目标对象的角度，并平滑地让玩家转向该目标。底层同样利用了 `SetFacing` 的 0.75 秒 360 度平滑转向机制。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `boolean` (成功或失败)
- **示例**: 
  ```lua
  -- 平滑面向焦点
  C_Timer.TCX.FaceObject('focus')
  ```

### `GetPitch()`
- **说明**: 获取本地玩家当前的俯仰角 (Pitch)。
- **返回**: `number` (弧度值，通常在 -1.54 到 1.54 之间)。
- **示例**: 
  ```lua
  local pitch = C_Timer.TCX.GetPitch()
  print("当前玩家俯仰角:", pitch)
  ```

### `SetPitch(pitch)`
- **说明**: 瞬间改变本地玩家当前的俯仰角 (Pitch)。输入值会被自动限制在安全的合法范围 (-1.54 ~ 1.54) 内。
- **参数**: `pitch` (number): 目标俯仰角的弧度值。
- **返回**: `boolean` (成功或失败)
- **示例**: 
  ```lua
  -- 将俯仰角调整至水平方向
  C_Timer.TCX.SetPitch(0.0)
  ```

### `GetMapID()`
- **说明**: 获取当前玩家所在的真实地图实例 ID。
- **返回**: `number` (Map ID)
- **示例**: 
  ```lua
  local mapId = C_Timer.TCX.GetMapID()
  print("当前真实的地图实例ID是:", mapId)
  ```

---

## 5. 文件系统与安全脚本 (File System & Security)

**关于路径支持：**
所有接受 `path` 的参数均同时支持**相对路径**（相对于 `TCX-Retail.exe` 所在目录，如 `scripts/main.lua`）和**绝对路径**（如 `C:/Bot/scripts/main.lua`）。为了兼容性，请尽量使用斜杠 `/` 或双反斜杠 `\\`。

### `GetWowDirectory()`
- **说明**: 返回当前正在被注入的魔兽世界（`Wow.exe`）的游戏目录绝对路径。
- **返回**: `string` (游戏目录绝对路径)
- **示例**: 
  ```lua
  local wowDir = C_Timer.TCX.GetWowDirectory()
  print("魔兽世界安装在: " .. wowDir)
  ```

### `ReadFile(path)`
- **说明**: 读取客户端本地的文本文件。
- **参数**: `path` (string) 文件路径（支持相对或绝对路径）。
- **返回**: `data` (string) 文件内容，读取失败则返回 `false`。
- **示例**: 
  ```lua
  local data = C_Timer.TCX.ReadFile('C:/TCX/scripts/test.json')
  ```

### `WriteFile(path, data, append)`
- **说明**: 向客户端本地写入文本文件。
- **参数**:
  - `path` (string): 文件路径（支持相对或绝对路径）。
  - `data` (string): 要写入的字符串内容。
  - `append` (boolean): 是否为追加模式。如果为 `false` 则覆盖原有内容。
- **返回**: `true | false` (是否写入成功)
- **示例**: 
  ```lua
  -- 覆盖写入配置文件
  C_Timer.TCX.WriteFile("C:/TCX/config.json", '{"bot_enabled": true}', false)
  
  -- 追加写入运行日志
  C_Timer.TCX.WriteFile("C:/TCX/run.log", "Bot started at 12:00\n", true)
  ```

### `ListFiles(dir)`
- **说明**: 罗列本地目录中的所有文件。
- **参数**: `dir` (string): 目录路径（支持相对或绝对路径）。
- **返回**: `table` (包含所有文件名的 Lua 数组表)
- **示例**: 
  ```lua
  -- 获取所有的职业脚本模块
  local files = C_Timer.TCX.ListFiles("C:/TCX/scripts/classes")
  for i, filename in ipairs(files) do
      print("发现脚本模块: " .. filename)
  end
  ```

### `ListDirectories(dir)` / `ListFolders(dir)`
- **说明**: 罗列本地目录中的所有子目录。
- **参数**: `dir` (string): 目录路径（支持相对或绝对路径）。
- **返回**: `table` (包含所有子目录名的 Lua 数组表)
- **示例**: 
  ```lua
  local dirs = C_Timer.TCX.ListDirectories("scripts")
  for _, folder in ipairs(dirs) do
      print("发现文件夹: " .. folder)
  end
  ```

### `CreateDirectory(dir)` / `CreateFolder(dir)`
- **说明**: 尝试创建一个新的目录。如果父目录不存在会自动递归创建。
- **参数**: `dir` (string): 目录路径。
- **返回**: `true | false` (是否创建成功或已存在)
- **示例**: 
  ```lua
  local success = C_Timer.TCX.CreateDirectory("scripts/myfolder")
  ```

### `DirectoryExists(dir)` / `FolderExists(dir)`
- **说明**: 检查指定目录是否存在。
- **参数**: `dir` (string): 目录路径。
- **返回**: `true | false`
- **示例**: 
  ```lua
  if C_Timer.TCX.DirectoryExists("scripts/myfolder") then
      print("文件夹存在")
  end
  ```

### `FileExists(file)`
- **说明**: 检查指定文件是否存在。
- **参数**: `file` (string): 文件路径。
- **返回**: `true | false`
- **示例**: 
  ```lua
  if C_Timer.TCX.FileExists("scripts/test.lua") then
      print("文件存在")
  end
  ```

### `DeleteFile(file)`
- **说明**: 从系统磁盘中删除指定文件。
- **参数**: `file` (string): 要删除的文件路径。
- **返回**: `true | false` (是否删除成功)
- **示例**: 
  ```lua
  local success = C_Timer.TCX.DeleteFile("scripts/test.txt")
  ```

### `EncryptFile(inPath, outPath)`
- **说明**: 将明文脚本文件读取、通过内置 VMP 密钥进行混淆加密，并输出为一个不可读的安全文件（推荐后缀 `.tcx`）。通常用于开发与发布阶段。
- **参数**:
  - `inPath` (string): 源明文文件路径（支持相对或绝对路径）。
  - `outPath` (string): 目标加密文件输出路径。
- **返回**: `true | false`
- **示例**: 
  ```lua
  C_Timer.TCX.EncryptFile("C:/Dev/bot.lua", "C:/Release/bot.tcx")
  ```

### `LoadProtectedFile(path)`
- **说明**: 读取加密的脚本文件，并在**内存中安全解密执行**。解密后的明文不会落盘，并且会在安全缓冲区执行后立刻被底层 C++ 覆写销毁，防止内存 Dump 破解。
- **参数**: `path` (string): 加密文件路径（支持相对或绝对路径）。
- **返回**: `true | false` (加载并执行是否成功)
- **示例**: 
  ```lua
  -- 在正式版中加载加密包，不再使用 dofile
  C_Timer.TCX.LoadProtectedFile("C:/Release/bot.tcx")
  ```

---

## 6. 其他工具 (Utilities)

### `GetKeyState(key)`
- **说明**: 判断键盘/鼠标某个键是否正在被物理按下以及是否处于锁定/触发状态（穿透游戏，直接读 Windows API）。
- **参数**: `key` (number) 虚拟键码（如 `0x10` 表示 Shift 键，`0x14` 表示 CapsLock）。
- **返回**: `isDown, isToggled` (两个 boolean 值)
- **示例**: 
  ```lua
  -- 按下 Shift 键时暂停输出
  local isDown, isToggled = C_Timer.TCX.GetKeyState(0x10)
  if isDown then
      print("Shift 正在被物理按下")
  end
  ```

### `HttpRequest(opts)`
- **说明**: 异步发送 HTTP 请求（不阻塞主线程）。
- **参数**: `opts` (table)
  - `url` (string): 请求地址
  - `method` (string): 请求方法 ('GET', 'POST' 等)
  - `body` (string): 请求体
  - `headers` (table): 请求头字典
  - `callback` (function): 异步回调函数，接收两个参数：`(statusCode, responseBody)`。
- **示例**: 
  ```lua
  C_Timer.TCX.HttpRequest({
      url = "http://api.example.com/data",
      method = "POST",
      body = '{"foo":"bar"}',
      headers = { ["Content-Type"] = "application/json" },
      callback = function(status, body)
          if status == 200 then
              print("请求成功: ", body)
          end
      end
  })
  ```

### `YamlEncode(obj)`
- **说明**: 将 Lua 的 table、number、string 或 boolean 序列化为标准 YAML 格式字符串。
- **参数**: `obj` (任意支持的数据类型) - 要序列化的 Lua 对象（最常用的是 table）。
- **返回**: `string` (序列化后的 YAML 字符串)。
- **示例**: 
  ```lua
  local yamlStr = C_Timer.TCX.YamlEncode({ name = "TCX", version = 1.0 })
  ```

### `YamlDecode(str)`
- **说明**: 将标准的 YAML 格式字符串反序列化为 Lua table。
- **参数**: `str` (string) - YAML 格式的字符串。
- **返回**: `table` (解析后的数据字典) 或者 `nil` (解析失败)。
- **示例**: 
  ```lua
  local obj = C_Timer.TCX.YamlDecode("name: TCX\nversion: 1.0")
  print(obj.name) -- 输出 TCX
  ```

### `JsonEncode(obj)`
- **说明**: 将 Lua 的 table、number、string 或 boolean 序列化为标准 JSON 格式字符串。
- **参数**: `obj` (任意支持的数据类型) - 要序列化的 Lua 对象。
- **返回**: `string` (序列化后的 JSON 字符串)。
- **示例**: 
  ```lua
  local jsonStr = C_Timer.TCX.JsonEncode({ data = { 1, 2, 3 } })
  ```

### `JsonDecode(str)`
- **说明**: 将标准的 JSON 格式字符串反序列化为 Lua table。
- **参数**: `str` (string) - JSON 格式的字符串。
- **返回**: `table` (解析后的数据字典) 或者 `nil` (解析失败)。
- **示例**: 
  ```lua
  local obj = C_Timer.TCX.JsonDecode('{"data":[1,2,3]}')
  print(obj.data[1]) -- 输出 1
  ```

### `Unwrap(...)`
清除 WoW 11.x+ (Midnight) 中 Lua 变量底层的 "Secret" 内存保护标记，解除暴雪的保护状态封锁。
- **参数**: `...` (任意类型的变量) - 比如被暴雪打上受保护标记的 table 或值。
- **返回**: 经过底层 `clearsecret` 处理后的原变量。
- **说明**: 系统会自动无差别地抹除传入参数在 Lua 栈上的受保护 TValue 标志；如果传入的是 `table`，还会深度递归清除内部所有元素的 Secret 标记。
- **示例**: 
  ```lua
  -- 获取受保护的暴雪私有数据
  local protectedData = C_Spell.GetSpellInfo(12345) 
  -- 通过 Unwrap 强行抹除所有 Secret 内存位，解包安全使用
  local safeData = C_Timer.TCX.Unwrap(protectedData)
  print("安全读取技能名:", safeData.name)
  ```

---

## 7. 占位与未完全实现的 API (TODO)

为了兼容某些现成的脚本不报错，系统目前提供了以下空占位符，它们不会崩溃，但尚未接入真实的底层偏移：
- `ObjectCastingInfo(obj)` -> 始终返回 `nil`
- `MoveTo(x, y, z)` / `MoveToRaw(x, y, z)` -> `false`
- `CameraPosition()` -> `0, 0, 0`
- `GetPitch()` / `SetPitch()` -> `0` / `false`
- `GeneratePath()` / `GeneratePathWeighted()` -> `nil`
- `GetAreaInfo()` -> `0`
