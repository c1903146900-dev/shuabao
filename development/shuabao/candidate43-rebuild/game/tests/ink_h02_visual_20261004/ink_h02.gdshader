shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

// Existing original RGBA brush. UV stays attached to authored ground ribbons.
// No TIME, scrolling UV, screen sampling, emission, noise or soft particles.
uniform sampler2D original_brush : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 deep_ink : source_color = vec4(0.115, 0.155, 0.155, 1.0);
uniform vec4 dilute_ink : source_color = vec4(0.41, 0.48, 0.45, 1.0);
uniform float opacity : hint_range(0.0, 1.0) = 0.46;
uniform float source_age = 0.0;
uniform float life_envelope : hint_range(0.0, 1.0) = 1.0;
uniform float layer_phase = 0.0;
uniform bool quiet_wet_edge = false;

void fragment() {
    vec4 brush = texture(original_brush, clamp(UV, vec2(0.0), vec2(1.0)));
    float value = dot(brush.rgb, vec3(0.299, 0.587, 0.114));
    float pigment = mix(brush.a, smoothstep(0.08, 0.76, brush.a), quiet_wet_edge ? 0.0 : 0.42);
    // A restrained traveling pressure change on stationary pigment; never a
    // moving texture or an enemy-attraction proxy. Source pause freezes it.
    float pressure = 0.92 + 0.08 * sin(UV.x * 6.283185 - source_age * 2.8 + layer_phase);
    ALBEDO = mix(deep_ink.rgb, dilute_ink.rgb, pow(clamp(value, 0.0, 1.0), 0.72));
    ALPHA = pigment * COLOR.a * opacity * life_envelope * pressure;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
