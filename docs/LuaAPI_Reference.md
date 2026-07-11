# TCX-Retail 扩展 Lua API 开发文档
# 版本: 2.5.5
本文档整理了 `TCX-Retail` 目前在 Lua 虚拟机中注入的所有底层扩展 API。这些 API 大部分是为了兼容 Tinkr 规范而设计，并对底层内存机制进行了安全封装。

所有扩展 API 不再挂载在全局变量 `C_Timer.TCX` 下，而是需要在被加载的脚本开头接收上下文 (`local tcx = ...`)。

---

## 0. 配置文件 `config.yaml` 字段说明与注意事项

`TCX-Retail` 会在运行目录中自动查找或生成 `config.yaml`。为了兼顾国服（CN服）与外服（GL服）的掉线重连、自动登录以及物理路径的安全性，请知悉以下字段说明和配置规范。

### 字段说明

- **`auth.passkey`** (string)
  - **说明**: 您的通行证授权密钥。启动器在运行时会与验证服务器握手验证。
- **`autologin.enabled`** (boolean)
  - **说明**: 自动登录与掉线快速重连保护的全局开关。
  - **取值**: `true` (开启) / `false` (关闭)。
- **`autologin.wow_auto_start`** (boolean)
  - **说明**: 是否在启动器运行且未检测到魔兽世界进程时，自动启动魔兽客户端。
  - **取值**: `true` (自动启动) / `false` (不自动启动)。
- **`autologin.wow_path`** (string)
  - **说明**: 魔兽世界客户端的绝对物理路径。
  - **示例**: `"D:\Program Files (x86)\World of Warcraft\_retail_\Wow.exe"`
  - **提示**: **国服用户**必须通过战网启动，此项直接配置为**空双引号 `""`** 即可，且`autologin.wow_auto_start`必须为`false`。
- **`autologin.username`** (string)
  - **说明**: 游戏登录用户名。
  - **提示**: 仅外服使用，**国服用户**直接保持默认示例或留空。
- **`autologin.password`** (string)
  - **说明**: 游戏登录密码。
  - **提示**: 仅外服使用，**国服用户**直接保持默认示例或留空.
- **`autologin.account`** (string)
  - **说明**: 角色所属的游戏子账号名字（例如: `WoW1`, `WoW2`, `WoW3`）。
- **`autologin.realmname`** (string)
  - **说明**: 默认选择并登录的服务器名字（例如: `死亡之翼`）。
- **`autologin.char_slot`** (number)
  - **说明**: 默认选择的角色位置编号（从上往下数，1 代表第 1 个角色）。
- **`autologin.max_attempts`** (number)
  - **说明**: 登录中遭遇报错时最大的重试上限。重试超限后会挂起 10 分钟以防账号被锁定。
- **`processes.unlocked`** (sequence)
  - **说明**: 系统自动管理与追踪的已解锁 WoW 进程 PID 列表。请勿手动修改此项。

### 配置注意事项

1. **【敏感字符双引号保护】**：
   YAML 格式有其特殊的词法语法。如果任何配置项的值包含以下敏感特殊字符：
   `"`、`:`、`{`、`}`、`[`、`]`、`,`、`&`、`*`、`#`、`?`、`|`、`-`、`<`、`>`、`!`、`%`、`@`
   或者**包含了空格、反斜杠 `\`（例如魔兽路径）**，**请务必将该值用双引号包裹起来**。
   - *正确示范*：`password: "my#pass:word"` 或者是 `wow_path: "D:\Program Files\Wow.exe"`
   - *错误示范*：`password: my#pass:word` (会触发 YAML 解析引擎语法中断或崩溃)
2. **【原生反斜杠】**：
   在配置路径时，系统完全支持并推荐直接使用 Windows 原生的单反斜杠 `\` 进行配置展示（如 `"D:\Wow\Wow.exe"`），程序在加载时会自动对其进行安全性与转义防护。

---

## 1. 核心系统执行 (System Execution)

### `Unlock(fnName, ...)`
- **说明**: 突破硬件保护，执行被保护（Protected）的原生 WoW API 而不会触发 Taint（污染）。
  **【自动解密特性】**：此方法在执行底层 API 时，会**自动清理所有返回值的 `secret` 加密标志位**。对于那些原生环境会返回加密值（Secret Value）的函数（例如某些坐标获取、底层状态函数等），你**必须**通过此函数进行调用，才能获取到解密后的真实可用数据。
  **【使用场景】**：此函数**仅在从游戏插件（AddOn）目录加载的脚本中才需要使用**（因为插件目录环境存在权限污染）。如果你是通过 `LoadProtectedFile`、`LoadProtectedBuffer` 加载的脚本，或者是直接放在 `scripts/` 目录下的自动加载脚本，它们本身就处于无污染的最高执行权限上下文中，可以直接安全调用受保护的函数，且所有 WOW API 的返回值天然没有秘密值（Secret Value）标记，因此无需使用此函数。
  > **性能提示**: `Unlock` 内部涉及环境切换 and 拦截，开销相对较高。如果该原生 API **没有被暴雪设为受保护（Protected）**，仅仅是因为返回了 Secret 加密值，**强烈建议直接调用原生函数然后用 `Unwrap` 进行解密**以提高执行性能。
- **参数**: 
  - `fnName` (string): 全局函数的名称（如 `"CastSpellByName"`）。
  - `...`: 传递给该函数的参数。
- **返回**: 原生函数执行后的所有解密返回值。
- **示例**: 
  ```lua
  local tcx = ...
  tcx.Unlock("CastSpellByName", "回春术")
  ```

### `RunScript(scriptStr)`
- **说明**: 直接使用底层执行缓冲区运行任意宏/脚本字符串，完美绕过原生环境的降级限制。全局的 `RunScript` 也会被重写为此方法。
  **【使用场景】**：与 `Unlock` 类似，本函数**仅在从游戏插件目录加载的脚本中才需要使用**。通过 `LoadProtectedFile` / `LoadProtectedBuffer` 或 `scripts/` 目录加载的代码已天然处于最高执行权限，无需通过 `RunScript` 绕过环境限制。
- **参数**: 
  - `scriptStr` (string): Lua 代码字符串。
- **示例**: 
  ```lua
  local tcx = ...
  tcx.RunScript("print('Hello from TCX!')")
  ```

### `IsInGame()`
- **说明**: 检查当前玩家是否已完全加载进游戏世界并且未处于蓝条/过图加载画面中。此方法通过底层 `LoadingScreenPtr` 偏移进行高精度判定，用于防止在场景切换时发生 API 竞争或崩溃。
- **返回**: `boolean` (是否完全进入游戏)
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.IsInGame() then
      print("玩家已完全加载进世界中，可以安全执行脚本")
  end
  ```

### `GetCurrentEventInfo()`
- **说明**: 突破原版 `COMBAT_LOG_EVENT` 的保护限制，直接从引擎底层读取并解析最新一条战斗日志（Combat Log）的详细数据。该方法完美平替了原生的 `CombatLogGetCurrentEventInfo` 和受保护的 `C_CombatLogSecure.GetCurrentEventInfo`，全程通过内存直读实现，不会触发任何安全拦截。建议在监听 `COMBAT_LOG_EVENT_UNFILTERED` 事件时配合调用。
- **返回**: 与原生战斗日志 API 完全一致的多个返回值（包含时间戳、事件类型、源/目标 GUID 及标志位、法术细节等）。
- **示例**: 
  ```lua
  local frame = CreateFrame("Frame")
  frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
  frame:SetScript("OnEvent", function(self, event, ...)
    local tcx = ...
    local timestamp, subevent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount = tcx.GetCurrentEventInfo()
    if subevent == "SPELL_DAMAGE" or subevent == "SPELL_PERIODIC_DAMAGE" or subevent == "RANGE_DAMAGE" then
      print(sourceName .. " 使用 " .. (spellName or "未知法术") .. " (" .. subevent .. ") 对 " .. (destName or "未知目标") .. " 造成了 " .. tostring(amount) .. " 点伤害!")
    end
  end)
  ```

