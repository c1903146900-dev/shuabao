shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, depth_test_disabled, fog_disabled;
uniform sampler2D art_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D erosion_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0, 1.0) = 1.0;
uniform float erosion : hint_range(0.0, 1.0) = 0.0;
uniform float erosion_strength = 1.0;
uniform float reveal : hint_range(0.0, 1.0) = 1.0;
uniform float directional_reveal = 0.0;
uniform vec2 erosion_offset = vec2(0.0);
void fragment() {
    vec4 art = texture(art_texture, UV);
    float grain = texture(erosion_texture, UV * 1.73 + erosion_offset).r;
    float arrival = max(0.0, 0.69 - UV.y) * 1.32 + abs(UV.x - 0.5) * 0.42;
    float emergence = mix(1.0, 1.0 - smoothstep(reveal - 0.055, reveal + 0.055, arrival), directional_reveal);
    float dissolve = 1.0 - smoothstep(grain - 0.12, grain + 0.12, erosion * 1.02);
    float a = art.a * tint.a * opacity * mix(1.0, dissolve, erosion_strength);
    ALBEDO = art.rgb * tint.rgb * COLOR.rgb;
    ALPHA = a * COLOR.a * emergence;
}
