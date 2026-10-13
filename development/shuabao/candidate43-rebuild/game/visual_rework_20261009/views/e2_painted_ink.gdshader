shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform sampler2D brush:source_color,filter_linear_mipmap;
uniform float age=0.0;
uniform float strength=1.0;
uniform float seed=0.0;
uniform int mode=0;
void fragment(){
 vec2 p=UV;
 vec2 at;
 if(mode==0){
  float s=.05+.90*p.x;
  at=vec2(s,.96-.82*s+.12*sin(s*PI)+(p.y-.5)*(.44-.15*s));
 }else{at=vec2(.30+p.x*.47,.035+p.y*.90);}
 vec4 raw=texture(brush,at);
 float l=dot(raw.rgb,vec3(.299,.587,.114));
 // The bitmap carries actual brush fibres and washes; pale pigment becomes
 // thin wash/negative space rather than glowing foam.
 float ink=max(0.0,(raw.a-.008)/.992)*(.12+.88*(1.0-l));
 vec2 advection=at+vec2(age*.058,-age*.033+seed*.03);
 if(mode==0){advection=at-vec2(age*.16,-age*.11)+vec2(seed*.035,-seed*.025);}
 vec4 grain=texture(brush,fract(advection));
 float g=dot(grain.rgb,vec3(.299,.587,.114));
 float density=.61+.39*(1.0-g);
 if(mode==0){density=.26+.74*grain.a;}
 float ends=smoothstep(0.0,.045,p.x)*(1.0-smoothstep(.88,1.0,p.x));
 vec3 col=mix(vec3(.025,.042,.048),vec3(.31,.34,.32),l*.66);
 col=mix(col,vec3(.39,.42,.40),clamp(seed*.15,0.0,.4));
 if(mode==1){col=mix(vec3(.13,.21,.22),vec3(.40,.47,.44),l*.7);}
 ALBEDO=col;ALPHA=ink*density*ends*strength;
}
