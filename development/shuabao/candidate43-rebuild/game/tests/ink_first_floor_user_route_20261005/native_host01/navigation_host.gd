extends "res://tests/ink_first_floor_user_route_20261005/native_host01/host.gd"
## Explicit optional source-navigation composition, separate from Q1 view seals.
const NavigationInstaller = preload("res://tests/ink_enemy_navigation_fix01_20261005/install.gd")
const NAV_ROOT := "res://tests/ink_enemy_navigation_fix01_20261005/"
const NAV_BINDING_SHA := "fb2de3efceb2bc59ae5cf5b357b05b2165a97f2c791dcf88a9373dd050ef0dc0"
const NAV_INSTALLER_SHA := "0e283319f8aed01a9f8342e4cc95aa995cc94b7576d45c1c296ec7866f16c469"
const NAV_DIRECTOR_SHA := "e35db36237772a3ba1ef6ed149869d61e9d5340ec96ecab37ab1055be352f21f"
var navigation_installation: Dictionary = {"accepted":false,"reason":"not_attempted"}
func _install_source_navigation() -> Dictionary:
 return NavigationInstaller.apply_to_fresh_ink_sim(sim)
func _start_encounter() -> void:
 var fresh: bool = shop_session == null
 super._start_encounter()
 if not fresh: return
 if sim == null or not startup_session_error.is_empty() or not floor_error.is_empty(): return
 if not flow_installed or not flow_install_source_equal:
  navigation_installation = {"accepted":false,"reason":"complete_original_Q1_install_required"}
  floor_error = "navigation_requires_original_Q1_install"; _pause(true,"navigation_install_fail_closed"); return
 if FileAccess.get_sha256(NAV_ROOT+"source_binding.json") != NAV_BINDING_SHA or FileAccess.get_sha256(NAV_ROOT+"install.gd") != NAV_INSTALLER_SHA or FileAccess.get_sha256(NAV_ROOT+"enemy_director.gd") != NAV_DIRECTOR_SHA:
  navigation_installation = {"accepted":false,"reason":"navigation_source_identity_mismatch"}
  floor_error = "navigation_source_identity_mismatch"; _pause(true,"navigation_install_fail_closed"); return
 var before_flow: PackedByteArray = _flow_source_seal()
 var before_source: PackedByteArray = var_to_bytes(sim.snapshot())
 var before_ledger: PackedByteArray = var_to_bytes(shop_session.ledger.model.snapshot())
 var before_rng: int = sim.rng.state
 var before_director: String = sim.enemy_director.get_script().resource_path
 var installed: Dictionary = _install_source_navigation()
 var preserved: bool = before_flow == _flow_source_seal() and before_source == var_to_bytes(sim.snapshot()) and before_ledger == var_to_bytes(shop_session.ledger.model.snapshot()) and before_rng == sim.rng.state
 navigation_installation = {"accepted":installed.get("accepted",false) and preserved,"installer_result":installed.duplicate(true),"source_ledger_flow_data_and_rng_preserved":preserved,"director_before":before_director,"director_after":sim.enemy_director.get_script().resource_path,"intentional_director_replacement":installed.get("accepted",false),"binding_sha256":NAV_BINDING_SHA,"installer_sha256":NAV_INSTALLER_SHA,"director_sha256":NAV_DIRECTOR_SHA,"separate_from_Q1_presentation_seal":true,"native_passed":false,"full_floor_passed":false}
 if not navigation_installation.accepted:
  floor_error = "navigation_install_or_data_seal_failed"; _pause(true,"navigation_install_fail_closed")

func _session_scope() -> String:
 return super._session_scope()+"\n显式选装导航候选；源数据/RNG封存独立记录，非整层导航验收"

func user_route_report() -> Dictionary:
 var report: Dictionary = super.user_route_report()
 report["host_variant"] = "explicit_navigation_candidate"
 report["navigation_candidate_installed"] = navigation_installation.get("accepted",false)
 report["navigation_installation"] = navigation_installation.duplicate(true)
 return report
