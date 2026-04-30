# Bastion - TCX-Retail 适配版

基于 [4n0n/Bastion](https://git.tinkr.site/4n0n/bastion) 框架，完整适配 TCX-Retail 内存直接交互架构。

## TCX 适配变更

### 核心架构
- **统一 Token 转换**：通过 `Unit:GetOMToken()` 实现内存指针到原生 Token 的自动转换
  - `string` 类型（`"player"`, `"target"` 等标准 Token）→ 直接返回
  - `lightuserdata` 类型（TCX.Objects() 返回的内存指针）→ 通过 `ObjectToken()` 转换
  - 对象失效时返回 `nil`，防止无效指针传入原生 API
- **TCX Unwrap 集成**：所有原生 API 返回值（`UnitPower`, `UnitCastingInfo`, `UnitChannelInfo` 等）的暴雪 taint 加密值均在框架层通过 `_u()` 自动解密

### 框架模块变更

| 模块 | 变更说明 |
|------|---------|
| `Unit.lua` | 重写 `GetOMToken()`，适配 lightuserdata 指针；`GetPower/GetMaxPower/GetPowerType` 改用原生 API + Unwrap；修复 `IsOutdoors()` 的 and/or 短路 bug；`UnitCastingInfo/UnitChannelInfo` wrapper 对所有返回值做 Unwrap |
| `ObjectManager.lua` | 每帧更新缓存对象的内存指针（`unit.unit = object`）；失效对象 Token 检查跳过 |
| `AuraTable.lua` | `GetUnitBuffs/GetUnitDebuffs/OnUpdate` 添加 Token nil 保护 |
| `Spell.lua` | 新增 `Spell:IsCurrent()` 方法（封装 `C_Spell.IsCurrentSpell` + Unwrap） |
| `Vector3.lua` | `FastDistance` 替换为 `math.sqrt` 原生实现 |
| `Item.lua` | `FastDistance` 替换为 `math.sqrt` 原生实现 |
| `TCXAdapter/` | 新增 TCX 兼容适配层，映射 `Object/Objects/ObjectGUID` 等全局函数 |
| `_bastion.lua` | 适配 TCX 环境初始化和模块加载 |

### 脚本层规范
- 脚本（`scripts/` 目录）**只调用框架 API**，不直接使用 WoW 原生 API
- 所有 taint 解密逻辑收敛在框架层，脚本层无需关心
- 通过 `Unit:GetOMToken()` 获取 Token，通过 `Spell:Cast()` 施放技能

## 快速开始
1. 将 `Bastion` 文件夹放入 TCX-Retail 的 `scripts/` 目录
2. 游戏内输入 `/bastion module` 加载对应职业的脚本模块
3. 游戏内输入 `/bastion toggle` 启用引擎自动运行

## 已有脚本
- `GuardianDruid.lua` - 守护德鲁伊（熊坦）
- `FeralDruid.lua` - 野性德鲁伊（猫 DPS）

## 环境依赖
- **平台**: TCX-Retail
- **游戏版本**: WoW Retail 12.0.5
- **底层 API**: `ObjectToken()`, `TCX.Objects()`, `TCX.Unlock()` 等
