# Ordinary P2 parse fix01: test-only successor

Actual original parse failed before any finite execution: the test declared Projection, a Godot built-in type, and called get_base_script directly on the Production preload class constant. Both original failures and source_checkpoint02 remain unchanged.

The new finite test renames only that helper to P2HudProjection and loads a real Script resource into production_script before inspecting get_base_script/resource_path. Every original check/near callsite remains. No gameplay, Host, Session, Catalog, UI, production adapter or runtime admission code changes.

The repaired parse gate loads the same candidate scripts and the new finite test path instead of the frozen failed test. Runtime composition remains bound to ordinary01/source_binding.json (6847fc2c3bcb41646198279ff6d48c14bd363b993509b657cab44fb5297869c8). This separate test binding records every before/after test hash and requires both test and runtime identity in actual reports. Stage application adds distinct fix01 paths; it does not overwrite failed source or historical checkpoints. The original reviewed production aliases remain unchanged in the map; no additional production mutation is introduced.

verify_source.py extends the existing preflight, without creating a framework. It checks const/var names against Godot value built-ins and common base engine names, and rejects direct get_base_script/can_instantiate/resource_path access on every preload("*.gd") class constant. Its built-in negative check must reject the two exact original defects and then accept all active scripts in the new parse list. Actual Godot parse/finite remain coordinator-only and NOT_RUN by this author.

Run verify_source.py → stage_delta.py --dest <stage> --apply --receipt <receipt> → fix01/parse_gate.gd → fix01/finite_gate.gd -- --p2-ordinary-result=<fresh-report> → fix01/raw_error_gate.py. Five groups and every original assertion remain mandatory. The known legacy E1 original-damage callback-pause issue remains outside this test-only repair.
