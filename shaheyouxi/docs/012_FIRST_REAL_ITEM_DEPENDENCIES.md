# First real inventory item: source-backed dependency boundary

Read-only original-source check, 2026-10-08 UTC. This is a plan, not implemented gameplay. No starting gift was found: cehua P129 and shuzhi 62_人物基础 C10/C12 specify capacity only. Technical fixture items must never be used as ordinary new-world grants.

## Smallest legal source path

- cehua P86: point at an in-range resource and hold left mouse; empty hand or a tool gathers, a weapon attacks. F is not gathering.
- shuzhi 20_挖掘 C2/C3/C13: interval 0.3 seconds, unarmed damage 0.5, ordinary tree durability 3. Six valid settlements are required. The first settlement's timing is not established here; do not claim exactly 1.8 seconds.
- 63_移动能量 C13: range 5 cells. C19 and cehua P199: interruption longer than 1 second resets gathering progress and fracture mask. Do not replace this with immediate release reset or the building-demolition wording at P196.
- cehua P301; 24_植物 A14/F14/H14/I14/J14/T14: tree_putong, any growth stage yields random 3–5 mucai; mature trees additionally yield random 0–1 seed_shumu. Natural trees are mature and do not naturally respawn. 06_基础主材 B2/N2: wood stack999. 24_植物 Q14: tree-seed stack99.
- Tree H1, 1×1 logical anchor; 24_植物 U14:X14: collision offset(0,-0.12), size(0.76,0.3) cells. P301 requires visible-trunk collision, not a full-cell wall.
- cehua P142–143; 133_死亡恢复掉落 C5: lifetime300 gameplay seconds. 63_移动能量 C14/C12/C16: delay0.5 seconds, pickup radius3 cells, attraction8 cells/second. Nearest eligible player wins, stable player identity breaks ties. Transfer only on arrival, hotbar first then bag; excess stays in world. Save remaining lifetime/protection rather than restarting timers.
- P52/P683: persistent instance identity and no duplication on retry/reconnect/reload. Tree content/instance, drop content/instance and harvest-completion event are distinct identities. Spawn body is xingxing_03/body_0001, celestial_local/surface/depth0.
- sucai 全部素材技术清单 C657/E657/V657: tree entity/tree_putong and trunk-center drop location; C1650/E1650: mucai icon; C1815/E1815: seed_shumu icon. A tree is not itself an inventory item.

## Missing implementation dependencies

1. Lock source projections for tree, wood and seed. Seed is currently absent from inventory012 whitelist.
2. Establish legal generated tree instances/positions with persistent IDs. 24_植物 D14/E14 refer to world generation rules; this check did not establish natural-tree density or a starting-tree position. No invented spawn gift/tree placement is authorized by these cells.
3. Add held/released left gathering input and authoritative aim/layer/range/hand validation, settlement and interruption tracking.
4. Atomically remove a tree once and create every allowed randomized drop once.
5. Implement delay/attraction/capacity and atomic world-drop-to-inventory transfer.
6. Persist tree removal, world drop remainder and inventory together; reopen cannot resurrect the harvested tree or duplicate its output.

Current source: inventory Core only creates empty players and transports existing items. actor_command accepts dodge/interact, sampler has no gathering command; surface_approach_rules marks trees technical_disabled. prefab_instantiator has ID/layer patterns, but no harvest system. layout_validator's permanent changes only cover underground ordinary-rock removal. No real gathering/world-drop/pickup implementation was found. These must not be bypassed with trusted_restore as a grant.

Current next step remains the explicitly labelled inventory fixture UI/save loop; an ordinary new world has empty inventory. The four user policy choices were confirmed on 2026-10-08 07:14 UTC; see 012_CONFIRMED_INVENTORY_POLICIES.md. Their unimplemented ground behavior remains gated by implementation, not missing user decisions.
