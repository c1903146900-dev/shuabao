# E3 下一最小边界候选：来源与普通组合落点

2026-10-06 06:06 UTC，只读盘点。本文是唯一新增文件；未改玩法、测试代码、选择器、绑定或生产入口，未启动引擎、导入、CUA、上传。下述历史通过均来自已有原始日志和进程回执，不是本次执行。

## 1. 有效规则与原文

- 最新权威：`docs/source_decisions/20261006-ink-five-resolutions.json`，`rules.ink_e3_obstacles`：允许隔墙交换；本次任一必需落点墙内/界外，必须在任何位移前拒绝整次交换，不能仅跳过非法对象。H12 当前返回使用相同规则；Boss 及其他原参与者例外保留，H11 仍须启用才有自身/友方资格。
- 继续有效：`docs/source_decisions/20261005-ink-six-resolutions.json`，`rules.ink_q2_e3`：第一标记不开始 CD；原 5 秒到期时先移除标记再起 CD；合法二段完成起 CD。
- 最新 overlay 的 `implementation_conventions.e3` 已明确把“拒绝后保留原 A/H12 窗口、不另起 CD”标作制作连续性选择，不伪装成用户逐字时序规则。拒绝 H12 不撤销已完成的首轮交换。
- 原始 DOCX：`data/final_design/sources/heroes_mechanics_no_values_v03(1).docx`，全部 body 后代段落 77 / 99 / 100。已直接只读解 OOXML，与 `tests/ink_e3_exchange_foundation_20261005/candidate03/source_oracle.json` 三段逐字相等；并直接核对 XLSX 61 个数值单元格相等、无公式。

原 E3（¶77）要点：首次在 10 米内放圆 A，5 秒内放同尺寸 B；普通/精英敌人交换，Boss/队友不交换；单侧空时另一侧合法敌人整体移过去。只有被移动敌人受普通伤害，近高远低，2 米以内最高，之后线性降至最大交换距离最低。H11（¶99）额外允许晏归舟自身与友方英雄；H12（¶100）交换后 2 秒内可使仍存活的原交换对象回原区域。

XLSX `晏归舟技能!E58:J67` / `专属海克斯!F60`（六阶从左至右）：

| 来源 | 参数 | 原值 |
|---|---|---|
| E58:J58 | 首 A 范围 | 10 / 10 / 10 / 10 / 10 / 10 米 |
| E59:J59 | B 窗口 | 5 / 5 / 5 / 5 / 5 / 5 秒 |
| E60:J60 | 画幅半径 | 3 / 3.06 / 3.16 / 3.32 / 3.54 / 3.8 米 |
| E61:J61 | A–B 最大距离 | 10 / 10.24 / 10.6 / 11.2 / 12.01 / 13 米 |
| E62:J62 | 近距阈值 | 2 / 2 / 2 / 2 / 2 / 2 米 |
| E63:J63 | 近距固定伤害 | 65 / 88 / 122 / 179 / 256 / 350 |
| E64:J64 | 近距 AP% | 90 / 95 / 102 / 114 / 130 / 150 |
| E65:J65 | 远距固定伤害 | 30 / 40 / 54 / 78 / 110 / 150 |
| E66:J66 | 远距 AP% | 45 / 48 / 52 / 59 / 68 / 80 |
| E67:J67 | CD | 20 / 19.64 / 19.1 / 18.2 / 16.98 / 15.5 秒 |
| 专属海克斯 F60 | H12 返回窗 | 2 秒 |

没有新增 H11 数值。以下重叠归侧、身体接触、保留相对偏移、快照时点等是旧候选明确声明的制作约定，不能反标成原文新增条款。

## 2. 参与分支与“必需落点”

准确代码：`candidate03/ink_e3_sim.gd`，`_e3_member`（129）、`_e3_exchange_plan`（144）、`_e3_return_plan`（259）；相对于 `tests/ink_e3_exchange_foundation_20261005/`。