### `GetHwid()`
- **说明**: 获取当前设备的全局唯一硬件 ID (HWID)。此 ID 基于当前计算机的 CPU 指纹与 MAC 地址进行 SHA256 哈希计算，截取前 16 位生成。该值与当前计算机硬件绑定。
- **返回**: `string` (当前设备的 HWID)
- **示例**: 
  ```lua
  local tcx = ...
  local hwid = tcx.GetHwid()
  print("当前设备的硬件ID是: " .. hwid)
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
3. **底层对象指针句柄** (userdata)：通过调用 `tcx.Objects()` 遍历返回的内存引用或`tcx.Object()` 返回的内存引用.

### `Object(val)`
- **说明**: 根据传入的标志或 GUID，获取对象引用句柄。
- **参数**: `val` (string): 可以是 Token (如 `"target"`, `"player"`) 或者是 GUID (如 `"Player-970-00108A83"`)。
- **返回**: `object` (对象底层句柄，获取失败返回 nil)
- **示例**: 
  ```lua
  local tcx = ...
  local myTarget = tcx.Object("target")
  if myTarget then
      print("目标存在:", tcx.ObjectName(myTarget))
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
  local tcx = ...
  -- 获取周围所有的单位(Unit)
  local units = tcx.Objects(5)
  for i, obj in ipairs(units) do
      print(tcx.ObjectName(obj))
  end
  ```

### `ObjectPosition(obj)`
- **说明**: 获取对象的 3D 坐标。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `x, y, z` (numbers)
- **示例**: 
  ```lua
  local tcx = ...
  local px, py, pz = tcx.ObjectPosition('player')
  print("玩家坐标:", px, py, pz)
  ```

### `ObjectName(obj)`
- **说明**: 获取对象的名称。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `string`
- **示例**: 
  ```lua
  local tcx = ...
  local name = tcx.ObjectName('target')
  print("目标的名字是:", name)
  ```

### `ObjectHealth(obj)` / `ObjectMaxHealth(obj)`
- **说明**: 获取目标当前的生命值 / 最大生命值。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local hp = tcx.ObjectHealth('target')
  local maxHp = tcx.ObjectMaxHealth('target')
  print("目标血量比例: " .. (hp / maxHp * 100) .. "%")
  ```

### `ObjectPower(obj)` / `ObjectMaxPower(obj)`
- **说明**: 获取目标当前的能量值 / 最大能量值（如法力、怒气、能量等）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local power = tcx.ObjectPower('player')
  local maxPower = tcx.ObjectMaxPower('player')
  print("玩家当前主资源比例: " .. (power / maxPower * 100) .. "%")
  ```

### `ObjectPower2(obj)` / `ObjectMaxPower2(obj)`
- **说明**: 获取目标当前的副能量值 / 最大副能量值（如死亡骑士的符文、德鲁伊的连击点等）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local power2 = tcx.ObjectPower2('player')
  print("玩家当前副资源: ", power2)
  ```

### `ObjectDisplayId(obj)`
- **说明**: 获取目标的外观 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local displayId = tcx.ObjectDisplayId('target')
  print("当前目标外观ID: ", displayId)
  ```

### `ObjectCreatureId(obj)`
- **说明**: 获取目标的生物 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local creatureId = tcx.ObjectCreatureId('target')
  print("当前目标生物ID: ", creatureId)
  ```

### `ObjectId(obj)`
- **说明**: 获取目标的底层实体 ID (Entry ID)。对于 NPC 或怪物，它代表 `CreatureID`（如 12345）；对于物品或游戏对象，代表 `ItemID` 或 `GameObject ID`。底层通过直接读取 `Descriptor_EntryID` 偏移获取，具有极高精度。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (Entry ID)
- **示例**: 
  ```lua
  local tcx = ...
  local entryId = tcx.ObjectId('target')
  print("当前目标的实体 ID: ", entryId)
  ```

### `GameObjectType(obj)`
- **说明**: 获取 GameObject 的特定底层类型。
- **参数**: `obj` (多态): 目标对象。必须是 GameObject 类型的对象。
- **返回**: `number` (GameObject 类型 ID。例如: 19 代表邮箱，7 代表椅子，50 代表采集节点/矿草)
- **示例**: 
  ```lua
  local tcx = ...
  local goType = tcx.GameObjectType('mouseover')
  if goType == 50 then
      print("目标是一个草药或矿石 (采集节点)!")
  elseif goType == 19 then
      print("目标是邮箱!")
  end
  ```

### `ObjectMountDisplayId(obj)`
- **说明**: 获取目标坐骑的外观 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local mountId = tcx.ObjectMountDisplayId('target')
  if mountId > 0 then print("目标正骑在坐骑上, 外观ID: ", mountId) end
  ```

### `ObjectRace(obj)`
- **说明**: 获取目标的种族 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local raceId = tcx.ObjectRace('player')
  print("玩家种族ID: ", raceId)
  ```

### `ObjectClass(obj)`
- **说明**: 获取目标的职业 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local classId = tcx.ObjectClass('player')
  if classId == 1 then print("玩家是战士") end
  ```

### `ObjectGender(obj)`
- **说明**: 获取目标的性别 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local genderId = tcx.ObjectGender('player')
  print("玩家性别ID: ", genderId)
  ```

### `ObjectCreatureType(obj)`
- **说明**: 获取目标的生物类型（如野兽、恶魔等）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local creatureType = tcx.ObjectCreatureType('target')
  print("目标生物类型ID: ", creatureType)
  ```

### `ObjectPowerType(obj)`
- **说明**: 获取目标的能量类型（如法力、怒气等）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local powerType = tcx.ObjectPowerType('player')
  print("玩家主能量类型ID: ", powerType)
  ```

### `ObjectLevel(obj)`
- **说明**: 获取目标的等级。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local level = tcx.ObjectLevel('target')
  print("目标等级: ", level)
  ```

### `ObjectFactionTemplate(obj)`
- **说明**: 获取目标的阵营模板 ID。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local faction = tcx.ObjectFactionTemplate('target')
  print("目标阵营模板: ", faction)
  ```

### `ObjectDynamicFlags(obj)`
- **说明**: 获取目标的动态状态掩码 (DynamicFlags)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local dynamicFlags = tcx.ObjectDynamicFlags('target')
  print("动态Flags: ", dynamicFlags)
  ```

### `ObjectAuraState(obj)`
- **说明**: 获取目标底层光环状态掩码 (AuraState)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local auraState = tcx.ObjectAuraState('target')
  print("光环State: ", auraState)
  ```

### `ObjectNpcFlags(obj)`
- **说明**: 获取目标底层的 NPC 交互标志位 (NpcFlags)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local npcFlags = tcx.ObjectNpcFlags('target')
  -- 检查是否可以对话/任务
  if bit.band(npcFlags, 0x01) ~= 0 then print("可对话NPC") end
  ```

### `ObjectUnitFlags(obj)`
- **说明**: 获取目标底层的单位标志位 (UnitFlags)。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local unitFlags = tcx.ObjectUnitFlags('target')
  -- 检查目标是否不可攻击
  if bit.band(unitFlags, 0x02) ~= 0 then print("目标不可攻击") end
  ```

### `ObjectSpeed(obj)`
- **说明**: 获取目标的当前奔跑速度。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数)
- **示例**: 
  ```lua
  local tcx = ...
  local speed = tcx.ObjectSpeed('player')
  print("当前移动速度: ", speed)
  ```

### `ObjectIsInCombat(obj)`
- **说明**: 快捷判断单位是否处于战斗中。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean`
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.ObjectIsInCombat('player') then
      print("玩家正在战斗中！")
  end
  ```

### `ObjectIsMounted(obj)`
- **说明**: 快捷判断单位是否在坐骑上。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean`
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.ObjectIsMounted('player') then
      print("玩家正在骑乘状态")
  end
  ```

### `ObjectHasPaladinAura(obj)`
- **说明**: 快捷判断单位是否拥有圣骑士光环。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean`
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.ObjectHasPaladinAura('player') then
      print("玩家受到圣骑士光环影响")
  end
  ```

### `ObjectTargetGuid(obj)`
- **说明**: 获取目标当前正在锁定的目标 GUID 字符串（如敌对怪物锁定的第一仇恨）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `string` (GUID) 或者 `nil`。
- **示例**: 
  ```lua
  local tcx = ...
  local targetOfTarget = tcx.ObjectTargetGuid('target')
  if targetOfTarget then print("目标的目标是: ", targetOfTarget) end
  ```

