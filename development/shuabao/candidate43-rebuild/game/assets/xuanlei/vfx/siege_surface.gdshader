shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_schlick_ggx;
uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 1.0;
uniform float emission_strength = 0.0;
uniform float metallic = 0.08;
uniform float erosion = 0.0;
void fragment() {
    vec3 grain = texture(stone_texture, UV * 1.4).rgb;
    vec3 base = COLOR.rgb * tint.rgb;
    ALBEDO = base * mix(vec3(0.71), grain, 0.62);
    METALLIC = metallic;
    ROUGHNESS = 0.78 + grain.r * 0.18;
    EMISSION = base * emission_strength;
    ALPHA = COLOR.a * tint.a * opacity;
}