| 分支 | 必需落点集合 | 既有例外 / 归属 |
|---|---|---|
| 首次放 A | 空；仅标记，无演员位移 | A 的 10 米范围保留，A 不起 CD |
| 普通 B 交换 | 当前活着、同房/代际/真实实例、非 spawn 的普通/精英敌人，与 A 或 B 有原身体接触者 | Boss 在生成计划前排除，不形成“Boss 应去的点”，也无 Boss 替身/交换伤害 |
| 单侧为空 | 有人一侧每个合格对象的对侧相对位置 | 不是挑一个目标，也不是跳过非法对象 |
| 两侧重叠 | 每个实际对象仅一项；最近中心归侧，等距归 A | 目标 `to = original + destination_center - origin_center` |
| H11 已启用 | 加入接触画幅的自身与已注册、存活的友方英雄，半径用现有 hero_radius | H11 不移 Boss；友方位移不伤害、不凭空获盾/治疗/无敌 |
| H11 未启用 | 自身、友方没有必需落点 | 不因其假想非法落点拒绝敌人的交换 |
| H12 返回 | 只取初次实际移动且仍存活、原实例仍有效的原成员；目标是其保存的 `original` | 离开画幅的活原对象仍回来；新来者/同 ID 替换对象/已死亡者不加入、不复活 |
| 空合法交换 / 同中心 | 空计划正常完成；同中心成员按现有计划存在但不产生位移伤害 | 原候选逐项检查计划，包括零位移项；本次审计没有另改这个约定 |

B 的 `plan` 在写位置前一次生成并全量预检，然后所有位置同步提交，再发回调/伤害。H12 也先全量预检再同步提交。B/H12 都复用 A 的原 cast_id，H12 无新 E 伤害、无新 CD、无新 on-cast；E3 伤害阶段在 H12 窗口结束之前已完成。

原分支用例来源：`candidate03/finite_gate.gd` 的 `test_placement_cd`、`test_frames_swap`、`test_overlap_empty`、`test_h11`、`test_h12`、`test_identity`（约 130–245 行）。Boss 正例在 152–168 行，H11 不覆盖 Boss 在 192–203 行。

## 3. 最小边界改动在哪里

现有 `_e3_preflight(plan)`（`candidate03/ink_e3_sim.gd:171`）由 B 预览/提交、H12 预览/提交四处共用。当前顺序为：目标点非法拒绝、起点非法拒绝、只要静态障碍数组非空便拒绝、只要有效 Q3 山存在便拒绝。这是旧 clear-space fixture 的诊断边界，已不适合作为最新有效生产规则。

下一独立边界候选最小玩法改动可集中在这一方法：

1. 保留既有完整 plan 和原子提交顺序；只检查实际合格成员的必需目标，不以路径穿墙、场内存在无关障碍、原点本身非法为额外拒绝条件。真实实例/房间/存活检查仍保留在原计划/时序方法中。
2. 静态墙/房界继续复用 `_e3_point_legal(entry.to, entry.radius)`（161–169）：有限点、按自身身体半径收缩边界、障碍按身体半径膨胀。不得改成 `_move_clipped` 路径扫掠、投影到附近点或借 E2 规则。几何 EPS、相切口径是制作实现，不是用户给出的精确数字。
3. 活 Q3 山不在 `obstacles` 中，不能仅删“全场 mountain 拒绝”就声称落点全部合法。原 Q3 ¶71 只阻挡普通敌人移动、不阻挡玩家；现实现 `_q3_terrain_contact` 也按 `ordinary(actor)` 过滤。新预检需逐项对实际被山阻挡的成员检查目标和山体几何，保留玩家/精英的现有通行例外。可在 `_e3_preflight` 内做 entry-aware 检查，或单独小 helper；不应把所有 H11 友方都改为被山阻挡。已有 `MountainGeometry.overlaps` 是圆/定向矩形几何；不得用路径进入查询把允许隔山的交换又挡住。
4. B 和 H12 自动共用同一 all-or-none 规则。任一目标非法时，演员位置、伤害包、阶段、CD、H12 consumed 均不提交；保留当前原窗口。只取消当前返回，不能撤销已经成功的 B。
5. 新后继应绑定 10-06 决定，并把合法/非法落点诊断改成正式当前玩法结果；旧的 `source_gameplay_outcome:false` / `*_outside_fixture` 不能继续当现行说明。旧冻源、旧测试断言和旧回执保持原样。

