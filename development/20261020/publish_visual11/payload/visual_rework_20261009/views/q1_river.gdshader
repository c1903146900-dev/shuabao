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
 // Pigment travels along the fixed river, from the first visible source frame.
 // This is visual advection only; the authoritative front_distance stays unchanged.
 float velocity=layer<.5?2.2:(layer<1.5?3.0:3.8);
 float drift=(s-velocity*age)/6.0;
 vec4 ink=texture(ink_texture,vec2(drift+layer*.193,.27+river_uv.y*.46));
 vec4 fine=texture(ink_texture,vec2((s-velocity*.72*age)/3.1,.34+river_uv.y*.32));
 float current=.5+.5*sin((s-velocity*age)*2.1+river_uv.y*6.0+layer);
 float wash=1.0-smoothstep(.24,.92,abs(river_uv.y*2.0-1.0));
 float pigment=clamp(ink.a*.72+fine.a*.28,0.0,1.0);
 float crest=smoothstep(.58,.92,current)*smoothstep(.12,.72,fine.a);
 vec3 deep_ink=vec3(.035,.105,.125);
 vec3 mineral_blue=vec3(.12,.34,.36);
 vec3 pale_water=vec3(.55,.73,.68);
 float body=.64*wash*(.82+.18*pigment)+.22*pigment;
 if(layer<.5){
  ALBEDO=mix(deep_ink,mineral_blue,.32+.42*pigment+.16*current);
  ALPHA=body;
 }else{
  // Sparse travelling crests above the connected dark wash; no emissive rim.
  ALBEDO=mix(mineral_blue,pale_water,crest*.78);
  ALPHA=pigment*(.12+.24*crest)*(layer<1.5?1.0:.64);
 }
 ALPHA*=crossfade*entry*outlet*reveal*retire;
 if(guide){ALBEDO=vec3(.49,.69,.66);ALPHA=.24*crossfade*entry*outlet;}
}
