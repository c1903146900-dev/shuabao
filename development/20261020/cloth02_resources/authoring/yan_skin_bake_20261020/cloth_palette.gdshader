shader_type spatial;
render_mode cull_disabled, diffuse_burley;
uniform sampler2D source_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 source_tint : source_color = vec4(1.0);
uniform float source_roughness = 0.9;
uniform float source_metallic = 0.0;
uniform float source_specular = 0.4;
varying vec4 cloth_color;
void vertex() { cloth_color = COLOR; }
void fragment() {
 vec3 original = texture(source_albedo, UV).rgb * source_tint.rgb;
 float mask = clamp(cloth_color.a, 0.0, 1.0);
 ALBEDO = mix(original, cloth_color.rgb, mask);
 ROUGHNESS = mix(source_roughness, 1.0, mask);
 METALLIC = mix(source_metallic, 0.0, mask);
 SPECULAR = mix(source_specular, 0.12, mask);
}
