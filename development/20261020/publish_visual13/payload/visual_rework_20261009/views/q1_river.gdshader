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
 // Stable brush silhouette; only internal pigment travels along source arc length.
 float v=river_uv.y*2.0-1.0;
 float stroke=1.0-smoothstep(.70,.79,abs(v));
 float core=1.0-smoothstep(.43,.66,abs(v));
 float velocity=layer<.5?2.2:(layer<1.5?3.0:3.8);
 float phase=s-velocity*age;
 vec4 ink=texture(ink_texture,vec2(phase/6.0+layer*.193,.27+river_uv.y*.46));
 vec4 fine=texture(ink_texture,vec2((s-velocity*.72*age)/3.1,.34+river_uv.y*.32));
 float grain=clamp(ink.a*.7+fine.a*.3,0.0,1.0);
 // Three long, narrow brush channels. Moving gaps make direction readable.
 float a=1.0-smoothstep(.018,.047,abs(v+.34-.055*sin(phase*1.7)));
 float b=1.0-smoothstep(.022,.052,abs(v-.02-.065*sin(phase*1.7+1.2)));
 float c=1.0-smoothstep(.014,.038,abs(v-.36-.045*sin(phase*1.7+2.1)));
 float beat=.5+.5*sin(phase*2.4+v*1.4);
 float run=smoothstep(.16,.64,beat);
 float threads=max(a*.8,max(b,c*.65))*(.22+.78*run);
 // Short forward-pointing crests interrupt the long lines instead of a broad glow.
 float crest_phase=fract((phase+v*.34)/1.85);
 float crest=(1.0-smoothstep(.04,.13,crest_phase))*smoothstep(.04,.22,abs(v))*(1.0-smoothstep(.42,.61,abs(v)));
 if(layer<.5){
  vec3 ink_edge=vec3(.025,.065,.075);
  vec3 blue_core=vec3(.10,.35,.34);
  ALBEDO=mix(ink_edge,blue_core,core*(.82+.18*grain));
  ALPHA=stroke*(.90+.06*grain);
 }else if(layer<1.5){
  ALBEDO=mix(vec3(.25,.56,.50),vec3(.73,.83,.66),run);
  ALPHA=stroke*threads*(.76+.18*grain);
 }else{
  ALBEDO=vec3(.79,.85,.70);
  ALPHA=stroke*crest*.78;
 }
 ALPHA*=crossfade*entry*outlet*reveal*retire;
 if(guide){ALBEDO=vec3(.49,.69,.66);ALPHA=.24*crossfade*entry*outlet;}
}
