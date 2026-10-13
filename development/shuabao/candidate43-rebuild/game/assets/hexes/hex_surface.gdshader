shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D art_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D erosion_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0,1.0) = 1.0;
uniform float erosion : hint_range(0.0,1.0) = 0.0;
uniform float glow : hint_range(0.0,1.0) = 0.0;
void fragment() {
 vec4 art=texture(art_texture,UV);
 float grain=texture(erosion_texture,UV*1.73+vec2(.271,.63)).r;
 float dissolve=1.0-smoothstep(grain-.16,grain+.16,erosion*1.12);
 float lum=dot(art.rgb,vec3(.299,.587,.114));
 ALBEDO=mix(vec3(lum),art.rgb,.16)*tint.rgb;
 EMISSION=ALBEDO*glow;
 ALPHA=art.a*tint.a*opacity*dissolve;
}
