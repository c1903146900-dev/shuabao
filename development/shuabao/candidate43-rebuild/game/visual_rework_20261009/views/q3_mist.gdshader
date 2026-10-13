shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float age=0.0;
uniform float seed=0.0;
uniform float strength=1.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float n=noise(vec2(UV.x*12.0-age*.50+seed,UV.y*3.0+seed));
 float fine=noise(vec2(UV.x*29.0-age*.91+seed,UV.y*6.0));
 float edge=pow(max(0.,sin(UV.y*3.14159)),1.7)*smoothstep(0.,.14,UV.x)*(1.-smoothstep(.85,1.,UV.x));
 ALBEDO=mix(vec3(.50,.62,.60),vec3(.79,.79,.65),n);
 ALPHA=edge*smoothstep(.24,.75,n*.72+fine*.28)*.65*strength;
}
