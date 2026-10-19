shader_type spatial;
render_mode unshaded, cull_back, depth_draw_opaque;
uniform vec4 pigment : source_color = vec4(0.65,0.61,0.45,1.0);
uniform sampler2D authored_map : source_color, filter_linear_mipmap, repeat_enable;
uniform bool has_map = false;
uniform float texture_strength : hint_range(0.0,0.2) = 0.06;
uniform float hit_amount : hint_range(0.0,1.0) = 0.0;
uniform bool minion_form_enabled = false;
void fragment() {
 float grain = has_map ? dot(texture(authored_map, UV).rgb, vec3(0.299,0.587,0.114)) : 0.5;
 float quiet_band = floor(clamp(grain,0.0,0.999)*3.0)/2.0;
 vec3 ink = pigment.rgb * mix(1.0,0.88+quiet_band*0.16,texture_strength);
 if (minion_form_enabled) {
  // View-space illustration key: stable screen-left/top, not a new scene light.
  float facing = dot(normalize(NORMAL), normalize(vec3(-0.45,0.65,0.60)));
  float shade = mix(0.70,1.0,smoothstep(0.12,0.18,facing));
  shade = mix(shade,1.10,smoothstep(0.80,0.86,facing));
  ink *= shade;
 }
 ALBEDO = mix(ink,vec3(1.0,0.88,0.67),hit_amount*0.85);
 ROUGHNESS = 1.0;
 SPECULAR = 0.0;
}
