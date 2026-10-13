shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;

// Original alpha pigment only. UV1 preserves frozen arc stations for contact
// pigment; UV2 carries one cohesive advancing stroke footprint. No TIME/screen.
uniform sampler2D ink_paint : source_color, filter_linear_mipmap, repeat_disable;
uniform bool use_local_footprint = false;
uniform vec4 pigment_dark : source_color = vec4(0.055, 0.092, 0.101, 1.0);
uniform vec4 pigment_mid : source_color = vec4(0.29, 0.39, 0.40, 1.0);
uniform vec4 uv_window = vec4(0.47, 0.08, 0.10, 0.84);
uniform float pigment_opacity : hint_range(0.0, 1.0) = 1.0;
uniform float edge_hardness : hint_range(0.0, 1.0) = 0.5;

void fragment() {
    vec2 pigment_uv = use_local_footprint ? UV2 : UV;
    vec4 paint = texture(ink_paint, uv_window.xy + clamp(pigment_uv, vec2(0.0), vec2(1.0)) * uv_window.zw);
    float load = dot(paint.rgb, vec3(0.299, 0.587, 0.114));
    float edge = mix(paint.a, smoothstep(0.07, 0.79, paint.a), edge_hardness);
    // Loaded black and diluted grey remain different pigments; gaps preserve
    // true transparency. No minimum alpha, metallic highlight, emission or fog.
    ALBEDO = mix(pigment_dark.rgb, pigment_mid.rgb, pow(clamp(load, 0.0, 1.0), 0.72)) * COLOR.rgb;
    ALPHA = edge * COLOR.a * pigment_opacity;
    ROUGHNESS = 1.0;
    SPECULAR = 0.0;
}
