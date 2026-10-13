# 011 map-edge and reconnect constraints — source check 2026-10-05

Originals: authorities/originals/cehua.docx and shuzhi.xlsx. Paragraph numbers below are direct DOCX body paragraph ordinals, not page numbers. No original file was changed. This note records requirements and implementation gaps; it does not add rules or claim runtime acceptance.

## Full body at map edges
- cehua P53: “人物的完整碰撞体到达已生成地图边缘时停止向外移动，仍可沿边界切向移动”
- Same paragraph covers ordinary movement, dodge and forced displacement; no wrapping, transfer to another planet or added damage.
- P85 expressly scopes the nonrotating AABB to player-versus-player collision only.
- shuzhi 63_移动能量!A10/C10 gives renwu_pengzhuang_zhijing=0.65cells; half extent/radius0.325 is derived by division. F10 says not to infer collision from sprite transparency.
- P53 does not uniquely select the environmental circle or auxiliary peer AABB. P148's explicit complete-person AABB belongs to bed respawn; P112's complete visible body belongs to mechanical summons. Neither can silently redefine ordinary player edge geometry.
- Root direction is to retain the current environmental circle and peer0.65AABB; check the entire registered environmental body, never its center alone or a smaller body. A future formal shape choice is not being declared here.

Current actor_space returns MAP_BOUNDARY_CLIP_REQUIRED for a requested end outside the full environmental circle; controller treats adapter failure as fatal. This must become legal bounded movement, not a world shutdown when a player touches the edge. Directly adding only a circle contact normal is insufficient: an exactly tangential line from a circle boundary is outside at every positive time, so the existing planar solver can enter a zero-time/no-progress loop. A post-move clamp or per-player pre-move is also invalid because it can skip wall/peer sweeps or alter the common collision timeline. The integration plan must retain the first collision TOI and certify any subsequent feasible motion in the existing simultaneous candidate loop.

## Reconnect nearest legal placement
- P421: “上线时优先恢复原位置；父级已经不存在或当前状态不再允许恢复时才回重生点”
- P426: “上线恢复原坐标；格子后来被占时从原点寻找最近合法位置”
- shuzhi 134_离线锚点!C2: “恢复原地图层+原局部坐标；被占用则从原点向外找最近合法位置”; D2 has no special fallback and E2 removes offline active colliders.
- A legal original location must be restored exactly before searching. Occupancy alone must not select the first spawn anchor, transfer layer/body or be equated with a missing parent.
- No reconnect-specific distance metric, grid-center restriction, step, candidate count, maximum search radius, precision, tie order or exhausted-search fallback was found when checking all148workbook sheets. “格子后来被占” does not say only cell centers are legal.
- Radius400/diameter800 in42_天体物理总表!B81:D82 is a map size, not a reconnect-search radius. Bed-side3cells in133_死亡恢复掉落!A22:C22/P148, vehicle-disembark outward searches and shaft/elevator nearest-grid rules are separate mechanics and cannot be borrowed as reconnect defaults.

Root direction: nearest placement is measured from the original location, with deterministic candidates and counterexamples first. Any finite geometry/candidate implementation must state its actual search domain and guarantees. Unmaterialized terrain remains unknown, not free space; a budget-limited failure is not permission to teleport to a respawn point. Current ACTOR_RECONNECT_PLACEMENT_UNRESOLVED remains an explicit gap until that placement path is implemented and verified.

## 2026-10-06 limited boundary resolution
The former requested-end-only fatal gap is now addressed in the technical joint solver/controller path: first circle TOI, bounded certified chords, retained wall/peer constraints, and full native commit certification. Actual repairedJoint53+NativeCircle3 pass and priorSession26/Space13 pass are recorded in the reconstruction runtime report. Full generated terrain and complete runtime gameplay coverage remain unverified; this does not close reconnect placement.