原 `candidate03` float32 B 中心上限修复必须保留：`_e3_centers_in_range`（82）将来源上限转成同一 Vector3 float32 表示，再比较实际距离，不加全局 EPS，不缩点，不改标量伤害曲线。该修复和新墙体规则是不同问题。

旧墙/山用例不能直接成为新正确答案：`finite_gate.gd:test_lifecycle`（262–269）含目标墙内拒绝和“两端合法、中间有墙则 outside_fixture”；后者在新候选应被新用例证明允许。`tests/ink_e3_independent_20261005/revision03/independent_gate.gd:56–88` 的两个山体隔离组也只证明当时限制被遵守。

建议下一小门槛只围绕新增差异：两端合法隔墙成功；多对象一个非法时全体零提交；房界身体半径；Boss/H11 资格正确影响落点集合；Q3 只对原阻挡对象检查落点；H12 新增障碍导致全体拒绝且原 B 不撤销；移除阻挡后在原窗口内重试；原 A 到期/CD 与 float32 上限不回退。这里仅列来源驱动的验证需要，没有新写测试或宣称通过。

## 4. 真实已有通过 / 红 / 未验

| 版本与归档 | 本次只读核实 | 准确边界 |
|---|---|---|
| E3 candidate02，`tests/ink_post_wip43_actual_20261005/ink_e3_actual_0518` | 作者 raw：339 检查，3失败、仅 15/16 组，rank3 10.6 被拒并随后空数组索引 SCRIPT ERROR；strict FAIL 保留 | 真实红，不是墙/房界问题 |
| 同 candidate02 独立 revision02 | raw 78/6 通过，但 strict 仍失败：旧 run_entry KeyError | 不能把 raw 绿升级为严格完整通过 |
| E3 candidate03，`tests/ink_post_wip43_actual_20261005/ink_nav_actual_0539` | 作者 raw 515/16、独立 raw 78/6；strict 310/286 全通过；两进程 exit0/reaped，1.121 / 0.639 秒；原始 raw 无脚本/引擎错误 | 独立清空场景 E3/H11/H12；包含 12 个 rank3/rank5 axis/diagonal float32 邻点观察；未覆盖新跨墙规则、普通接入或当前 P1 |
| Q2-over-E3 candidate01 | `tests/ink_q2_e3_composition_independent_20261005/candidate01_review.json` 保存源审查缺陷 | 预排普通河流终点触碰在后发同刻瞬移后未失效，不能接受 |
| Q2-over-E3 candidate02，`tests/ink_q2_e3_composition_20261005/main_actual_candidate02_0647` | raw/report 96/7，strict 311 全通过；exit0/reaped，0.861 秒，无引擎错误 | 只过七组组合接缝；H04 瞬移采样和 E3 障碍继续 HOLD，P1 仍仅 Q3/E1/E2 |

E3 两份 raw、两份 exit、两份 strict 的归档 SHA 本次逐项与 `tests/ink_q2_e3_composition_20261005/candidate02/upstream_evidence.json` 完全匹配。推荐目录 `ink_e3_actual_0538` 不是实际通过的记录目录；`stage_handoff_candidate03.json` 的 NOT_RUN 是当时作者交接状态，不能覆盖之后真实 `ink_nav_actual_0539`。

准确绑定：E3 candidate03 `251731c37bcbaf7b526c8b45609da5f541b0376995f19de17a63ff805b7de28a`；Q2/E3 candidate02 `04f7e1c388e16f4885555085776944da1918612a200849213e2a285a4c18bce6`。本次没有把这些旧绿升级为新边界或当前普通组合的绿。

## 5. 当前普通链与 P1 必要兼容

当前生产 `scripts/integration/yanguizhou_first_floor.gd` 第一行指向 `tests/ink_e2_boundary_20261006/ordinary01/text01/host.gd`；text01 的 `live_binding.gd:6` 仍精确要求 `ordinary01/sim.gd`，text01 只改展示。Sim 当前 SHA：`e4e380b798fc20c609bd25eb6e560cb63e1a0fbd4ab76dae4a6ce63386f6d107`。