### `ObjectType(obj)`
- **说明**: 获取目标的类型 ID（参考 `Objects` 参数）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number`
- **示例**: 
  ```lua
  local tcx = ...
  local typeId = tcx.ObjectType('target')
  if typeId == 5 then
      print("目标是一个 NPC 或怪物")
  end
  ```

### `ObjectGUID(obj)`
- **说明**: 获取目标对象的 GUID 字符串（与原生 `UnitGUID()` 格式完全一致）。
- **参数**: `obj` (多态): 目标对象 (Token / 指针句柄)。
- **返回**: `string`
- **示例**: 
  ```lua
  local tcx = ...
  local guid = tcx.ObjectGUID('player')
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
  local tcx = ...
  -- 用法: 遍历对象管理器中的单位，自动获取可用 Token
  local units = tcx.Objects(5)
  for _, obj in ipairs(units) do
      local token = tcx.ObjectToken(obj)
      -- token 保证非 nil（最差情况返回 "mouseover" 并自动设置 Mouseover）
      -- 可直接传给原生暴雪 API，无需手动 SetMouseover/清理
      local hp = UnitHealth(token)
      print(tcx.ObjectName(obj), "HP:", hp, "Token:", token)
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
  local tcx = ...
  local dist = tcx.ObjectDistance('player', 'target')
  print("距离目标:", dist, "码")
  ```

### `ObjectCreator(obj)`
- **说明**: 获取该对象的创建者对象引用（常用于判断图腾/宠物归属）。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `object` (与 Objects() 遍历出来的底层对象句柄相同)
- **示例**: 
  ```lua
  local tcx = ...
  local creatorObj = tcx.ObjectCreator('pet')
  if creatorObj and tcx.ObjectGUID(creatorObj) == tcx.ObjectGUID('player') then
      print("这是我的宠物")
  end
  ```

### `ObjectRotation(obj)`
- **说明**: 获取目标对象的朝向角（弧度，`[0, 2π)`）。同时支持 **Unit/Player** 和 **GameObject**（包括船、飞艇等 Transport）：
  - **Unit/Player**: 读取 `MovementData` 中的朝向字段。当单位位于交通工具上时返回的是**相对于交通工具的局部朝向**，需要叠加交通工具的世界朝向才能得到世界朝向（参见 `ObjectTransport`）。
  - **GameObject**: 从对象的世界变换矩阵反算 yaw，对于船等动态 Transport 同样有效，**返回的始终是世界朝向**。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `number` (弧度)，无效或不支持的对象类型返回 `nil`。
- **示例**:
  ```lua
  local tcx = ...
  local facing = tcx.ObjectRotation('target')
  if facing then
      print(("目标朝向: %.3f 弧度 (%.1f°)"):format(facing, math.deg(facing)))
  end
  ```

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
  local tcx = ...
  -- 判断鱼漂是否处于动画跳动(咬钩)状态
  local _, animationFlags = tcx.ObjectFlags(bobberObj)
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
  local tcx = ...
  local targetObj = tcx.ObjectCastingTarget("player")
  if targetObj then
      local name = tcx.ObjectName(targetObj)
      print("你当前的底层交互目标是: " .. (name or "未知"))
  end
  ```

### `ObjectBoundingRadius(obj)`
- **说明**: 获取对象的物理边界半径（Bounding Radius）。决定角色或怪物实际占地面积和被 AOE 命中的物理体积大小。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数) 表示碰撞体积半径；无效返回 `false`。
- **示例**: 
  ```lua
  local tcx = ...
  local radius = tcx.ObjectBoundingRadius("player")
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
  local tcx = ...
  local reach = tcx.ObjectCombatReach("target")
  if reach then
      print("当前目标的战斗范围 (CombatReach) 为:", reach)
  end
  ```

### `ObjectMovementFlag(obj)`
- **说明**: 获取对象的当前移动状态标志位。
- **参数**: `obj` (多态): 目标对象.
- **返回**: `number` (uint32) 对应底层的 MovementFlags 位掩码；若无效返回 `0`。
- **示例**:
  ```lua
  local tcx = ...
  local flags = tcx.ObjectMovementFlag("player")
  -- 根据实际标志位进行与操作，例如 0x01 可能表示正在向前移动
  if bit.band(flags, 0x01) ~= 0 then
      print("玩家当前正在移动")
  end
  ```

### `ObjectTransport(obj)`
- **说明**: 获取目标单位当前所站立的交通工具（船、飞艇、电梯等 Transport GameObject）对象引用。当单位踏上交通工具后，其 `ObjectPosition` / `ObjectRotation` 返回的将是**相对于该交通工具的局部坐标与局部朝向**（底层不再自动叠加），需要通过本接口获取交通工具自身的世界坐标和朝向后，在 Lua 层自行做一次旋转 + 平移变换以还原世界坐标。
- **参数**: `obj` (多态): 目标单位 (Token / GUID 字符串 / 指针句柄)，通常传 `'player'`。
- **返回**: 成功返回 `lightuserdata` (交通工具的底层对象指针，可继续作为 `obj` 参数传入其他 API)；如果该单位当前不在交通工具上，或交通工具未在对象管理器中可见，则返回 `nil`。
- **示例**:
  ```lua
  local tcx = ...
  -- 还原玩家在船上的世界坐标与世界朝向
  local function worldPosOf(obj)
      local x, y, z = tcx.ObjectPosition(obj)
      local t = tcx.ObjectTransport(obj)
      if t then
          local tx, ty, tz = tcx.ObjectPosition(t)
          local yaw = tcx.ObjectRotation(t)
          local c, s = math.cos(yaw), math.sin(yaw)
          -- 局部 (x,y) 绕 Z 轴按船的世界 yaw 旋转，再叠加船的世界平移
          return tx + (x * c - y * s),
                 ty + (x * s + y * c),
                 tz + z
      end
      return x, y, z
  end

  local function worldFacingOf(obj)
      local f = tcx.ObjectRotation(obj)
      local t = tcx.ObjectTransport(obj)
      if t then
          f = (f + tcx.ObjectRotation(t)) % (2 * math.pi)
      end
      return f
  end

  local wx, wy, wz = worldPosOf('player')
  print(("玩家世界坐标: %.2f, %.2f, %.2f  朝向: %.3f"):format(wx, wy, wz, worldFacingOf('player')))
  ```

### `ObjectAuras(obj)`
- **说明**: 获取目标身上所有的动态光环（Buff/Debuff）列表。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `table` (包含光环信息的 Lua 数组表，每项包含 `spellId`, `flags`, `duration`, `endTime`, `stackCount`, `casterGuid` 字段)。
- **示例**: 
  ```lua
  local tcx = ...
  local auras = tcx.ObjectAuras('target')
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
  local tcx = ...
  if tcx.ObjectHasAura('player', 774) then
      print("玩家身上有回春术")
  end
  ```

### `ObjectIsOutdoors(obj)`
- **说明**: 判断目标对象是否处于室外。通过向上方发射高精度的物理碰撞射线检测是否有屋顶或遮挡（World 或 WMO）。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean` (是否在室外)
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.ObjectIsOutdoors("player") then
      print("玩家处于室外，可以骑乘飞行坐骑！")
  end
  ```

### `ObjectIsSubmerged(obj)`
- **说明**: 判断目标对象是否浸泡在水中（被水面淹没）。对于单位对象直接使用底层引擎判定；对于游戏对象（如水下草药/矿脉），通过发射向下射线高精度检测水面碰撞。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean` (是否在水中)
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.ObjectIsSubmerged("target") then
      print("目标在水下，请注意呼吸条！")
  end
  ```

### `ObjectLootable(obj)`
- **说明**: 判断目标对象是否可被拾取。针对12.0.5更新，通过直接读取 Descriptor 的 DynamicFlags 高精度判定单位尸体是否有“发光/闪光”掉落物；对于游戏对象则判定其是否包含战利品。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `boolean` (是否可拾取)
- **示例**: 
  ```lua
  local tcx = ...
  if UnitIsDead("target") and tcx.ObjectLootable("target") then
      print("发现闪光的尸体，快去摸尸！")
  end
  ```

### `ObjectHeight(obj)`
- **说明**: 获取目标对象的实际物理 Z 轴模型高度（融合了 BaseHeight 和动态 Scale 缩放比例）。常用于计算挂载姓名板的实际 3D 坐标，或在复杂地形进行精准视线与技能覆盖检测。
- **参数**: `obj` (多态): 目标对象。
- **返回**: `number` (浮点数，模型高度)
- **示例**: 
  ```lua
  local tcx = ...
  local height = tcx.ObjectHeight("target")
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
  local tcx = ...
  -- 拾取尸体或对话
  if UnitIsDeadOrGhost('target') then
      tcx.RightClickObject('target')
  end
  ```

### `LeftClickObject(obj)`
- **说明**: 模拟鼠标左键点击对象。通常用于将对象设置为当前目标。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `boolean` (是否执行成功)
- **示例**: 
  ```lua
  local tcx = ...
  -- 选中鼠标悬停的单位
  tcx.LeftClickObject('mouseover')
  ```

