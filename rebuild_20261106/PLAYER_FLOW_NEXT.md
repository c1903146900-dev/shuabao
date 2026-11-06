# Player guidance iteration

Frozen overlay: flow_next. It supersedes flow_changes only when explicitly included by build.py <new candidate> flow_next; earlier passing motion_rebuild01/Windows ZIP remain untouched.

Specific gaps fixed without changing difficulty or source transaction rules:
- Closing the map while still standing in the exit requires stepping out and back in. The objective now explicitly says to move down out of the exit then up to reopen, instead of continuing to tell the player to walk upward.
- Rejected shop/transition actions previously disappeared silently. Existing source rejection reasons now produce a four-second readable explanation. Pause state takes priority over that transient notice.
- A first skill point is explained in preparation, before entering combat. Combat guidance recommends pausing before reading skill choices. No extra points, auto-learning or free purchases are introduced.
- Paused learning guidance appears only when SP is available; otherwise it only explains resume. Objective text has a dark outline for readability over scenery.

New normal Boot/UI event test playerui04:11 checks PASS,12.2107 guard seconds, exit0/full cleanup. It exercised actual E learn control and E2 candidate, SP1→0, exit-map close/reenter, combat-shop refusal still enforced but explained, and Esc pause taking priority. AI,HP,damage and gold were not injected. playerui02/03 earlier passes retained; final04 includes conditional SP text and outline. Four actual rendered frames were inspected for readability/obstruction. Event regression is not manual OS validation, human full-floor success, Windows acceptance, or balance evidence.

This guidance overlay has not yet been combined with the next animation polish. The prior full-floor normal-combat pass belongs specifically to motion_rebuild01.

The public test copy saves screenshots under `user://player_ui_*.png` rather than an executor-specific path. Screenshots and raw logs are not included.
