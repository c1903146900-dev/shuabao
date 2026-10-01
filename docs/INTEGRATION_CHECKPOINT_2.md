# 两种房间循环与真实成长 checkpoint 2

基于 main `15e694e2e260953076d37cc81cf0c23eaa658487`，不混入后续美术 b5bcc203。默认入口仍是 `scenes/integration/room.tscn`，现在使用真实 catalog-backed 单局模型；不是 UI demo 或奖励 fixture。

## 操作与原型边界

K 修习，选一个候选并投入1级授予的1点；进入第1房。WASD移动，左键普攻，Q/E/R技能，Shift冲刺。胜利后 Esc 关闭结算，K升级，P打开安全商店；点击顶部进入下一房。两个各3普通敌人的布阵交替重复，房间ID持续递增，不是四幕内容。保留生命、冷却、技能、装备和账本。F5只在真死亡后续战同一房：保留存活敌人、已发奖励ID、技能与装备，恢复35%生命、不重置冷却、自救次数；不是新开账本。此续战策略及每敌150金/60经验是本轮新增原型初值，待设计审阅，不能当作历史定稿。

倒地后关闭结算再空格自救一次；第二次致死扣当前级剩余经验30%（向下取整），不降级或扣技能点。首次倒地不扣经验。已击杀敌人的收益立即按唯一身份到账；结算只汇总已到账收益，不再次发奖。

## 权威与事务

- `ledger_bridge.gd` 持有唯一 `run_model.gd`（继承 catalog_model）。击杀身份为本局ID/房间ID/敌人ID；先核对当前房间和敌人死亡状态，然后通过模型原子 command 同时写金币、经验、授点和奖励记录。相同请求重放幂等，不同请求复用奖励ID拒绝。
- 房间终止用房间/阶段/事件序号去重；真死亡处罚也进入模型独立幂等事务。模型为XP唯一权威，战斗的XP/GOLD是投影。交易、死亡、升级不补生命、不重置CD。级别上限18，仍是P3/Q5/E5/R(1+2+2)共18点；R后两阶未知门槛保持关闭，无额外点数来源。
- HUD注入同一个模型，用真实 progression_controller；接受成长请求后同步战斗loadout。AD按基础32 + 聚合AD重新计算，不逐帧累加，铁刃使真实普攻变为40。
- 只声明 `stats.v1` / `stat.AD.v1`。未实现属性装备不能买，药品、锻体、海克斯本阶段全部拒绝；海克斯按钮禁用。目录数值均仍是新增可调初值。没有全开能力flag或假装执行机制。
- 行动回执保存 accepted/reason，并向UI反馈拒绝原因；持续、重施、锁定、冻结状态由真实战斗状态投影，有冷却时同时显示冷却。按住攻击的逐帧轮询不分配幂等记录；显式玩家/UI命令保留请求ID。

## 验证范围

真实Godot MCP客户端完成 initialize、tools/list、应用查询、脚本写入/验证、场景创建/保存/重开/运行、InputEvent输入、运行读回及截图。Blender仍完成握手与应用查询，本轮无新资产制作。输入是引擎真实GUI路由 `Input.parse_input_event`，不是OS键鼠，也不是直接扣血/发经验/关AI。

两房测试先通过真实UI学习Q，连续清怪；第一房金币450、经验180对应Lv2/本级80，重复击杀和终止回调不重复到账；升级Q2并花450购买铁刃。第二房仅普攻清怪，实际40伤害且受到敌人攻击；累计6个唯一奖励，Lv3/本级135、金币450。胜利冻结、同账本续房及CD按战斗时钟恢复递减通过。随后第三次进入第1种布阵，等待敌人自然击倒、自救、真死亡（135→94），重放死亡回调不二扣，F5同房续战保留账本。详见[结构化记录](validation/two-room/reports.json)、[两房结算截图](validation/two-room/mcp/step-04-get_game_screenshot-0.png)和[输入边界截图](validation/two-room/input-boundary.png)。

另外重新运行：战斗364项、QA002跨房35项、成长274项、经济交错17项、目录13862项均通过；`scripts/check.sh`导入与无头启动通过（不是可玩验收）。另有纯模型回归检查18点守恒、奖励/处罚去重、额外技能点拒绝、未知R门槛与未接入能力原子拒绝；不冒充真人可玩验证。纯模型54项（包括24种未接入物品的原子拒绝）及旧输入边界5项通过。日志另列证据。

首轮两个失败属于测试设计：续房经过输入帧后CD应随时钟递减，不能要求严格相等；第二房用Q先击杀，没观测到40点普攻。保留首轮结果，修正时钟断言并改第二房仅普攻后复测。

## 下一阶段与尚未验收

- 独立QA需要固定本次新SHA复验两房及死亡邻接，15e694的通过不能替代本版。
- E2/R2动画覆盖、导入GLB受击闪白仍未绑定；持续/重施显示映射已接，全部技能组合的运行验证未在本轮完成。
- 后续审阅合并b5bcc203美术，再看真实战斗遮挡、身体软阴影和接触感。本轮未整合。
- 当前两房没有精英/Boss编组，没有存档/联机；仅目标平台架构仍保留。旧发行包是checkpoint1，不包含本轮。导出白名单随源码更新，实际新包留下一阶段重建和独立验证。
- 不上传Library，不发公开Release、不部署、不访问阿里云。

## 复跑

先按仓库 [云端复用步骤](CLOUD_REPRO.md)和[MCP客户端说明](MCP_CLIENT.md)准备已固定版本的本地工具。MCP校验入口如下，必须使用fresh fixture避免复用过期脚本：

```sh
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --fresh-fixture --workflow scripts/mcp/two_room.json --evidence .local/recheck-two-room
.local/blender-mcp-venv/bin/python scripts/mcp/check.py --workflow scripts/mcp/input_boundaries.json --evidence .local/recheck-input
XDG_CACHE_HOME="$PWD/.local/cache" XDG_DATA_HOME="$PWD/.local/data" XDG_CONFIG_HOME="$PWD/.local/config" godot --headless --path . --script tests/integration/run_authority.gd
```

读取工具回执及 `TWO_ROOM_REPORT` / `BOUNDARY_REPORT` 中的failures数组，不以MCP传输层isError=false代替业务断言。测试完成F5续战后，游戏仍实时运行，后续读回可能已再次死亡；验收的具名sample是当时实际状态，不能用后续窗口状态冒充同一时刻。两种布阵会循环，测试的“第3房”就是第1种布阵的重复，不是第三种内容。

证据检查附注：首次图片查看显示疑似空白；对同一PNG重新查看并检查像素后确认为完整正常结算图，未发现Godot采集黑帧。另行重跑两房12项全部通过，并重抓[关闭结算后的真实画面](validation/two-room/visual-retry/step-07-get_game_screenshot-0.png)完成复核。新增暂存文件执行凭据特征扫描未发现命中；这不是对全部敏感信息不存在的保证。