### `SetTargetObject(obj, [mode])`
- **说明**: 强制将本地玩家的目标设置为该对象。
- **参数**: 
  - `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
  - `mode` (number, 默认为 1): 交互模式 (如 5=软目标)。
- **示例**: 
  ```lua
  local tcx = ...
  -- 将焦点目标设置为当前目标
  tcx.SetTargetObject('focus')
  ```

### `SetMouseover(obj)`
- **说明**: 临时将一个对象设置为本地玩家的悬停目标（Mouseover），而不会触发屏幕高光或 UI 闪烁。这是一种高级内存劫持技巧，常用于对**没有原生 Token 的任意内存实体**执行底层 API 查询。传入 `nil` 可清空该状态。
- **参数**: `obj` (多态 | nil): 目标对象 (Token / GUID 字符串 / 指针句柄)，或者 `nil` 来清空伪装状态。
- **示例**: 
  ```lua
  local tcx = ...
  -- 遍历周围所有的单位(Unit, 枚举值为 5)
  local units = tcx.Objects(5)
  for _, obj in ipairs(units) do
      if tcx.ObjectName(obj) == "德纳修斯大帝" then
          -- 找到特定 Boss 后，将其临时劫持为 mouseover
          -- 这样即使你没有选中它，也能对其使用 WoW 原生 API
          tcx.SetMouseover(obj)
          
          -- 完美利用原生 API 获取其复杂属性（无需重新造轮子）
          local hp = UnitHealth("mouseover")
          local name, text, texture, startTime, endTime, isTradeSkill, castID, notInterruptible = UnitCastingInfo("mouseover")
          
          if name and notInterruptible then
              print("警告：" .. name .. " 是不可打断的技能！")
          end
          
          -- 用完后立刻清理内存槽位，不留痕迹
          tcx.SetMouseover(nil)
          break
      end
  end
  ```

### `ClickPosition(x, y, z)`
- **说明**: 面向地面的范围技能（如暴风雪、烈焰风暴）点击释放。在法术处于“鼠标瞄准”状态时，调用此函数将在指定坐标立刻施法。
- **返回**: `boolean` (成功或失败)
- **示例**: 
  ```lua
  local tcx = ...
  -- 对目标脚下释放地毯技能 (需先 CastSpellByName("暴风雪"))
  local tx, ty, tz = tcx.ObjectPosition('target')
  tcx.ClickPosition(tx, ty, tz)
  ```

---

## 4. 移动与空间感知 (Movement & Vision)

### `MoveTo(x, y, z)`
- **说明**: 控制玩家角色自动向指定的世界 3D 坐标移动。该函数会自动计算角色与目标点之间的角度并调整朝向。当角色面朝目标的角度差小于或等于 50 度时，将自动开始前进；如果在移动途中角度偏差过大，将暂停前进并重新修正朝向。当与目标的直线距离小于 1.5 码时，将自动停止移动。在已有移动目标的情况下重复调用，会立即放弃旧目标并重新计算新目标的朝向和移动。如果传入的坐标参数非数字，将返回 `false`。
- **参数**:
  - `x, y, z` (numbers): 目标的 3D 世界坐标。
- **返回**: `boolean` (是否成功设置移动目标)
- **示例**: 
  ```lua
  local tcx = ...
  local tx, ty, tz = tcx.ObjectPosition('target')
  if tx then
      tcx.MoveTo(tx, ty, tz)
  end
  ```

### `StopMoveTo()`
- **说明**: 立即停止由 `MoveTo` 发起的自动移动，并清除当前正在前往的目标信息。
- **返回**: `boolean` (如果成功中断了正在进行的移动返回 `true`，如果没有移动任务则返回 `false`)
- **示例**: 
  ```lua
  local tcx = ...
  -- 在施法或受到控制时打断寻路
  tcx.StopMoveTo()
  ```

### `ClickToMove(x, y, z)`
- **说明**: 直接调用游戏引擎底层的点击移动（Click To Move, CTM）功能。
- **参数**:
  - `x, y, z` (numbers): 目标位置的 3D 世界坐标。
- **返回**: `boolean` (是否成功调用底层点击移动函数)
- **示例**: 
  ```lua
  local tcx = ...
  -- 获取当前目标的坐标并使用引擎原生点击移动前往
  local tx, ty, tz = tcx.ObjectPosition('target')
  if tx and ty and tz then
      tcx.ClickToMove(tx, ty, tz)
  end
  ```

### `ClickToMoveStop()`
- **说明**: 立即中断由 `ClickToMove` 触发的原生引擎点击移动。
- **返回**: `boolean` (是否成功下发急刹车指令)
- **示例**: 
  ```lua
  local tcx = ...
  -- 在开始读条施法、或者需要立即规避地板技能时紧急刹车
  tcx.ClickToMoveStop()
  ```

### `GeneratePath(...)`
- **说明**: 发起异步寻路请求。该接口通过后台工作线程异步向寻路服务器发送请求，避免阻塞游戏主线程。支持多态重载参数，可以通过配置 Table (推荐) 或位置参数传入寻路选项。**注意：该接口不支持跨地图生成路径，起点和终点的地图 ID 必须相同。**
- **现代配置 Table 模式 (推荐)**:
  `tcx.GeneratePath(options)`
  - **`options` 字段说明**:
    - `end` (table, 必填): 终点世界坐标，格式为 `{ x = num, y = num, z = num }`。
    - `callback` (function, 必填): 寻路完成后的回调函数，格式为 `function(success, path, code, message)`。
      - `success` (boolean): 寻路是否成功（当 `code <= 1` 时为 `true`）。
      - `path` (table): 成功时返回的路径点数组，格式为 `{{x = num, y = num, z = num}, ...}`。
      - `code` (number): 错误码。
      - `message` (string): 错误说明。
    - `mapId` (number, 可选): 地图 ID。若省略，自动补齐为当前玩家所在的地图 ID。
    - `start` (table, 可选): 起点世界坐标，格式为 `{ x = num, y = num, z = num }`。若省略，自动补齐为当前玩家所在坐标。
    - `moveType` (string, 可选): 移动模式，默认 `"all"`。可选值：
      - `"walk"`: 仅陆地行走（不跨水，不考虑游泳或飞行）。
      - `"swim"`: 涉水游泳寻路。
      - `"fly"`: 三维立体飞行寻路。
      - `"all"`: 融合所有移动能力，自动切换。
    - `flyHeight` (number, 可选): 飞行高度（单位：码）。仅在 `"fly"` 模式下生效，使生成的路径点向上偏移此高度以避免贴地撞墙，默认 `30.0`。
    - `straightPath` (boolean, 可选): 是否强制生成直线路径（三维空间射线直连避障），默认 `false`。若为 `true`，寻路器会尝试直接以直线连通起点和终点，通常在短距离且无障碍物的直视可见移动中使用。
    - `simplifyEpsilon` (number, 可选): 路径平滑与节点简化参数。大于 0 时生效，基于 Ramer-Douglas-Peucker 算法简化多余折线节点。值越大，路径越稀疏、平滑，生成的路径节点越少，可有效优化 CTM 频繁切换转向的抖动，默认 `0.0`（保留原始路径点，推荐设置为 `0.5`）。
    - `clearance` (number, 可选): 碰撞体积/避障安全厚度（单位：码），默认 `0.0`。用于使生成的路径与墙壁、树木或静态障碍物的边界保持安全距离。在狭窄地形或室内容易贴墙卡住的场景中，建议将其设置为 `2.0` 码左右以远离障碍物边界。
- **位置参数重载模式**:
  - **语法 A** (终点极简版，自动补齐起点和地图)：
    `tcx.GeneratePath(endX, endY, endZ, callback)`
  - **语法 B** (完整自定义参数版)：
    `tcx.GeneratePath(mapId, startX, startY, startZ, endX, endY, endZ, callback, [moveType, flyHeight, straightPath, simplifyEpsilon, clearance])`
- **示例**:
  ```lua
  local tcx = ...
  -- 推荐的配置 Table 模式，使用平滑和避障参数
  tcx.GeneratePath({
      ["end"] = { x = -8779.94, y = 834.54, z = 94.64 },
      simplifyEpsilon = 0.5,
      clearance = 2.0,
      callback = function(success, path, code, msg)
          if success then
              print("寻路成功，共生成节点数：" .. #path)
              for i, node in ipairs(path) do
                  print(string.format("节点 %d: %.2f, %.2f, %.2f", i, node.x, node.y, node.z))
              end
          else
              print("寻路失败，错误码：" .. tostring(code) .. "，原因：" .. tostring(msg))
          end
      end
  })
  ```

### `CameraPosition()`
- **说明**: 获取当前魔兽世界游戏内摄像机（Camera）的实时 3D 绝对世界坐标。常用于实现极其精准的射线检测（Raycast）和真实的视野遮挡判定（例如从真实摄像机位置向屏幕光标发射 `TraceLine`）。
- **返回**: `x, y, z` (numbers)
- **示例**:
  ```lua
  local tcx = ...
  local cx, cy, cz = tcx.CameraPosition()
  print(string.format("摄像机全局坐标: %.2f, %.2f, %.2f", cx, cy, cz))
  ```

### `GetCorpsePosition()`
- **说明**: 获取玩家死亡后尸体的全局世界坐标。如果找不到尸体（例如存活状态或跨服等特殊环境异常），将返回 false。
- **返回**: `x, y, z` (numbers) 或 `false`
- **示例**: 
  ```lua
  local tcx = ...
  if UnitIsDeadOrGhost('player') then
      local cx, cy, cz = tcx.GetCorpsePosition()
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
  - `flags` (number, 可选): 碰撞标志位掩码，默认使用内部完整的 LOS 标志。常用标志位如下（可用 `bit.bor` 组合）：
    - `0x1` : M2Collision (M2 模型碰撞)
    - `0x2` : M2Render (M2 渲染层)
    - `0x10` : WMOCollision (WMO 建筑碰撞)
    - `0x20` : WMORender (WMO 渲染层)
    - `0x100` : Terrain (地形地面)
    - `0x10000` : WaterWalkableLiquid (可水上行走的液体表面)
    - `0x20000` : Liquid (所有水面/液体)
    - `0x100000` : EntityCollision (实体防碰撞体积)
    - `0x200000` : Unknown
- **返回**: `x, y, z` 
  - 如果**发生碰撞**：返回实际发生碰撞击中点的 `x, y, z` 坐标。
  - 如果**无遮挡（视线畅通）**：返回您传入的终点原始坐标 `ex, ey, ez`。
- **示例**: 
  ```lua
  local tcx = ...
  local px, py, pz = tcx.ObjectPosition('player')
  local tx, ty, tz = tcx.ObjectPosition('target')
  -- 检查视线和实体碰撞
  local hitFlags = bit.bor(0x1, 0x10, 0x100, 0x100000)
  local cx, cy, cz = tcx.TraceLine(px, py, pz, tx, ty, tz, hitFlags)
  -- cx, cy, cz 为最终返回的探测点，无碰撞时返回0,0,0
  ```

### `WorldToScreen(x, y, z)`
- **说明**: 将 3D 世界坐标投影到 2D 屏幕 NDC 坐标。直接读取魔兽引擎原生摄像机矩阵计算，精准无形变。
- **参数**: `x, y, z` (numbers) 3D 世界坐标。
- **返回**: `ndcX, ndcY` (numbers) 或 `nil` (如果在视野外)。
  - `ndcX` 和 `ndcY` 返回的是标准化设备坐标 (NDC)。
  - `(0, 0)` 代表屏幕正中心。
  - `(-1, -1)` 代表屏幕的**左上角**，`(1, 1)` 代表屏幕的**右下角**。
- **示例**: 
  ```lua
  local tcx = ...
  local tx, ty, tz = tcx.ObjectPosition('target')
  local sx, sy = tcx.WorldToScreen(tx, ty, tz)
  if sx then
      print("目标在屏幕上的 NDC 坐标:", sx, sy)
  end
  ```

### `ScreenToWorld(ndcX, ndcY, [hitFlags])`
- **说明**: 将屏幕 2D NDC 坐标转换为世界 3D 坐标。该方法会从摄像机位置向屏幕坐标方向发射一条射线，并返回射线与物理环境的交点。
- **参数**: 
  - `ndcX, ndcY` (numbers): 屏幕 NDC 坐标（-1 到 1）。
  - `hitFlags` (number, 可选): 碰撞标志位掩码，默认值为 0（标准视线检测）。常用标志位参考（可用 `bit.bor` 组合）：
    - `0x1` : M2Collision (M2 模型碰撞)
    - `0x2` : M2Render (M2 渲染层)
    - `0x10` : WMOCollision (WMO 建筑碰撞)
    - `0x20` : WMORender (WMO 渲染层)
    - `0x100` : Terrain (地形地面)
    - `0x10000` : WaterWalkableLiquid (可水上行走的液体表面)
    - `0x20000` : Liquid (所有水面/液体)
    - `0x100000` : EntityCollision (实体防碰撞体积)
    - `0x200000` : Unknown
- **返回**: 成功击中则返回物理交点的 `x, y, z` 坐标；无碰撞或天空则返回 `nil`。
- **示例**: 
  ```lua
  local tcx = ...
  -- 探测屏幕正中心的世界坐标
  local sx, sy = 0, 0
  local hitFlags = bit.bor(0x1, 0x10, 0x100, 0x100000)
  local x, y, z = tcx.ScreenToWorld(sx, sy, hitFlags)
  if x then
      print("屏幕中心指向的世界坐标:", x, y, z)
  end
  ```

### `DrawLine(x1, y1, z1, x2, y2, z2, [r, g, b, a, thickness])`
- **说明**: 绘制 3D 线条的工具函数。在当前帧画一条发光的线段。**该函数必须在 `OnUpdate` 循环中每帧调用**。
- **参数**:
  - `x1, y1, z1`: 线段起点世界坐标。
  - `x2, y2, z2`: 线段终点世界坐标。
  - `r, g, b, a` (可选): RGB 颜色及透明度 (0.0~1.0)，默认全白。
  - `thickness` (可选): 线条粗细（像素），默认是 2。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
      local px, py, pz = tcx.ObjectPosition("player")
      local tx, ty, tz = tcx.ObjectPosition("target")
      if px and tx then
          -- 在玩家和目标之间画一条红线
          tcx.DrawLine(px, py, pz, tx, ty, tz, 1, 0, 0, 1, 3)
      end
  end)
  ```

### `DrawCircle(x, y, z, radius, [r, g, b, a, thickness, fill])`
- **说明**: 在 3D 地面上绘制一个原生圆圈，完美适配地形。常用于绘制技能范围预警或 AOE 范围。**该函数必须在用户的 `OnUpdate` 循环中每帧调用刷新位置**。
- **参数**:
  - `x, y, z`: 圆心世界坐标。
  - `radius`: 圆的半径 (码)。
  - `r, g, b, a` (可选): RGB 颜色及透明度 (0.0~1.0)，默认全白。
  - `thickness` (可选): 线条粗细（像素），默认是 2。
  - `fill` (boolean, 可选): 是否开启实体填充模式。如果为 `true`，会在内部利用网格扭曲技术渲染出一个贴合地面的半透明圆形面；默认不开启（仅画线框）。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
      local x, y, z = tcx.ObjectPosition("target")
      if x then
          -- 在目标脚下画一个半径 8 码的绿色圆圈
          tcx.DrawCircle(x, y, z, 8, 0, 1, 0, 1, 2)
      end
  end)
  ```

