extends RefCounted
## Read-only presentation geometry for the fixed UI012 carry Label and its two
## decorations. It never writes a Node, reads Input, or emits a gameplay intent.
## Label character bounds are shaped advance/line-height boxes, NOT exact ink.
## layout_contained only describes the measured layout envelope. Actual renderer
## edge coverage with the current fixed font/theme remains a separate gate.
const MIN_ABS_DETERMINANT := 0.00000001

static func place(panel: Control, carry: Label, requested_position: Vector2) -> Dictionary:
	var result: Dictionary = _unavailable(requested_position, "unattached_carry")
	if not is_instance_valid(panel) or not is_instance_valid(carry): return result
	if not panel.is_inside_tree() or not carry.is_inside_tree(): return result
	if carry.get_parent() != panel or carry.is_set_as_top_level():
		return _unavailable(requested_position, "unexpected_carry_parent")
	if not carry.is_visible_in_tree(): return _empty(requested_position)
	var panel_to_viewport: Transform2D = panel.get_global_transform_with_canvas()
	if not _finite_transform(panel_to_viewport) or absf(panel_to_viewport.determinant()) <= MIN_ABS_DETERMINANT:
		return _unavailable(requested_position, "unstable_or_singular_panel_transform")
	if not requested_position.is_finite():
		return _unavailable(carry.position, "nonfinite_requested_position")
	var measured: Dictionary = _measure(carry)
	if not measured["available"]: return _unavailable(requested_position, measured["reason"])
	if not measured["has_visual"]: return _empty(requested_position)
	var current_union: Rect2 = measured["rect"]
	var movement: Vector2 = panel_to_viewport.basis_xform(requested_position - carry.position)
	var proposed_union := Rect2(current_union.position + movement, current_union.size)
	result = fit_union(proposed_union, panel.get_viewport().get_visible_rect())
	result["requested_position"] = requested_position
	result["position"] = requested_position
	result["bounds_basis"] = "fixed_ui012_layout_envelope"
	# Preserve the original local +18 bit-for-bit in the interior. Only the visual
	# displacement is inverse-transformed; no event/mouse/slot coordinate changes.
	if result["available"] and result["correction_viewport"] != Vector2.ZERO:
		result["position"] = requested_position + panel_to_viewport.affine_inverse().basis_xform(result["correction_viewport"])
	return result

static func fit_union(proposed_union: Rect2, viewport_rect: Rect2) -> Dictionary:
	# Each feasible axis uses the minimum translation. An oversized axis always
	# aligns its minimum edge with the viewport minimum. No resizing or clipping.
	if not _finite_rect(proposed_union) or not _finite_rect(viewport_rect) or not proposed_union.has_area() or not viewport_rect.has_area():
		return _unavailable(Vector2.ZERO, "invalid_or_unlaid_out_geometry")
	var limited_axes := Vector2i(int(proposed_union.size.x > viewport_rect.size.x), int(proposed_union.size.y > viewport_rect.size.y))
	var correction := Vector2(
		_axis_shift(proposed_union.position.x, proposed_union.end.x, viewport_rect.position.x, viewport_rect.end.x),
		_axis_shift(proposed_union.position.y, proposed_union.end.y, viewport_rect.position.y, viewport_rect.end.y))
	var corrected_union := Rect2(proposed_union.position + correction, proposed_union.size)
	var limited: bool = limited_axes != Vector2i.ZERO
	return {"available": true, "has_visual": true, "layout_contained": not limited,
		"limited": limited, "limited_axes": limited_axes, "status": "limited" if limited else "placed",
		"reason": "viewport_smaller_than_layout_union" if limited else "",
		"proposed_union_viewport": proposed_union, "layout_union_viewport": corrected_union,
		"viewport_rect": viewport_rect, "correction_viewport": correction}

static func _axis_shift(start: float, finish: float, lower: float, upper: float) -> float:
	if finish - start > upper - lower: return lower - start
	if start < lower: return lower - start
	if finish > upper: return upper - finish
	return 0.0

