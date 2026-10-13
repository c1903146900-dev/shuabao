shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D painting : source_color;
uniform float age=0.0;
uniform float life=6.0;
uniform float strength=.48;
uniform bool mountain=false;
uniform int layer=0;
float noise(vec2 p){return sin(p.x*4.3+sin(p.y*2.7))*.5+.5;}
void vertex(){if(mountain){float delay=float(layer)*.012;float grow=smoothstep(delay,delay+.055,age);VERTEX.y*=grow;}}
void fragment(){
 vec4 c=texture(painting,UV);
 if(!mountain){float grey=dot(c.rgb,vec3(.299,.587,.114));c.rgb=vec3(grey*.97,grey,grey*1.012);c.a=smoothstep(.015,.99,c.a);c.a*=smoothstep(0.0,.025,min(min(UV.x,1.0-UV.x),min(UV.y,1.0-UV.y)));}
 float incoming=smoothstep(0.0,.18,age);float outgoing=1.0-smoothstep(life-.2,life,age);
 if(mountain){incoming=smoothstep(0.0,.02,age);outgoing=1.0-smoothstep(.20,.3,age);}
 float layer_mask=1.0;
 if(mountain){
  float a=smoothstep(.31,.46,UV.x);float b=smoothstep(.61,.76,UV.x);
  layer_mask=layer==0?1.0-a:(layer==1?a*(1.0-b):b);
  float reveal=smoothstep(0.0,.055,age-float(layer)*.012);
  layer_mask*=smoothstep(1.0-reveal-.11,1.0-reveal,UV.y);
  float wash=noise(UV*vec2(4.0,2.0)+vec2(-age*.65,age*.38));
  c.rgb=mix(c.rgb*.78,vec3(.60,.64,.63),wash*.10*(1.0-UV.y));
 }
 ALBEDO=c.rgb;ALPHA=c.a*strength*incoming*outgoing*layer_mask;
}
