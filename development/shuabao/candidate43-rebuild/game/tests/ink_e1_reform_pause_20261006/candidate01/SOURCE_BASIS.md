# Exact source basis and necessary method copy

The leaf inherits `tests/ink_p2_ordinary_20261006/mechanism01/sim.gd`, SHA256 `ebc5c843c72b7da04516299b43d809fceee1df7e26fbb28d085e7fea7e8288bb`. It does not inherit or alter the concurrent P2 ordinary successor.

The old E1 source is `tests/ink_e1_ordinary_20261005/candidate01/rain_layer.gd`, whole-file SHA256 `edc57d814e8acf757dfc9f056ba5c77854fa2996481d01bd73cf0eb16d8cb32d`.

The only original method whose behavior must be copied into the new continuation is `_e1_reform`: its snapshot/detachment/impact setup and its final receipt. The original method is synchronous and exposes no continuation seam, so calling `super._e1_reform` would irrevocably pre-claim missing packets and finish them. No whole source layer or world-step implementation is copied. `_e1_damage_batch`, damage/guard/common/equipment/P1/P2 packet capture and identity admission stay inherited.

SHA256 for each exact method text is measured from `func NAME(` up to (but excluding) the following `func`, retaining the intervening newline:

| Source | Method | SHA256 |
| --- | --- | --- |
| Original rain layer | `_e1_reform` | `1c86a98795a2163cffdde7834e819534dc58bd356c1bee8364b6e06d84a9142a` |
| Original rain layer | `_e1_damage_batch` | `13193865fd0016e7631d12271dd2df5d4d40fe679607c30546f7f26adbd9b7fc` |
| P2 mechanism Sim | `_e1_reform` | `b07d69176b9541acbffed76a504c8145b9d5e340df0f742bc04a83b31fa651b8` |
| P2 mechanism Sim | `_e1_damage_batch` | `36e23eea54a806e080e539f016d382f8a69572ee4c1d41ad48e6b52552cf157e` |
| P1 ordinary settlement | `_e1_reform` | `2a61b72a6e28d2a7de2edd430bbf7ec7d08b35908bb3658a3c2da9e2b1cd074e` |

The last two ancestor reform wrappers cannot be invoked via `super` without also invoking the broken original method. Their essential whole-reform guards are therefore explicitly reproduced: P1 enters before outward reform/contact/terminal callbacks and leaves/flushes only after that drain; P2 pushes the original E1 source-time/origin frame before dispatch and pops only after the original terminal. A pending-queue predicate spans pauses without pretending that a source call stack is still active. The inherited P2 per-batch frame remains present inside each unchanged single-target `_e1_damage_batch`.

Two original snapshot arrays are retained, rather than combined/re-sorted or recalculated on resume. Stage zero is every saved radius target in the existing `circle_targets` order; stage one is every original matching marked identity in that order. `at`, `origin`, base/bonus amounts, shared impact snapshot and the terminal receipt's original `finished_at` remain fixed. Actual dispatch can reject a retired/replaced identity via the inherited method. Actual contact `settled_at` remains the submission clock; no source/world clock is rewound.

`source_binding.json` pins the 64 runtime source/data dependencies separately from the new files. Local checkpoint01 captured the original bytes before edits but followed excessive archival references; it is retained only as local history. Narrow checkpoint02 contains the new candidate bytes and dependency hashes, without project/frontdoor/assets or transitive old evidence copies.
