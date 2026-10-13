shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform sampler2D landscape_atlas : filter_linear,repeat_disable;
uniform vec3 domain_center=vec3(0.0);
uniform float domain_radius=10.0;
uniform float visible_ink=0.0;
uniform float fold_progress=0.0;
uniform float unfold_progress=0.0;
uniform vec3 gather_target=vec3(0.0);
varying vec3 world_position;
varying float fixed_boundary;
varying float ribbon;
varying vec2 brush_coordinate;
void vertex(){
 fixed_boundary=COLOR.r;ribbon=COLOR.g;brush_coordinate=UV2;
 if(fixed_boundary<0.5){
  float p=clamp(fold_progress,0.0,1.0);
  float lead=clamp(p*1.20-0.16*(1.0-UV2.x),0.0,1.0);
  float gather=smoothstep(0.0,1.0,lead);
  vec3 origin=VERTEX;
  VERTEX=mix(origin,gather_target,gather);
  // Open ribbons curve into the frozen brush origin, never into a smaller ring.
  float bow=sin(lead*3.14159265);
  VERTEX.x+=bow*0.045*sin(ribbon*6.2831853+UV2.x*3.14159265);
  VERTEX.z+=bow*0.045*cos(ribbon*6.2831853+UV2.x*3.14159265);
  VERTEX.y+=bow*(0.38+COLOR.b*0.30)*sin(UV2.x*3.14159265);
 }
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 if(visible_ink<0.5 || fold_progress>=1.0){discard;}
 // Boundary is always source-bound. Interior ribbons are explicitly cosmetic
 // and may finish at a frozen hero brush point just beyond the source edge.
 if(fixed_boundary>0.5 && length(world_position.xz-domain_center.xz)>domain_radius){discard;}
 vec2 pixel=clamp(UV*vec2(1254,675),vec2(0.5,540.5),vec2(1253.5,616.5));
 vec4 plate=textureLod(landscape_atlas,pixel/1254.0,0.0);
 float density=clamp(1.0-dot(plate.rgb,vec3(0.2126,0.7152,0.0722)),0.0,1.0)*plate.a;
 float edge=smoothstep(0.0,0.12,UV2.y)*(1.0-smoothstep(0.60,1.0,UV2.y));
 float alpha=edge*mix(0.50,1.0,density);
 if(fixed_boundary>0.5){
  alpha*=0.32;
 }else{
  float tip=pow(max(0.0,sin(UV2.x*3.14159265)),0.55);
  float closing=smoothstep(0.0,0.15,fold_progress)*(1.0-smoothstep(0.96,1.0,fold_progress));
  // Brief directional unfold strokes; they disappear while the field holds.
  float opening=sin(clamp(unfold_progress,0.0,1.0)*3.14159265)*0.22;
  alpha*=tip*max(opening,closing*0.82);
 }
 if(alpha<0.002){discard;}
 ALBEDO=vec3(0.025,0.038,0.043);ALPHA=alpha;ROUGHNESS=1.0;SPECULAR=0.0;
}
