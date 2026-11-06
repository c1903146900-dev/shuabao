# Integration caution

ranged_facing01 and body_aim05 both change the same enemy draw transform. Do not apply either full presentation.gd over the other: that would silently discard one feature. No combined candidate has been built or accepted.

If the mouse candidate later passes its own full-floor verification, multiply the signed facing into the existing body_scale.x before both Transform2D(...body_scale...) in body_pick_context and draw_set_transform(...body_scale). The picker must invert exactly the same mirrored geometry that is rendered. Changing only draw_set_transform would make the visible shooter body and clickable opaque pixels disagree. Keep hero geometry and other enemy art unchanged.

A future combined candidate needs real left/right shooter clicks including transparent gun-adjacent space, overlap, empty-space direction, no-follow behavior and its own complete regression. Neither isolated pass establishes this integration.
