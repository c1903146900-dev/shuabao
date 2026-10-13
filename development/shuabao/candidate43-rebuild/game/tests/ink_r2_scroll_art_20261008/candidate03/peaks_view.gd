extends Node3D
## Opt-in ordinary R2 artwork. Only detached source packets reach these views.
const PeakArt = preload("res://tests/ink_r2_scroll_art_20261008/candidate03/peak_art_view.gd")
const RegionArt = preload("res://tests/ink_r2_scroll_art_20261008/candidate02/domain_scroll_view.gd")
const Placement = preload("res://tests/ink_r1_ordinary_20261005/candidate01/ordinary01/domain_view.gd")
var ink_view: Node3D
var region: Node3D
var placement: Node3D
var peak_samples: Array = []
var display_report: Dictionary = {}
var preview_sample: Dictionary = {}

func _ready() -> void:
 set_process(false)
 set_physics_process(false)
 _ensure_resources()

func _ensure_resources() -> bool:
 if not is_instance_valid(ink_view):
  ink_view = PeakArt.new()
  add_child(ink_view)
 if not is_instance_valid(region):
  region = RegionArt.new()
  add_child(region)
 if not is_instance_valid(placement):
  placement = Placement.new()
  add_child(placement)
 return ink_view._ensure_resources() and region._ensure_resources()

func present_source(ink_snapshot: Dictionary, preview_dictionary: Dictionary = {}) -> void:
 if not _ensure_resources():
  reset_visuals()
  return
 var detached: Dictionary = ink_snapshot.duplicate(true)
 ink_view.present_source(detached, {})
 region.present_source(detached, {})
 # Retain the original uncommitted placement renderer. The detached copy has
 # no committed snow domain, so it cannot draw the retired diagnostic circle.
 var preview_source: Dictionary = detached.duplicate(true)
 preview_source["snow"] = {}
 placement.present_source(preview_source, preview_dictionary.duplicate(true))
 peak_samples = ink_view.peak_samples.duplicate(true)
 display_report = region.presentation_snapshot()
 preview_sample = placement.preview_sample.duplicate(true)

func receive_source(event: Dictionary) -> void:
 if is_instance_valid(region):
  region.receive_source(event.duplicate(true))

func reset_visuals() -> void:
 if is_instance_valid(ink_view): ink_view.reset_visuals()
 if is_instance_valid(region): region.reset_visuals()
 if is_instance_valid(placement): placement.reset_visuals()
 peak_samples.clear()
 display_report.clear()
 preview_sample.clear()

func presentation_snapshot() -> Dictionary:
 return {"peaks":ink_view.presentation_snapshot() if is_instance_valid(ink_view) else {},
  "region":display_report.duplicate(true), "placement":preview_sample.duplicate(true),
  "visual_tail_seconds":0.0, "art_accepted":false}

func _exit_tree() -> void:
 reset_visuals()
