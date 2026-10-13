shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_schlick_ggx;
// Slate-grain jade with pale bevels, fine etched cracks and a very restrained edge sheen.
// COLOR.r controls stone tone; COLOR.g marks authored bevels; COLOR.a masks broken edges.
uniform sampler2D stone_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D fracture_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.30,0.47,0.40,1.0);
uniform float opacity : hint_range(0.0,1.0) = 1.0;
uniform float strength : hint_range(0.0,1.0) = 1.0;
uniform float pulse : hint_range(0.0,1.0) = 0.0;
uniform float edge_light : hint_range(0.0,1.0) = 0.2;
void fragment() {
    vec3 grain = texture(stone_texture, UV * 1.65).rgb;
    float fault = texture(fracture_texture, UV * vec2(3.7,1.2)).r;
    float etch = (1.0-smoothstep(0.016,0.043,abs(fault-0.45))) * 0.32;
    float bevel = COLOR.g;
    vec3 body = tint.rgb * mix(vec3(0.68),grain,0.50) * mix(0.50,1.10,COLOR.r);
    vec3 edge = vec3(0.72,0.86,0.73) * (0.79+grain*0.21);
    ALBEDO = mix(body,edge,bevel*0.80) + etch*tint.rgb*0.20;
    EMISSION = vec3(0.27,0.63,0.47) * (bevel*0.82+etch) * edge_light * (0.62+strength*0.28+pulse*0.10);
    ROUGHNESS = 0.89;
    METALLIC = 0.07;
    ALPHA = tint.a * opacity * COLOR.a;
}
