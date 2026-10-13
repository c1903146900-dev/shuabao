# 当前普通链 E3 / P1 最小组合

状态：SOURCE_ONLY_NOT_RUN。新普通源接线已制作；没有引擎、导入、CUA、原生输入、自然流程、完整首层或美术验收。

## 实现边界

- e3_base.gd 仅将独立 candidate03 E3 本体父类改到当前 E2/P1/R1/E1/Q2/Q3/Q1 Sim，保留当前 R1 导演和导航。既有 ExchangeCommon 继承同一 BoatCommon，最后只有一个 live common。
- q2_jump_seams.gd 只接实际 E3/H12 跳变、半开连续腿、原对象预排触河失效和真实到达触河。不替换当前 P1/Q1/Q2 solver、整批调度、补算吸血或 E1/R1 的事件递送，不增加世界步进。
- e3_boundary.gd 转接实际已验的独立边界规则：隔墙允许，所有必需落点原子预检；Boss 和 Q3 地形通行类别例外保留。
- sim.gd 将 A 的唯一原根、准确 frame 对象和每个真实 swap_damage 包接到原 P1 collector。完整真实 terminal 通知退出后才结算，沿用 B09 已提交补伤吸血。A、超时、空交换、伪 terminal 不提供单敌付款；H12 不建新 root，不重复付款。
- Catalog 只在当前 Q1/Q2/Q3/E1/E2/P1/R1 上新增 E3。H11/H12 的机制仅回归，不开放普通选择；P2/P3、H03/H04 等未接范围保持关闭。
- 真实 E-down/up 两次放 A/B；Q/R 预瞄和已占用鼠标输入不被抢走。菜单保留原窗口并冻结时钟，要求实际松 E 后再次按下。沿用 E1 隐藏房间 release 所有权。
- 同一 Session、Bridge、Model、生命、钱包和导航；原休息回满生命、清暂态 Buff/CD、不补基础瓶不改。
- 临时 A/B 圆、真实窗口/CD、普通学习和当前能力文案都走新精确 Binding。生产仅改变 host 首行和 chooser 文案工具引用；两者 preimage 已保存。

## 验证入口

1. python tests/ink_e3_ordinary_20261006/ordinary01/verify_source.py
2. python tests/ink_e3_ordinary_20261006/ordinary01/stage_delta.py --dest EXISTING_CURRENT_STAGE --apply --receipt OUTSIDE_SOURCE.json
3. 外部受控引擎运行 parse_gate.gd 和 finite_gate.gd。有限门报告位置使用 INK_E3_ORDINARY_REPORT，另保存 raw 输出、exit=0/reaped=true 进程回执。
4. raw_error_gate.py 必须验证准确 binding、7 个 raw group 必达标记、完整 report 一致和无脚本/引擎错误。

只验受影响七组，不重复历史 231 / 126 / 85 全矩阵。历史回执不升级为新组合或原生通过。source_checkpoint01 是先行核心保护快照，其 SOURCE_ONLY 状态和字节永久保留；最终工作源可含后续精确修正。
