extends RefCounted
## Authored layer animation resource interface, not a supplied artwork pack.
const SLOTS := ["front", "right", "rear", "left"]
const ACTIONS := ["idle", "basic", "q1_draw", "q1_hold", "q1_release", "q2_place", "q2_corner", "q2_release", "q2_aim", "q3_raise", "q3_collapse", "e1_enter", "e1_reform", "e2_launch", "e2_board", "e2_return", "e3_place", "e3_exchange", "e3_return", "r1", "r2", "dash", "hit", "death"]

static func finite_number(value: Variant) -> bool:
    return (value is float or value is int) and is_finite(float(value))

static func numbers(value: Variant, count: int) -> bool:
    if not value is Array or value.size() != count:
        return false
    for item: Variant in value:
        if not finite_number(item):
            return false
    return true

static func validate(data: Dictionary) -> String:
    if data.get("schema") != "hero2d-authored-layers-1" or not finite_number(data.get("height_m")) or float(data.height_m) < 0.25 or float(data.height_m) > 4.0:
        return "invalid_schema_or_height"
    if not data.get("textures") is Dictionary or not data.get("slots") is Dictionary:
        return "missing_textures_or_slots"
    for slot: String in SLOTS:
        var view: Variant = data.slots.get(slot)
        if not view is Dictionary or not view.get("lower") is Dictionary or not view.get("upper") is Dictionary:
            return "missing_view:" + slot
        for action: String in ["idle", "run"]:
            var error := _clip(view.lower.get(action), data.textures)
            if not error.is_empty():
                return slot + "/lower/" + action + ":" + error
        for action: String in ACTIONS:
            var error := _clip(view.upper.get(action), data.textures)
            if not error.is_empty():
                return slot + "/upper/" + action + ":" + error
        var rain_error := _clip(view.get("rain"), data.textures)
        if not rain_error.is_empty():
            return slot + "/rain:" + rain_error
    return ""

static func _clip(value: Variant, textures: Dictionary) -> String:
    if not value is Array or value.is_empty() or value.size() > 120:
        return "invalid_frame_count"
    for frame: Variant in value:
        if not frame is Dictionary or not frame.get("texture") is String or not textures.has(frame.texture):
            return "unknown_texture"
        if not numbers(frame.get("rect"), 4) or not numbers(frame.get("uv"), 4):
            return "invalid_rect_or_uv"
        # Rect uses normalized character-height units; y=0 is the planted sole.
        var rect: Array = frame.rect
        var uv: Array = frame.uv
        if rect[2] <= 0.0 or rect[3] <= 0.0 or absf(rect[0]) > 2.0 or absf(rect[1]) > 2.0 or rect[2] > 4.0 or rect[3] > 4.0:
            return "invalid_frame_bounds"
        if uv[0] < 0.0 or uv[1] < 0.0 or uv[2] <= 0.0 or uv[3] <= 0.0 or uv[0] + uv[2] > 1.0 or uv[1] + uv[3] > 1.0:
            return "invalid_uv_bounds"
    return ""

static func frame_at(clip: Array, progress: float) -> Dictionary:
    return clip[mini(clip.size() - 1, int(floor(clampf(progress, 0.0, 1.0) * clip.size())))].duplicate(true)

static func sample(data: Dictionary, plan: Dictionary, slot: String) -> Dictionary:
    if not SLOTS.has(slot) or not data.slots.has(slot) or not numbers(plan.get("position"), 3) or not finite_number(plan.get("progress")) or not finite_number(plan.get("gait_phase")):
        return {"accepted":false, "reason":"invalid_sample"}
    var view: Dictionary = data.slots[slot]
    if plan.get("form") == "rain":
        return {"accepted":true, "frames":[frame_at(view.rain, fposmod(float(plan.gait_phase), 1.0))]}
    if plan.get("form") != "hero" or not ACTIONS.has(plan.get("upper")) or not ["idle", "run"].has(plan.get("lower")):
        return {"accepted":false, "reason":"uncovered_action"}
    if plan.upper == "death":
        return {"accepted":true, "frames":[frame_at(view.upper.death, 1.0)]}
    var lower_phase := float(plan.gait_phase) if plan.lower == "run" else 0.0
    return {"accepted":true, "frames":[frame_at(view.lower[plan.lower], lower_phase), frame_at(view.upper[plan.upper], float(plan.progress))]}