普通玩法链：ordinary01/sim → e2_boundary → e2_remainder → e2_base → 当前 P1 lifesteal → P1 sim/settlement → R1 → 普通 E1 → Q2 fix01 → Q3 fix02 → 原 Q1/common/core。普通能力 Q1/Q2/Q3/E1/E2/P1/R1，原十个 Hex hook；H11/H12、H03/H04 未因本审计打开。主开发的 P2 是后续独立工作；E3 将来应以届时已验收的真实普通叶子为基线，本文不替 P2 写机制或提前冻结其未完工落点。

不能整层拿旧 `p1_over_composed_sim.gd` 覆盖当前链：它的 P1 范围只有 Q3/E1/E2，会丢当前 Q1/Q2 的真实完整批次与补伤吸血等修复。也不能只把 E3 extends 改到普通 Sim 就声称组合完毕：当前整条普通链没有 `_qe_*` 瞬移观察。旧 Q2/E3 candidate02 已通过的实际断点、半开连续腿、预排普通触河失效和真实到达即触河接缝必须在新链明确保留/重接。

相关源：旧 `q2_over_e3_sim.gd` 的 `emit_event`（268）、`_e3_return`（644）、`_qe_observe_exchange/return`（652/656）、`_qe_record_jumps`（662）、`_qe_motion_legs`（692）、`_qe_queued_river_current`（722）与 `_qe_split_prior_traces`（734）。保留旧源码层整包重叠会覆盖当前 Q2/P1 solver 入口修复，宜做明确方法差异合成并验证；不能新增第二个 common 实例、世界步进或伤害通道。

P1 对 E3 的新接入需要的是同一 collector 的完整原根归属，不能只放宽字符串：

- A 接受时原 `new_cast("e")` 只建一个 E3 root；B/H12 使用原根。可参考 ordinary01 对 E2 的 `new_cast` 扩展，保留原 P1 快照值与同 owner/room/generation 验证。
- 在真实 `first_placed` 绑定准确 `ink_frames` 对象/frame_id。每个合格 E3 `swap_damage` 必须与 `_e3_packets[effect_id]` 的原 state、原 enemy、cast_id、房间、代际对应；排除伪造终端/包、BASIC、R1、Hex 派生、P1 自补伤。
- 真实普通伤害仍交给当前 `damage_enemy` → 已提交 damage 事件 → 同一 P1 collector。单目标补伤基数是实际结算量，不读回调后的 HP 差，也不重放伤害。
- 只有真实 `_e3_finish_damage` 的完整批次完成才能 `p1.complete`，并持有现有 enter/leave 屏障直到当前真实批次/终端通知退出。`finish_cast`、A 超时、`release_completed`、第一个命中或随意发同名事件均不构成 P1 付款凭据。可以参考当前 E2 的 terminal frame 绑定方式；E3 完成时 state 可能已从 `ink_frames` 移除，不能仅用 `_e3_live` 来否定真实终端。
- H12 仅保留位置状态，不延迟 P1 到 2 秒窗口结束、不再建根/再付款。空交换不符合单敌；双敌拒绝单敌奖励；中途暂停不能提前付款。A 到期或真正取消需清除未付款的 E3 collector 归属，不形成成功完成。
- 使用现有 P1 原子 HP/CD/死亡提交和 `lifesteal01` 的已提交补伤回调，仅增 E3 合法来源；不新建吸血/生命权威。当前 `_p1_lifesteal_source` 范围未含 E3，必须明确接入而非假定继承即生效。

普通路由还须继承当前 E2 的真实 E-down/up、暂停菜单后 release-required，以及 E1 隐藏房间 release 的处理，不能换回旧 E3 独立 input_adapter 整层回退。新普通 Binding/Session/Bridge/selector 需要独立精确身份与源闭包，不能放松旧绑定的 script/path/hash 限制。本文不授权或执行这些普通入口更改。

## 6. 本次停止点

已完成来源/原文/旧实际回执/最小方法与组合风险盘点。新边界候选、当前链 E3+Q2、当前 P1-E3、普通 E3 输入/展示和整层实际运行均未制作或验证。先做独立边界差异，再在当前完整普通链自然空档接入；不扩大技能或 Hex 选择范围。