### `DrawPolygon(points, [r, g, b, a, thickness, fill])`
- **说明**: 绘制任意 3D 多边形。函数会自动将数组最后一个点和第一个点相连以闭合多边形。**此函数必须在 `OnUpdate` 循环中每帧调用**。
- **参数**:
  - `points` (table): 一个包含多个世界坐标点的数组表，格式为 `{{x, y, z}, {x, y, z}, ...}`。
  - `r, g, b, a` (可选): RGB 颜色及透明度，默认全白。
  - `thickness` (可选): 线条粗细。
  - `fill` (boolean, 可选): 是否开启实体填充模式。内部会将多边形按顶点自动拆分为多个三角形进行光栅化渲染，构成半透明底面。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
      local x, y, z = tcx.ObjectPosition("target")
      if x then
          -- 在目标脚下画一个 10x10 的多边形闭合路径
          local points = { {x+5, y+5, z}, {x-5, y+5, z}, {x-5, y-5, z}, {x+5, y-5, z} }
          tcx.DrawPolygon(points, 1, 0, 0, 1, 2)
      end
  end)
  ```

### `DrawBox(x, y, z, width, length, rotation, [r, g, b, a, thickness, fill])`
- **说明**: 绘制 3D 矩形/包围盒。适合用来绘制 Boss 的方形区域技能（如地刺），或者带有特定朝向的冲锋路径预测。**此函数必须在 `OnUpdate` 循环中每帧调用**。
- **参数**:
  - `x, y, z`: 矩形中心点世界坐标。
  - `width, length`: 矩形的宽度（左右跨度）和长度（前后跨度）。
  - `rotation`: 矩形的朝向旋转弧度。
  - `r, g, b, a, thickness` (可选): 颜色及粗细设置。
  - `fill` (boolean, 可选): 是否开启实体填充模式，生成带有透视效果的半透明矩形面。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
      local x, y, z = tcx.ObjectPosition("target")
      if x then
          local facing = tcx.ObjectRotation("target") or 0
          -- 画一个宽 4 码，长 10 码的顺着目标朝向的预警矩形框
          tcx.DrawBox(x, y, z, 4, 10, facing, 1, 1, 0, 1, 2)
      end
  end)
  ```

