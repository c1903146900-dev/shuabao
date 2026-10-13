shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float remaining=1.0;
uniform float age=0.0;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise2(vec2 p){vec2 c=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(c),hash2(c+vec2(1,0)),f.x),mix(hash2(c+vec2(0,1)),hash2(c+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*2.0-1.0;float r=length(p);float angle=atan(p.y,p.x);
 float billow=.72+.08*sin(angle*5.0+1.2)+.06*sin(angle*9.0-.3)+.05*noise2(p*7.0);
 float inner=1.0-smoothstep(billow-.16,billow+.06,r);
 float clouds=noise2(p*4.1)*.65+noise2(p*10.5)*.35;
 float creamy=smoothstep(.37,.70,clouds);
 ALBEDO=mix(vec3(.025,.045,.035),vec3(.085,.13,.073),creamy);
 EMISSION=vec3(.002,.004,.001)*creamy;
 // Organic visible body, soft inner fill, exact outer extent indicated separately.
 ALPHA=(inner*(.32+.34*creamy)+.025*(1.0-smoothstep(.87,.99,r)))*(1.0-smoothstep(.992,1.0,r))*smoothstep(0.0,.18,remaining);
}
