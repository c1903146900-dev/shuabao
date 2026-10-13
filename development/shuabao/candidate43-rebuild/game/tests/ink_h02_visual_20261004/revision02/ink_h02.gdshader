shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Original Q06 pigment sampled through authored cross-section UVs. No new raster.
// Ground-locked ink, source-age only; no autonomous time or moving texture.
uniform sampler2D original_brush : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 deep_ink : source_color = vec4(0.055, 0.077, 0.080, 1.0);
uniform vec4 dilute_ink : source_color = vec4(0.29, 0.36, 0.34, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.77;
uniform float source_age = 0.0;
uniform float life_envelope : hint_range(0.0, 1.0) = 1.0;
uniform float layer_phase = 0.0;
uniform bool quiet_wet_edge = false;

void fragment() {
    vec4 brush = texture(original_brush, clamp(UV, vec2(0.0), vec2(1.0)));
    float value = dot(brush.rgb, vec3(0.299, 0.587, 0.114));
    // Ground shows through the original fibre highlights and true alpha tears.
    // Never replace original transparent areas with artificial black minimum fill.
    float dry_fibre = 1.0 - 0.80 * smoothstep(0.30, 0.70, value);
    float pigment = brush.a * (quiet_wet_edge ? 1.0 : dry_fibre);
    float pressure = 0.96 + 0.04 * sin(UV2.x * 6.283185 - source_age * 2.8 + layer_phase);
    // Short dilution exists only beside the loaded portion, not a full halo.
    float wet_window = smoothstep(0.32, 0.48, UV2.x) * (1.0 - smoothstep(0.82, 0.93, UV2.x));
    if (quiet_wet_edge) {
        pigment *= wet_window;
    }
    ALBEDO = mix(deep_ink.rgb, dilute_ink.rgb, pow(clamp(value, 0.0, 1.0), 0.80));
    ALPHA = pigment * COLOR.a * opacity * life_envelope * pressure;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