### `DrawCone(x, y, z, radius, angle, facing, [r, g, b, a, thickness, fill])`
- **说明**: 绘制锥形/扇形扫击区域。极其适合用来可视化“吐息”或“顺劈斩”等正面锥形 AOE 技能。会自动画出扇形的圆弧和两条边界线段。**此函数必须在 `OnUpdate` 循环中每帧调用**。
- **参数**:
  - `x, y, z`: 扇形顶点世界坐标。
  - `radius`: 扇形半径。
  - `angle`: 扇形总夹角（弧度），例如 90 度为 `math.pi / 2`。
  - `facing`: 扇形正中心的朝向（弧度）。
  - `r, g, b, a, thickness` (可选): 颜色及粗细设置。
  - `fill` (boolean, 可选): 是否开启实体填充模式，生成具有范围覆盖感的半透明扇形。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
      local x, y, z = tcx.ObjectPosition("target")
      if x then
          local facing = tcx.ObjectRotation("target") or 0
          -- 画一个半径12码、前方90度(pi/2)的扇形顺劈斩区域
          tcx.DrawCone(x, y, z, 12, math.pi / 2, facing, 1, 0, 1, 1, 2)
      end
  end)
  ```

### `DrawCylinder(x, y, z, radius, height, [r, g, b, a, thickness, fill])`
- **说明**: 绘制 3D 圆柱体碰撞框。适合用来完美可视化怪物或玩家的真实三维碰撞体积 (Hitbox)。**此函数必须在 `OnUpdate` 循环中每帧调用**。
- **参数**:
  - `x, y, z`: 圆柱体底面圆心坐标。
  - `radius`: 圆柱体半径。
  - `height`: 圆柱体高度。
  - `r, g, b, a, thickness` (可选): 颜色及粗细设置。
  - `fill` (boolean, 可选): 是否开启实体填充模式。不仅会渲染上下底面，还会用曲面材质包裹柱体侧面，形成立体光柱特效。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
      local x, y, z = tcx.ObjectPosition("target")
      if x then
          -- 在目标位置画一个半径2码，高2.5码的3D碰撞柱体
          tcx.DrawCylinder(x, y, z, 2, 2.5, 0, 1, 1, 1, 2)
      end
  end)
  ```

### `DrawText(text, x, y, [size, r, g, b, a, center])`
- **说明**: 绘制基于屏幕 2D 坐标的文字。常用于在屏幕上显示调试信息或状态预警。**此函数必须在 `OnUpdate` 循环中每帧调用**。
- **参数**:
  - `text` (string): 要显示的文本内容。
  - `x, y` (numbers): 屏幕像素坐标 (以屏幕左上角为原点 `0,0`)。
  - `size` (number, 可选): 字体大小，默认 14。
  - `r, g, b, a` (可选): RGB 颜色及透明度 (0.0~1.0)，默认全白。
  - `center` (boolean, 可选): 是否以文字几何中心作为锚点。如果为 true，`x, y` 将指向文字正中心；如果为 false (默认)，`x, y` 指向文字左上角。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
    -- 每帧在屏幕指定坐标绘制状态
    tcx.DrawText("正在躲避暴风雪...", 200, 200, 16, 1, 0, 0, 1)
  end)
  ```

### `DrawText3D(text, x, y, z, [size, r, g, b, a])`
- **说明**: 将文字绘制在真实的 3D 世界坐标位置上。非常适合给怪物头顶添加追踪文字、标记特殊物品位置、或在 AOE 圈中心显示技能名称。会自动根据摄像机进行 3D 到 2D 的投影转换，离开视野自动隐藏。**必须在每帧调用**。
- **参数**:
  - `text` (string): 要显示的文本内容。
  - `x, y, z` (numbers): 世界坐标。
  - `size, r, g, b, a` (可选): 字体大小及颜色设置。
- **示例**:
  ```lua
  local tcx = ...
  local frame = CreateFrame("Frame")
  frame:SetScript("OnUpdate", function()
    local px, py, pz = tcx.ObjectPosition("target")
    if px then
      -- 在目标头顶(约+2.5高度)显示文字
      tcx.DrawText3D("目标位置", px, py, pz + 2.5, 14, 0, 1, 0, 1)
    end
  end)
  ```

### `SetHeading(facing, [sendPacket])`
- **说明**: 瞬间改变本地玩家角色的朝向。
- **参数**: 
  - `facing` (number): 目标朝向的弧度角 (0 ~ 2π)。
  - `sendPacket` (boolean, 可选, 默认 `false`): 为 `true` 时立即进行物理封包同步发包；为 `false` 时仅本地安全写入内存。
- **示例**: 
  ```lua
  local tcx = ...
  -- 瞬间转向并同步至服务器
  local theta = tcx.ObjectRotation('player') + 1.0
  tcx.SetHeading(theta, true)
  ```

### `FaceDirection(dir, [sendPacket])`
- **说明**: 直接改变本地玩家角色的朝向，可根据参数决定是否同步发送网络封包。
- **参数**: 
  - `dir` (number): 目标朝向的弧度角 (0 ~ 2π)。
  - `sendPacket` (boolean, 可选, 默认 `false`): 为 `true` 时，在将朝向写入内存后强制发送 `SendSetFacingPacket` 物理封包进行服务器实时同步；为 `false` 时，仅进行本地内存写入更新。
- **示例**: 
  ```lua
  local tcx = ...
  -- 直接面向新角度并发包同步
  tcx.FaceDirection(math.pi, true)
  ```

### `SetFacing(facing)`
- **说明**: 异步平滑地改变本地玩家角色的朝向。该机制通过 `OnUpdate` 帧循环实现 0.75 秒 360 度的平滑转向。为了平衡网络吞吐量和反作弊安全性，平滑转向期间采取**固定每 15 帧**以及在**转向结束时强制发包同步**的节流发包策略，保证旋转平滑的同时兼顾绝对安全性。
- **参数**: `facing` 为目标朝向的弧度角 (0 ~ 2π)。
- **示例**: 
  ```lua
  local tcx = ...
  -- 平滑转向并平稳同步到服务器
  local theta = tcx.ObjectRotation('player') + 1.0
  tcx.SetFacing(theta)
  ```

### `FaceObject(obj)`
- **说明**: 自动计算本地玩家到目标对象的角度，并平滑地让玩家转向该目标。底层同样利用了 `SetFacing` 的 0.75 秒 360 度平滑转向机制。
- **参数**: `obj` (多态): 目标对象 (Token / GUID 字符串 / 指针句柄)。
- **返回**: `boolean` (成功或失败)
- **示例**: 
  ```lua
  local tcx = ...
  -- 平滑面向焦点
  tcx.FaceObject('focus')
  ```

### `GetPitch()`
- **说明**: 获取本地玩家当前的俯仰角 (Pitch)。
- **返回**: `number` (弧度值，通常在 -π/2 ~ π/2 之间)。
- **示例**: 
  ```lua
  local tcx = ...
  local pitch = tcx.GetPitch()
  print("当前玩家俯仰角:", pitch)
  ```

### `SetPitch(pitch)`
- **说明**: 瞬间改变本地玩家当前的俯仰角 (Pitch)。输入值会被自动限制在安全的合法范围 (-π/2 ~ π/2) 内。
- **参数**: `pitch` (number): 目标俯仰角的弧度值。
- **返回**: `boolean` (成功或失败)
- **示例**: 
  ```lua
  local tcx = ...
  -- 将俯仰角调整至水平方向
  tcx.SetPitch(0.0)
  ```

### `GetMapID()`
- **说明**: 获取当前玩家所在的真实地图实例 ID。
- **返回**: `number` (Map ID)
- **示例**: 
  ```lua
  local tcx = ...
  local mapId = tcx.GetMapID()
  print("当前真实的地图实例ID是:", mapId)
  ```

---

## 5. 文件系统与安全脚本 (File System & Security)

**关于路径支持：**
所有接受 `path` 的参数均同时支持**相对路径**（相对于 `TCX-Retail.exe` 所在目录，如 `scripts/main.lua`） and **绝对路径**（如 `C:/Bot/scripts/main.lua`）。为了兼容性，请尽量使用斜杠 `/` 或双反斜杠 `\\`。

### `GetWowDirectory()`
- **说明**: 返回当前正在被注入的魔兽世界（`Wow.exe`）的游戏目录绝对路径。
- **返回**: `string` (游戏目录绝对路径)
- **示例**: 
  ```lua
  local tcx = ...
  local wowDir = tcx.GetWowDirectory()
  print("魔兽世界安装在: " .. wowDir)
  ```

### `ReadFile(path)`
- **说明**: 读取客户端本地的文件（完全兼容二进制与文本读取，无 `\0` 截断风险）。
- **参数**: `path` (string) 文件路径（支持相对或绝对路径）。
- **返回**: `data` (string) 文件内容，读取失败则返回 `false`。
- **示例**: 
  ```lua
  local tcx = ...
  local data = tcx.ReadFile('C:/TCX/scripts/test.json')
  ```

### `WriteFile(path, data, append)`
- **说明**: 向客户端本地写入文件（完全兼容二进制与文本写入，无 `\0` 截断风险）。
- **参数**:
  - `path` (string): 文件路径（支持相对或绝对路径）。
  - `data` (string): 要写入的内容。
  - `append` (boolean): 是否为追加模式。如果为 `false` 则覆盖原有内容。
- **返回**: `true | false` (是否写入成功)
- **示例**: 
  ```lua
  local tcx = ...
  -- 覆盖写入配置文件
  tcx.WriteFile("C:/TCX/config.json", '{"bot_enabled": true}', false)
  
  -- 追加写入运行日志
  tcx.WriteFile("C:/TCX/run.log", "Bot started at 12:00\n", true)
  ```

### `DownloadFile(url, destPath, callback)`
- **说明**: 异步下载远程文件并直接以二进制形式写入本地磁盘，完全避免内存截断风险。非常适合下载 Lua 脚本、加密包（.tcx）或压缩文件（.zip）。
- **参数**:
  - `url` (string): 远程文件的下载地址。
  - `destPath` (string): 本地保存路径（支持相对或绝对路径）。
  - `callback` (function, 可选): 异步回调函数，接收两个参数：`(success, err)`。
    - `success` (boolean): 是否下载并保存成功。
    - `err` (string): 失败时的错误信息。
- **返回**: `true | false` (是否成功发起了后台下载任务)
- **示例**: 
  ```lua
  local tcx = ...
  tcx.DownloadFile("https://example.com/data.zip", "C:/TCX/data.zip", function(success, err)
      if success then print("下载成功") else print("下载失败:", err) end
  end)
  ```

### `UnzipFile(zipPath, extractDir, callback)`
- **说明**: 异步解压本地的 ZIP 文件到指定目录。使用底层 Windows 原生静默解压实现，无任何弹窗进度条。解压全过程在后台线程执行，完成后通过回调通知。如果目标释放目录不存在会自动创建。
- **参数**:
  - `zipPath` (string): ZIP 压缩包的本地路径（支持相对或绝对路径）。
  - `extractDir` (string): 解压释放的目标目录路径（支持相对或绝对路径）。
  - `callback` (function, 可选): 异步回调函数，接收两个参数：`(success, err)`。
- **返回**: `true | false` (是否成功发起了后台解压任务)
- **示例**: 
  ```lua
  local tcx = ...
  tcx.UnzipFile("C:/TCX/data.zip", "C:/TCX/data_folder", function(success, err)
      if success then print("解压完成") else print("解压失败: " .. err) end
  end)
  ```

### `ListFiles(dir)`
- **说明**: 罗列本地目录中的所有文件。
- **参数**: `dir` (string): 目录路径（支持相对或绝对路径）。
- **返回**: `table` (包含所有文件名的 Lua 数组表)
- **示例**: 
  ```lua
  local tcx = ...
  -- 获取所有的职业脚本模块
  local files = tcx.ListFiles("C:/TCX/scripts/classes")
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
  local tcx = ...
  local dirs = tcx.ListDirectories("scripts")
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
  local tcx = ...
  local success = tcx.CreateDirectory("scripts/myfolder")
  ```

### `DirectoryExists(dir)` / `FolderExists(dir)`
- **说明**: 检查指定目录是否存在。
- **参数**: `dir` (string): 目录路径。
- **返回**: `true | false`
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.DirectoryExists("scripts/myfolder") then
      print("文件夹存在")
  end
  ```