static func _measure(carry: Label) -> Dictionary:
	var rectangles: Array[Rect2] = []
	var fallback: Dictionary = _label_envelope(carry)
	if not fallback["available"]: return fallback
	if fallback["has_visual"]:
		var fallback_rect: Rect2 = fallback["rect"]
		rectangles.append(carry.get_global_transform_with_canvas() * fallback_rect)
	var icon: TextureRect = carry.get_node_or_null("MaterialIcon") as TextureRect
	var quantity: Label = carry.get_node_or_null("MaterialQuantity") as Label
	if icon == null or quantity == null:
		return {"available": false, "reason": "missing_fixed_decorations"}
	if icon.is_visible_in_tree() and icon.texture != null:
		if icon.size.x <= 0.0 or icon.size.y <= 0.0 or icon.stretch_mode != TextureRect.STRETCH_KEEP_ASPECT_CENTERED:
			return {"available": false, "reason": "unexpected_icon_layout"}
		# The original square texture occupies its 40x40 draw frame. Including that
		# frame is also conservative for a narrower KEEP_ASPECT_CENTERED texture.
		rectangles.append(icon.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, icon.size))
	if quantity.is_visible_in_tree() and not quantity.text.is_empty():
		if not quantity.clip_text or quantity.size.x <= 0.0 or quantity.size.y <= 0.0:
			return {"available": false, "reason": "unexpected_quantity_layout"}
		# Existing clip_text limits all quantity drawing to this 60x24 frame. Do
		# not reuse the empty carry Label's 1x23 minimum or crop/shrink the number.
		rectangles.append(quantity.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, quantity.size))
	if rectangles.is_empty(): return {"available": true, "has_visual": false}
	var united: Rect2 = rectangles[0]
	for rectangle: Rect2 in rectangles:
		if not _finite_rect(rectangle): return {"available": false, "reason": "nonfinite_child_geometry"}
		united = united.merge(rectangle)
	return {"available": true, "has_visual": true, "rect": united}

static func _label_envelope(label: Label) -> Dictionary:
	if label.text.is_empty(): return {"available": true, "has_visual": false}
	# This candidate is intentionally not a general Label renderer. These modes
	# do not occur in the pinned carry and require their own review if introduced.
	if label.label_settings != null or label.uppercase or label.visible_characters >= 0 or label.autowrap_mode != TextServer.AUTOWRAP_OFF or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING or label.lines_skipped != 0 or label.max_lines_visible != -1:
		return {"available": false, "reason": "fallback_mode_outside_fixed_scope"}
	if not label.get_theme_stylebox("normal") is StyleBoxEmpty or label.material != null:
		return {"available": false, "reason": "fallback_effect_outside_fixed_scope"}
	if label.get_theme_font("font") == null or label.get_theme_font_size("font_size") <= 0 or label.size.x <= 0.0 or label.size.y <= 0.0:
		return {"available": false, "reason": "fallback_not_laid_out"}
	# Use the original Label's shaping, fallback font, paragraph layout, and
	# horizontal/vertical alignment. Do not rebuild text with get_string_size.
	var rectangles: Array[Rect2] = []
	for character_index: int in range(label.get_total_character_count()):
		var character_rect: Rect2 = label.get_character_bounds(character_index)
		if character_rect.has_area(): rectangles.append(character_rect)
	if rectangles.is_empty(): return {"available": false, "reason": "fallback_bounds_unavailable"}
	var shaped_layout: Rect2 = rectangles[0]
	for rectangle: Rect2 in rectangles: shaped_layout = shaped_layout.merge(rectangle)
	var outline_size: int = maxi(0, label.get_theme_constant("outline_size"))
	var shadow_size: int = maxi(0, label.get_theme_constant("shadow_outline_size"))
	var shadow_offset := Vector2(label.get_theme_constant("shadow_offset_x"), label.get_theme_constant("shadow_offset_y"))
	var effects: Array[Rect2] = []
	if label.get_theme_color("font_color").a > 0.0: effects.append(shaped_layout)
	if outline_size > 0 and label.get_theme_color("font_outline_color").a > 0.0: effects.append(shaped_layout.grow(outline_size))
	if label.get_theme_color("font_shadow_color").a > 0.0:
		var shadow: Rect2 = shaped_layout.grow(shadow_size)
		shadow.position += shadow_offset
		effects.append(shadow)
	if effects.is_empty(): return {"available": true, "has_visual": false}
	var envelope: Rect2 = effects[0]
	for effect: Rect2 in effects: envelope = envelope.merge(effect)
	if label.clip_text: envelope = envelope.intersection(Rect2(Vector2.ZERO, label.size))
	return {"available": true, "has_visual": envelope.has_area(), "rect": envelope}

static func _finite_transform(value: Transform2D) -> bool:
	return value.x.is_finite() and value.y.is_finite() and value.origin.is_finite()

static func _finite_rect(value: Rect2) -> bool:
	return value.position.is_finite() and value.size.is_finite() and value.end.is_finite()

static func _empty(requested_position: Vector2) -> Dictionary:
	return {"available": true, "has_visual": false, "layout_contained": true,
		"limited": false, "status": "empty", "reason": "", "position": requested_position,
		"requested_position": requested_position, "correction_viewport": Vector2.ZERO}

static func _unavailable(requested_position: Vector2, reason: String) -> Dictionary:
	# A display limitation never rejects a server view or blocks gameplay input.
	return {"available": false, "has_visual": null, "layout_contained": false,
		"limited": true, "status": "unavailable", "reason": reason, "position": requested_position,
		"requested_position": requested_position, "correction_viewport": Vector2.ZERO}
