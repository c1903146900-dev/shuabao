shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D erosion_map : filter_linear_mipmap, repeat_enable;
uniform float life_alpha=1.0;
uniform float spin_material=0.0;
uniform float stroke_seed=0.0;
uniform float stroke_clock=0.0;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123); }
float noise(vec2 p) {
 vec2 cell=floor(p), f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(hash(cell),hash(cell+vec2(1.,0.)),f.x),mix(hash(cell+vec2(0.,1.)),hash(cell+vec2(1.,1.)),f.x),f.y);
}
void fragment() {
 float grain=noise(vec2(UV.x*15.,UV.y*4.))+noise(vec2(UV.x*37.,UV.y*9.))*.24;
 float torn=smoothstep(.15,.48,grain+UV.x*.18);
 float bevel=pow(abs(cos(UV.y*6.2831853)),5.);
 vec3 silver=mix(vec3(.43,.54,.62),vec3(.89,.94,.98),bevel*.72+grain*.19);
 vec3 blood=vec3(.27,.030,.058);
 ALBEDO=mix(silver,blood,(1.-smoothstep(.08,.30,UV.y))*.58);
 float cut=noise(vec2(UV.x*24.+stroke_seed*7.,UV.y*3.+stroke_clock*4.));
 float negative_cut=smoothstep(.23,.52,cut+UV.x*.16);
 float soft_edge=pow(abs(sin(UV.y*6.2831853)),.24);
 vec3 feather=mix(vec3(.35,.43,.51),vec3(.84,.91,.96),noise(vec2(UV.x*7.+stroke_seed,UV.y*2.))*.85);
 ALBEDO=mix(ALBEDO,feather,spin_material);
 ALPHA=life_alpha*COLOR.a*torn*(.66+.26*UV.x)*mix(1.,negative_cut*(.35+.65*soft_edge),spin_material);
}