### `FileExists(file)`
- **说明**: 检查指定文件是否存在。
- **参数**: `file` (string): 文件路径。
- **返回**: `true | false`
- **示例**: 
  ```lua
  local tcx = ...
  if tcx.FileExists("scripts/test.lua") then
      print("文件存在")
  end
  ```

### `DeleteFile(file)`
- **说明**: 从系统磁盘中删除指定文件。
- **参数**: `file` (string): 要删除的文件路径。
- **返回**: `true | false` (是否删除成功)
- **示例**: 
  ```lua
  local tcx = ...
  local success = tcx.DeleteFile("scripts/test.txt")
  ```

### `EncryptFile(inPath, outPath)`
- **说明**: 将明文脚本文件读取、通过内置 VMP 密钥进行底层加密（AES-256-GCM），并输出为一个不可读的安全文件（推荐后缀 `.tcx`）。通常用于本地开发与发布阶段。
- **参数**:
  - `inPath` (string): 源明文文件路径（支持相对或绝对路径）。
  - `outPath` (string): 目标加密文件输出路径。
- **返回**: `true | false`
- **示例**: 
  ```lua
  local tcx = ...
  tcx.EncryptFile("C:/Dev/bot.lua", "C:/Release/bot.tcx")
  ```

> [!TIP]
> **服务器端一键加密接口 (推荐用于 CI/CD 和云端分发)**
> 除了使用 Lua 本地环境加密外，你也可以直接调用 TCX 官方服务器提供的云端接口完成加密。云端加密生成的 `.tcx` 文件完全等效于本地客户端的输出。
> **使用方法 (支持批量脚本调用)**:
> ```bash
> curl -s -X POST "https://tcxcore.com/api/encrypt" --data-binary "@file.lua" > file.tcx
> ```

### `LoadProtectedFile(path, [callback], ...)`
- **说明**: 读取加密的或未加密的脚本文件（支持 `.tcx` 加密包与普通明文 `.lua` 文件），在**内存中安全加载/解密并编译为一个匿名函数，然后将传入的参数传递给该函数执行**。对于加密脚本，解密后的明文不会落盘，并且会在安全缓冲区执行后立刻被底层 C++ 覆写销毁，防止内存 Dump 破解。如果执行出错，会返回错误信息，且**不会暴露加密文件的源代码**。
  **【纯净执行环境】**：通过此方法加载的脚本处于无污染的最高执行权限上下文中，可以直接安全调用受保护的函数，且获取到的所有 WOW API 返回值天然没有秘密值（Secret Value）标记，无需使用 `Unlock` 或 `Unwrap`。
  **【异步与同步双模式】**：如果第二个参数传入了一个 `function` 作为回调，系统会自动走**异步无阻塞模式**，文件读取和解密操作会被丢弃到后台 C++ 线程进行处理，防止由于文件或脚本巨大造成的游戏画面卡顿。
- **参数**: 
  - `path` (string): 加密或明文文件路径（支持相对或绝对路径）。
  - `callback` (function, 可选): 如果提供，则异步执行脚本，并在此回调中返回 `(success, ...返回值)` 或 `(false, errorMsg)`。
  - `...` (动态参数): 传递给解密后匿名函数的参数。
- **返回**: 
  - **同步模式**: `true, ...返回值` (执行成功并返回脚本执行的返回值) 或 `false, 错误信息` (加载或执行失败)。
  - **异步模式**: 立即返回空值，结果会通过 `callback` 传入。
- **示例**: 
  ```lua
  local tcx = ...
  -- [同步模式] 在正式版中加载加密包，传递参数，并获取返回值
  local success, result1, result2 = tcx.LoadProtectedFile("C:/Release/bot.tcx", "arg1", 123)
  if not success then
      print("同步加载失败:", result1)
  end

  -- [异步模式] 不阻塞主线程加载大文件，通过回调接收数据
  tcx.LoadProtectedFile("C:/Release/huge_bot.tcx", function(success, result1, result2)
      if success then
          print("异步加载成功，结果：", result1, result2)
      else
          print("异步加载失败：", result1)
      end
  end, "arg1", 123)
  ```

### `LoadProtectedBuffer(buffer, [callback], ...)`
- **说明**: 直接从一个内存字符串/二进制物理缓冲区（支持加密的二进制字节流与普通未加密的明文 `.lua` 代码文本字符串）中加载、解密/解析并执行代码。它和 `LoadProtectedFile` 的执行逻辑完全一致，并同样支持同步 and 异步双模式。安全等级最高，彻底做到从云端到执行的全流程无文件（Fileless）注入。
  **【纯净执行环境】**：与 `LoadProtectedFile` 一致，通过此方法加载的脚本同样处于无污染的最高执行权限上下文中，可自由调用受保护函数且无秘密值（Secret Value）污染。
- **参数**:
  - `buffer` (string): 存放加密数据的二进制字符串缓冲区。
  - `callback` (function, 可选): 如果提供，则进入异步模式。
  - `...` (动态参数): 传递给解密后匿名函数的参数。
- **返回**: 与 `LoadProtectedFile` 机制一致。
- **示例**:
  ```lua
  local tcx = ...
  tcx.HttpRequest({
      url = "http://your-server.com/script.tcx",
      callback = function(status, body)
          if status == 200 then
              -- 从内存变量 body 异步解析执行，绝不落盘
              tcx.LoadProtectedBuffer(body, function(success, ...)
                  if success then
                      print("内存脚本加载成功", ...)
                  else
                      print("内存脚本加载失败:", ...)
                  end
              end, "arg1")
          end
      end
  })
  ```

---

## 6. 其他工具 (Utilities)

