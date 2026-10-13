shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float age=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 float x=UV.x;float y=UV.y;
 float n=noise(vec2(x*8.-age*7.,y*22.));
 float edge=pow(max(0.,sin(y*3.14159)),1.1);
 float born=smoothstep(x*.12,x*.12+.08,age);
 float tail=1.-smoothstep(.70,1.4,age);
 float front=exp(-pow((x-age*.9)/.12,2.));
 ALBEDO=mix(vec3(.07,.17,.17),vec3(.6,.65,.53),n*.7+front*.3);
 ALPHA=(.32+.35*n+.2*front)*edge*smoothstep(0.,.065,x)*born*tail*(1.-smoothstep(.96,1.,x));
}
