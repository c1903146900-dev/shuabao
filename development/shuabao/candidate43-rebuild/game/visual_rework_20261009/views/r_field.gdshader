shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age=0.0;
uniform float life=6.0;
uniform bool snow=true;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=(UV-.5)*2.0;float r=length(p);float edge=1.0-smoothstep(.72,1.0,r);
 float low=noise(p*vec2(2.0,3.0)+vec2(age*.008,-age*.011));
 float channel=1.0-smoothstep(.1,.68,abs(p.y+.15*sin(p.x*2.0)));
 float stroke=noise(p*vec2(2.7,34.0)+vec2(age*.018,-age*.022));
 float fleck=smoothstep(.59,.68,stroke)*smoothstep(.52,.65,low);
 vec3 paper=vec3(.71,.75,.74);vec3 ink=vec3(.23,.30,.33);
 vec3 water=mix(paper,ink,channel*(.12+fleck*.28));
 float born=smoothstep(0.0,.18,age);float end=1.0-smoothstep(life-.22,life,age);
 ALBEDO=snow?water:vec3(.66,.67,.54);ALPHA=edge*born*end*(snow?.27:.06);
}