### `GetKeyState(key)`
- **说明**: 判断键盘/鼠标某个键是否正在被物理按下以及是否处于锁定/触发状态（穿透游戏，直接读 Windows API）。
- **参数**: `key` (number) 虚拟键码（如 `0x10` 表示 Shift 键，`0x14` 表示 CapsLock）。
- **返回**: `isDown, isToggled` (两个 boolean 值)
- **示例**: 
  ```lua
  local tcx = ...
  -- 按下 Shift 键时暂停输出
  local isDown, isToggled = tcx.GetKeyState(0x10)
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
  local tcx = ...
  tcx.HttpRequest({
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

### `GetLicenseInfo(callback)`
- **说明**: 异步获取当前授权证书（License）的详细状态和统计数据。返回的时间数据（如创建时间、过期时间及最后活跃时间）已在底层自动转换为玩家本地时区。
- **参数**: 
  - `callback` (function): 异步回调函数，接收两个参数：`(success, result)`。
    - `success` (boolean): 请求是否成功。
    - `result` (table | string): 请求成功时返回一个字典表，失败时返回错误信息字符串。返回字典包含以下字段：
      - `id` (string): 证书 ID
      - `key` (string): 授权密钥 (License Key)
      - `status` (string): 证书状态 (例如 `"ACTIVE"`)
      - `maxSessions` (number): 允许的最大会话数 (多开数)
      - `currentSessions` (number): 当前已登录的活跃会话数
      - `expireAt` (string): 证书过期本地时间 (格式为 `"YYYY-MM-DD HH:MM:SS"`)
      - `remainingDays` (number): 剩余可用天数
      - `createdAt` (string): 证书创建本地时间 (格式为 `"YYYY-MM-DD HH:MM:SS"`)
- **返回**: `boolean` (是否成功发起请求)
- **示例**: 
  ```lua
  local tcx = ...
  tcx.GetLicenseInfo(function(success, data)
      if success then
          print("授权密钥: " .. data.key)
          print("证书状态: " .. data.status)
          print("允许最大多开数: " .. tostring(data.maxSessions))
          print("当前已使用多开: " .. tostring(data.currentSessions))
          print("过期本地时间: " .. data.expireAt)
          print("剩余天数: " .. tostring(data.remainingDays))
      else
          print("获取授权信息失败: " .. tostring(data))
      end
  end)
  ```

### `YamlEncode(obj)`
- **说明**: 将 Lua 的 table、number、string 或 boolean 序列化为标准 YAML 格式字符串。
- **参数**: `obj` (任意支持的数据类型) - 要序列化的 Lua 对象（最常用的是 table）。
- **返回**: `string` (序列化后的 YAML 字符串)。
- **示例**: 
  ```lua
  local tcx = ...
  local yamlStr = tcx.YamlEncode({ name = "TCX", version = 1.0 })
  ```

### `YamlDecode(str)`
- **说明**: 将标准的 YAML 格式字符串反序列化为 Lua table。
- **参数**: `str` (string) - YAML 格式的字符串。
- **返回**: `table` (解析后的数据字典) 或者 `nil` (解析失败)。
- **示例**: 
  ```lua
  local tcx = ...
  local obj = tcx.YamlDecode("name: TCX\nversion: 1.0")
  print(obj.name) -- 输出 TCX
  ```

### `JsonEncode(obj)`
- **说明**: 将 Lua 的 table、number、string 或 boolean 序列化为标准 JSON 格式字符串。
- **参数**: `obj` (任意支持的数据类型) - 要序列化的 Lua 对象。
- **返回**: `string` (序列化后的 JSON 字符串)。
- **示例**: 
  ```lua
  local tcx = ...
  local jsonStr = tcx.JsonEncode({ data = { 1, 2, 3 } })
  ```

### `JsonDecode(str)`
- **说明**: 将标准的 JSON 格式字符串反序列化为 Lua table。
- **参数**: `str` (string) - JSON 格式的字符串。
- **返回**: `table` (解析后的数据字典) 或者 `nil` (解析失败)。
- **示例**: 
  ```lua
  local tcx = ...
  local obj = tcx.JsonDecode('{"data":[1,2,3]}')
  print(obj.data[1]) -- 输出 1
  ```

### `Unwrap(...)`
清除 WoW 11.x+ (Midnight) 中 Lua 变量底层的 "Secret" 内存保护标记，解除暴雪的保护状态封锁。
- **参数**: `...` (任意类型的变量) - 比如被暴雪打上受保护标记的 table 或值。
- **返回**: 经过底层 `clearsecret` 处理后的原变量。
- **说明**: 系统会自动无差别地抹除传入参数在 Lua 栈上的受保护 TValue 标志；如果传入的是 `table`，还会深度递归清除内部所有元素的 Secret 标记。
  **【使用场景】**：此函数**仅在从游戏插件目录加载的脚本中才需要使用**。通过 `LoadProtectedFile` / `LoadProtectedBuffer` 或 `scripts/` 目录加载的脚本处于无污染上下文中，调用 WOW API 所获得的所有返回值天然无秘密值（Secret Value）标记，不需要解包。
- **示例**: 
  ```lua
  local tcx = ...
  -- 获取受保护的暴雪私有数据
  local protectedData = C_Spell.GetSpellInfo(12345) 
  -- 通过 Unwrap 强行抹除所有 Secret 内存位，解包安全使用
  local safeData = tcx.Unwrap(protectedData)
  print("安全读取技能名:", safeData.name)
  ```

---

## 7. 环境与投掷物系统 (Environment & Projectiles)

TCX 提供了强大的底层内存直读能力，用于扫描和躲避游戏世界中尚未结算或持续生效的法术效果。

### `GetAreaTriggerCount()`
- **说明**: 获取当前环境内存中所有的 AreaTrigger / DynamicObject (地板技能、地面环境效果) 的总数。
- **返回**: `number` (触发器总数)
- **示例**: 
  ```lua
  local tcx = ...
  local count = tcx.GetAreaTriggerCount()
  print("当前地面环境技能数量: " .. count)
  ```

### `GetAreaTriggerWithIndex(index)`
- **说明**: 根据索引获取 AreaTrigger / DynamicObject 的详细属性。常用于遍历扫描所有地面范围技能（例如暴风雪、火雨、某些副本怪物的持续地毯）。
- **参数**: `index` (number) - 索引，从 1 开始。
- **返回**: 
  - `spellId` (number) - 产生该地毯的法术 ID。
  - `x, y, z` (number) - 地毯中心的 3D 世界坐标。
  - `radius` (number) - 范围的精确半径大小 (极少数技能可能读出 0，请使用下方的查表函数)。
  - `startTime` (number) - 产生该地毯的绝对时间戳 (GetTickCount)。
  - `duration` (number) - 地毯的持续时间 (毫秒)。
  - `ownGuid` (string) - 对象自身的底层 GUID。
  - `casterGuid` (string) - 释放该地毯的施法者 GUID。
- **示例**: 
  ```lua
  local tcx = ...
  for i = 1, tcx.GetAreaTriggerCount() do
      local spellId, x, y, z, radius = tcx.GetAreaTriggerWithIndex(i)
      if spellId then
          print(string.format("地毯法术: %d, 坐标: %.1f, %.1f, %.1f, 半径: %.1f", spellId, x, y, z, radius))
      end
  end
  ```

### `GetMissileCount()`
- **说明**: 获取当前内存中正在飞行的法术投射物 (Missile) 总数。
- **返回**: `number` (当前活跃导弹的数量)
- **示例**: 
  ```lua
  local tcx = ...
  local count = tcx.GetMissileCount()
  print("当前活跃导弹数量: " .. count)
  ```

### `GetMissileWithIndex(index)`
- **说明**: 根据索引获取飞行中的导弹详情，可以用于预判范围和躲避技能。
- **参数**: `index` (number) - 索引，从 1 开始。
- **返回**: 
  - `spellId` (number) - 导弹的法术 ID。
  - `0` (number) - 占位符。
  - `mx, my, mz` (number) - 导弹当前的实时 3D 世界坐标。
  - `sourceGuid` (string) - 施法者 GUID。
  - `sx, sy, sz` (number) - 导弹的起始发射坐标。
  - `targetGuid` (string) - 导弹追踪的目标 GUID。
  - `tx, ty, tz` (number) - 导弹的预计落点坐标。
- **示例**: 
  ```lua
  local tcx = ...
  for i = 1, tcx.GetMissileCount() do
      local spellId, _, mx, my, mz = tcx.GetMissileWithIndex(i)
      if spellId then
          print(string.format("导弹技能ID: %d, 实时坐标: %.2f, %.2f, %.2f", spellId, mx, my, mz))
      end
  end
  ```

### `GetSpellRadius(spellId)`
- **说明**: 这是一个由辅助静态数据库 (`_SpellRadiusDB.lua`) 提供的外挂扩展函数。传入法术 ID，返回对应的真实危险半径。由于 Missile 在飞行中是一个绝对的质点，没有 Radius 字段，必须依赖该方法进行客户端脱机查表。
- **参数**: `spellId` (number) - 目标法术 ID。
- **返回**: `number` (安全判定半径，若未收录则返回 `0.0`)。
- **示例**: 
  ```lua
  local tcx = ...
  local radius = tcx.GetSpellRadius(190356) -- 例如暴风雪
  if radius > 0 then
      print("法术危险半径为: " .. radius .. " 码")
  end
  ```
