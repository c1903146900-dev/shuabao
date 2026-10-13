shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D atlas : filter_linear, repeat_disable;
uniform float fade = 1.0;
uniform float impact = 0.0;
uniform vec4 ink_tint : source_color = vec4(0.025,0.035,0.042,1.0);
varying float vertex_alpha;
void vertex(){vertex_alpha=COLOR.a;}
void fragment(){
 vec2 pixel=vec2(mix(100.5,1120.5,UV.x),mix(550.5,610.5,UV.y));
 vec4 sample_color=textureLod(atlas,pixel/1254.0,0.0);
 float density=clamp(1.0-dot(sample_color.rgb,vec3(0.2126,0.7152,0.0722)),0.0,1.0)*sample_color.a;
 float cross_distance=abs(UV.y-0.5)*2.0;
 // One connected directional core; original ink affects only the soft irregular edge.
 float edge_width=mix(0.78,1.0,density);
 float edge=1.0-smoothstep(0.48,edge_width,cross_distance);
 float core=1.0-smoothstep(0.24,0.62,cross_distance);
 float tip=1.0-smoothstep(0.92,1.0,UV.x);
 float alpha=max(core*0.90,edge*mix(0.35,0.80,density))*tip*vertex_alpha*fade*ink_tint.a;
 if(alpha<0.003)discard;
 vec3 paper_ink=vec3(0.76,0.82,0.79);
 ALBEDO=mix(ink_tint.rgb,paper_ink,impact*core*0.92);
 ALPHA=alpha;
}
