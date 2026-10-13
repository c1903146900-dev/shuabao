shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_always;
uniform sampler2D landscape_atlas : filter_linear,repeat_disable;
uniform vec3 peak_center=vec3(0.0);
uniform vec3 domain_center=vec3(0.0);
uniform float peak_radius=2.0;
uniform float domain_radius=10.0;
uniform float ground_y=0.0;
uniform float rise_offset=-2.0;
uniform float body_visible=0.0;
uniform float root_visible=0.0;
uniform float root_progress=0.0;
uniform float root_opacity=0.0;
uniform float rise_progress=0.0;
uniform float fade_progress=0.0;
uniform float harmless=0.0;
varying vec3 world_position;
varying float root_mask;
varying float face_tone;
varying vec2 stroke_coordinate;
varying float crown;
void vertex(){
 root_mask=COLOR.r;face_tone=COLOR.g;stroke_coordinate=UV2;crown=COLOR.b;
 if(root_mask<0.5){
  float lift=smoothstep(0.0,1.0,rise_progress);
  float settle=smoothstep(0.0,1.0,fade_progress);
  VERTEX.y=max(0.0,VERTEX.y)*lift*(1.0-settle);
  VERTEX.xz*=mix(0.70,1.0,lift)*(1.0-settle*0.58);
 }else{
  // A grounded outward load through the two existing root strokes, no ring.
  VERTEX.xz*=mix(0.82,1.0,smoothstep(0.0,0.75,root_progress));
 }
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment(){
 bool root=root_mask>0.5;
 if((!root && (body_visible<0.5 || rise_progress<=0.0)) || (root && root_visible<0.5) || fade_progress>=1.0){discard;}
 if(length(world_position.xz-peak_center.xz)>peak_radius || length(world_position.xz-domain_center.xz)>domain_radius){discard;}
 vec2 pixel=clamp(UV*vec2(1254,675),vec2(0.5),vec2(1253.5,674.5));
 if(root){pixel=clamp(pixel,vec2(0.5,540.5),vec2(1253.5,616.5));}
 vec4 plate=textureLod(landscape_atlas,pixel/1254.0,0.0);
 float lum=dot(plate.rgb,vec3(0.2126,0.7152,0.0722));
 float opacity=0.98;
 vec3 ink=vec3(0.02,0.03,0.035);
 if(root){
  float front=root_progress*1.16;
  float drawn=1.0-smoothstep(front-0.1,front+0.035,stroke_coordinate.x);
  float edge=1.0-smoothstep(0.65,1.0,abs(stroke_coordinate.y));
  opacity=plate.a*max(0.48,1.0-lum)*drawn*edge*root_opacity*(1.0-smoothstep(0.7,1.0,fade_progress));
 }else{
  // Continuous cool ink wash on the connected mountain. Fold normals change
  // value gently, avoiding hard metallic alternating triangle highlights.
  float wash=clamp(0.22+lum*0.68+(face_tone-0.50)*0.28,0.0,1.0);
  ink=mix(vec3(0.026,0.036,0.039),vec3(0.68,0.71,0.66),wash);
  // Atlas-derived dry brush follows the authored uphill UV flow. At the
  // irregular crown, small pale flecks read as flying-white ink, not shine.
  float dry=smoothstep(0.48,0.88,lum)*smoothstep(0.65,0.94,crown);
  ink=mix(ink,vec3(0.79,0.80,0.73),dry*0.40);
  float contact=smoothstep(0.0,0.30,world_position.y-ground_y);
  ink=mix(vec3(0.018,0.025,0.029),ink,mix(0.30,1.0,contact));
  opacity*=smoothstep(0.0,0.08,rise_progress)*(1.0-smoothstep(0.93,1.0,fade_progress));
 }
 opacity*=mix(1.0,0.68,harmless);
 if(opacity<0.005){discard;}
 ALBEDO=ink;ALPHA=opacity;ROUGHNESS=1.0;SPECULAR=0.0;
}
