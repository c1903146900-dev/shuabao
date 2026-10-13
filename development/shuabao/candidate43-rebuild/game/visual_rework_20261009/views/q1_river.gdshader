shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D ink_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float age=0.0;
uniform float path_length=11.0;
uniform float front_distance=0.0;
uniform float layer=0.0;
uniform bool guide=false;
varying vec2 river_uv;
void vertex(){river_uv=UV;}
void fragment(){
 float s=river_uv.x*path_length;
 float crossfade=1.0-smoothstep(.65,1.0,abs(river_uv.y*2.0-1.0));
 // Endpoints stay full-width geometrically; only opacity feathers in/out.
 float entry=smoothstep(0.0,min(.65,path_length*.18),s);
 float outlet=1.0-smoothstep(max(0.0,path_length-min(1.15,path_length*.25)),path_length,s);
 float reveal=1.0-smoothstep(front_distance-.06,front_distance+.06,s);
 float retire=1.0-smoothstep(2.55,3.45,age);
 float velocity=layer<.5?5.04:(layer<1.5?7.42:9.38);
 float drift=(s-velocity*age)/6.0;
 vec4 ink=texture(ink_texture,vec2(drift+layer*.193,.27+river_uv.y*.46));
 vec4 fine=texture(ink_texture,vec2((s-velocity*.72*age)/3.1,.34+river_uv.y*.32));
 float current=.5+.5*sin(s*3.1-age*velocity*3.1+river_uv.y*5.0+layer);
 float density=mix(.27,.8,current)*mix(.4,1.0,fine.a);
 ALBEDO=mix(vec3(.13,.19,.19),vec3(.39,.47,.43),layer*.21+current*.09);
 ALPHA=ink.a*density*crossfade*entry*outlet*reveal*retire*(layer<.5?.48:.36);
 if(guide){ALBEDO=vec3(.49,.69,.66);ALPHA=.24*crossfade*entry*outlet;}
}
