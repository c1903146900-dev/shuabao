shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float life_alpha=1.0;
uniform float spin_material=1.0;
uniform float stroke_seed=0.0;
uniform float stroke_clock=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453123);}
float noise(vec2 p){vec2 c=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(c),hash(c+vec2(1,0)),f.x),mix(hash(c+vec2(0,1)),hash(c+vec2(1,1)),f.x),f.y);}
void fragment(){
 float grain=noise(vec2(UV.x*21.+stroke_seed*4.,UV.y*5.-stroke_clock*3.));
 float cut=step(.36+(1.-life_alpha)*.26,grain+UV.x*.15);
 float edge=smoothstep(0.,.12,UV.y)*(1.-smoothstep(.75,1.,UV.y));
 float layer=mix(.23,.64,smoothstep(.28,.64,UV.y));
 float leading=pow(clamp(UV.x,0.,1.),.55);
 ALBEDO=mix(vec3(.32,.42,.49),vec3(.79,.88,.92),smoothstep(.34,.70,grain));
 ALPHA=COLOR.a*life_alpha*cut*edge*layer*(.30+.70*leading);
}
