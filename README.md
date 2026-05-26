# Bastion - TCX-Retail/TCX Core 适配版

基于 [4n0n/Bastion](https://git.tinkr.site/4n0n/bastion) 框架，完整适配 TCX-Retail/TCX Core 内存直接交互架构。

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
| `_bastion.lua` | 增加职业目录按需加载逻辑，并加入 `TCX.IsInGame()` 状态检测，支持安全登录初始化延迟 |
| `BastionUI/` & `config/` | 新增模块化 UI 界面和基于 YAML 的 ConfigManager，支持用户在游戏内切换和保存配置 |
| `Locale/` | 增加多语言翻译文本支持模块 |

### 最新更新 (v1.x)
- **多版本客户端支持**：重构了脚本目录层级，现在支持按 `Retail`、`Titan` 和 `TBC` 客户端版本独立加载对应的战斗循环模块 (`scripts/<版本>/<职业>/`)。
- **底层内存检索优化**：全面升级了 `Unit`, `ObjectManager`, `TCXAdapter` 的底层交互，大幅提升了 `ObjectToken`、`ObjectGUID` 及交互接口在复杂战斗环境中的运行性能。
- **配置系统 (JSON) 升级**：废弃了 `YAML` 格式，全面采用更加规范的 `JSON` 持久化方案。现在每一个战斗循环模块均会独立生成对应名称的 `.json` 配置文件，全局开关和界面热键则整合入 `framework.json`。


### 脚本层规范
- 脚本（`scripts/` 目录）**只调用框架 API**，不直接使用 WoW 原生 API
- 所有 taint 解密逻辑收敛在框架层，脚本层无需关心
- 通过 `Unit:GetOMToken()` 获取 Token，通过 `Spell:Cast()` 施放技能

## 快速开始
注：本框架依赖：https://www.curseforge.com/wow/addons/abstract-framework ， 请自行下载解压到魔兽世界的插件目录中
1. 将 `Bastion` 文件夹放入 TCX-Retail或TCX.App 的 `scripts/` 目录
2. 进入游戏TCX解锁器解锁成功后，在小地图左键点击Bastion图标打开UI界面，选择对应职业天赋的循环，右键点击Bastion图标，切换Bastion的开关

## 已有脚本
所有职业均已经按客户端版本 (Retail / Titan / TBC) 进行了分类拆解。如：
- `scripts/Titan/DeathKnight/DeathKnightInitial.lua`
- `scripts/TBC/Mage/MageInitial.lua`
- `scripts/Retail/Druid/GuardianDruid.lua`
- **`scripts/Retail/DeathKnight/DeathKnightFrost.lua` (冰霜死亡骑士 - 死神使者 / 冰龙吐息流派)**
  - 严格根据 WCL 顶尖实战日志打磨的高阶循环脚本。
  - **单体核心**：以【破灭】强化湮灭为最高优先级，完美同步【死神印记】与【冰霜之柱】爆发，平稳期采用【冰霜打击】进行高频泄能。
  - **AOE 智能切换**：自动探测周围敌对目标数量（默认 ≥3 触发），智能切换【冰霜之镰】消耗杀戮机器，并转用【冰川突进】倾泄能量，杜绝单体爆发被误浪费。
  - **资源管理**：精准规划符文/符能，高频智能开启【符文武器增效】填补资源缺口，最大化【冰龙吐息】的维持时间与循环流畅度。
- **`scripts/Retail/Mage/MageFrost.lua` (冰霜法师 - 疾咒师 / 碎裂核心流派)**
  - **核心爆发机制**：实时追踪目标身上的【冻结】(1221389) 堆叠层数。当满 5 层时瞬间打出【冰枪术】，完美引爆巨额【碎裂】被动伤害。
  - **引导优先级跃升**：深度适配 WCL 实战节奏，将【冰霜射线】提升至极高优先级，确保在不移动时卡 CD 打出毁灭性的单体引导伤害。
  - **智能自保与 AOE 控制**：内置智能【深寒凝冰】防暴毙机制，血线危急自动减伤；并在多目标 AOE 模式中自动穿插【超级新星】进行群体打断和辅助输出。
- **`scripts/Retail/Warlock/WarlockDemonology.lua` (恶魔学识术士 - 恶魔使徒流派)**
  - **量身定制**：严格根据 WCL 恶魔术前排日志（Diabolist），100% 聚焦于【恶魔使徒】英雄天赋的极致输出循环。
  - **瞬发核弹【陨灭】**：精准捕捉由【敬魔仪式】触发的极高伤害技能【陨灭】(Ruin)，赋予最高优先级，确保触发即砸，绝不浪费。
  - **高效资源闭环**：完美适配 15.1 CPM 的【古尔丹之手】与 10.5 CPM 的【恶魔之箭】实战配比。满 3 片即刻砸古尔丹之手招小鬼；一旦触发【恶魔之核】且碎片未满，立即穿插瞬发【恶魔之箭】回片，彻底告别卡手。
  - **大招联动与生存**：自动监控场上恶魔数量卡 CD 释放【召唤恶魔暴君】；内置基于 WCL 实战防暴毙习惯的【黑暗契约】智能护盾。
- **`scripts/Retail/Warlock/WarlockDestruction.lua` (毁灭术 - 恶魔使徒流派)**
  - **纯化体系**：去除了冗余的多流派兼容，完全聚焦于【恶魔使徒】的极致输出。
  - **陨灭与泄片**：【陨灭】触发后给予最高优先级释放；结合 14.5 CPM 级别的实战倾泻频率，在碎片充足或带有【爆燃】时高频连发【混乱之箭】。
  - **精准斩杀**：【暗影灼烧】仅在目标血量低于 20% 或角色处于移动中才会释放，绝不浪费宝贵的站桩公 CD。
- **`scripts/Retail/DemonHunter/DemonHunterDevourer.lua` (恶魔猎手 - 噬灭专精)**
  - **全新专精适配**：新增第三专精“噬灭”量身打造，摒弃传统浩劫体系，基于纯正的虚空魔法机制构建输出循环。
  - **核心终结技**：将拥有高达 28.5% 伤害占比的巨型核弹【坍缩之星】置于绝对优先级，一旦条件满足或触发瞬间打出，绝不浪费。
  - **资源顺滑闭环**：以【吞噬】作为底层填充疯狂积攒资源，并在真空期稳健穿插【虚空射线】和【灵魂献祭】倾泻伤害。



## 环境依赖
- **平台**: TCX-Retail
- **游戏版本**: WoW Retail 12.0.5 / WoW Titan / WoW TBC
- **底层 API**: `ObjectToken()`, `TCX.Objects()`, `TCX.TraceLine()` 等
