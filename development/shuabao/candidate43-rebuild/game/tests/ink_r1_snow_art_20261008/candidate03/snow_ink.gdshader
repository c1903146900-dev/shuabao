shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D landscape_atlas : filter_linear, repeat_disable;
uniform vec3 domain_center = vec3(0.0);
uniform float domain_radius = 1.0;
uniform float visible_ink = 0.0;
uniform float source_age = 0.0;
uniform float open_progress = 0.0;
uniform float close_progress = 0.0;
uniform vec2 opening_origin = vec2(0.0);
varying vec3 world_position;
varying vec4 brush_metadata;
varying vec2 brush_coordinate;
float hash21(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float wash_noise(vec2 p) {
 vec2 i = floor(p); vec2 f = fract(p); f = f*f*(3.0-2.0*f);
 return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 brush_metadata = COLOR; brush_coordinate = UV2;
 if (COLOR.r < 0.075) {
  float unfold = smoothstep(0.12+0.10*COLOR.g,0.93,open_progress);
  VERTEX.y = 0.05+(VERTEX.y-0.05)*unfold;
 }
 if (COLOR.r > 0.9) { VERTEX.xz += opening_origin*(1.0-UV2.x); }
 float gather = COLOR.b > 0.5 ? 0.0 : smoothstep(0.0,1.0,close_progress);
 float turn = gather*0.32;
 vec2 inward = VERTEX.xz-opening_origin;
 inward = mat2(vec2(cos(turn),sin(turn)),vec2(-sin(turn),cos(turn)))*inward;
 VERTEX.xz = opening_origin+inward*pow(max(0.0,1.0-gather),0.72);
 VERTEX.y = 0.018+(VERTEX.y-0.018)*(1.0-gather);
 world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
 vec2 p = (world_position.xz-domain_center.xz)/domain_radius;
 float radial = length(p);
 if (visible_ink < 0.5 || close_progress >= 1.0 || radial > 1.0) { discard; }
 float noise = 0.65*wash_noise(p*8.7+vec2(3.2,9.8))+0.35*wash_noise(p*21.3+vec2(12.9,1.4));
 float front = mix(0.035,1.94,smoothstep(0.0,1.0,open_progress));
 float written = 1.0-smoothstep(front-0.12,front+0.07,length(p-opening_origin)+0.06*(noise-0.5));
 float alpha = brush_metadata.a*written;
 vec3 ink = vec3(0.045,0.058,0.068);
 float s = brush_coordinate.x;
 if (brush_metadata.r < 0.075) {
  vec2 low = vec2(0.5,0.5); vec2 high = vec2(1253.5,674.5);
  if (brush_metadata.g > 0.25 && brush_metadata.g < 0.75) { low=vec2(0.5,699.5); high=vec2(647.5,982.5); }
  if (brush_metadata.g >= 0.75) { low=vec2(648.5,747.5); high=vec2(1253.5,988.5); }
  vec4 plate = textureLod(landscape_atlas,clamp(UV*1254.0,low,high)/1254.0,0.0);
  float luma = dot(plate.rgb,vec3(0.2126,0.7152,0.0722));
  // Continuous tonal separation, atmospheric far ink and strong nearer ridges.
  float snow = smoothstep(0.16,0.81,luma);
  vec3 shade = mix(vec3(0.30,0.36,0.38),vec3(0.025,0.04,0.052),brush_metadata.g);
  ink = mix(shade,vec3(0.91,0.95,0.97),snow);
  float ground_mist = smoothstep(0.0,0.25,brush_coordinate.y);
  alpha *= plate.a*ground_mist*(0.83+0.17*noise);
 } else if (brush_metadata.r < 0.22) {
  // Local elliptical washes feather into visible warm ground, never a disk.
  vec2 q = (UV-vec2(0.5))*2.0;
  float patch = 1.0-smoothstep(0.24,1.0,length(q)+0.22*(noise-0.5));
  alpha *= patch*(0.50+0.50*noise);
  ink = mix(vec3(0.76,0.84,0.88),vec3(0.96,0.98,0.99),noise);
 } else if (brush_metadata.r < 0.40) {
  float taper = pow(max(0.0,sin(3.14159265*s)),0.65);
  float bristles = 1.0-smoothstep(0.18,1.0,brush_coordinate.y);
  alpha *= taper*bristles*(0.25+0.75*noise);
  ink = mix(vec3(0.94,0.97,0.99),vec3(0.19,0.24,0.28),brush_coordinate.y);
 } else if (brush_metadata.r < 0.55) {
  float taper = 0.35+0.65*wash_noise(vec2(s*21.4,3.7));
  float crossfade = 0.25+0.75*sin(3.14159265*brush_coordinate.y);
  alpha *= taper*crossfade;
 } else if (brush_metadata.r < 0.62) {
  // A common winding foothill texture lies beneath the three mountain layers.
  // Existing lower atlas landscape sampled inside its own guarded cell.
  vec2 pixel = mix(vec2(20.5,1034.5),vec2(869.5,1200.5),UV);
  vec4 ground = textureLod(landscape_atlas,pixel/1254.0,0.0);
  float luma = dot(ground.rgb,vec3(0.2126,0.7152,0.0722));
  float ends = smoothstep(0.0,0.13,s)*(1.0-smoothstep(0.84,1.0,s));
  float crossfade = pow(max(0.0,sin(3.14159265*UV.y)),0.7);
  alpha *= ground.a*ends*crossfade*(0.55+0.45*noise);
  ink = mix(vec3(0.08,0.12,0.15),vec3(0.72,0.81,0.86),smoothstep(0.20,0.76,luma));
 } else if (brush_metadata.r < 0.9) {
  float gust = 0.75+0.25*wash_noise(vec2(s*5.1,source_age*0.15+brush_metadata.g*7.3));
  alpha *= gust*smoothstep(0.0,0.12,s)*(1.0-smoothstep(0.86,1.0,s))*(1.0-smoothstep(0.1,1.0,abs(brush_coordinate.y)));
  ink = mix(vec3(0.43,0.52,0.57),vec3(0.94,0.98,1.0),smoothstep(-0.3,0.35,brush_coordinate.y));
 } else {
  float stroke = 1.0-smoothstep(open_progress*1.18-0.04,open_progress*1.18+0.04,s);
  alpha = stroke*(1.0-smoothstep(0.55,1.0,open_progress))*(1.0-smoothstep(0.35,1.0,abs(brush_coordinate.y)))*0.64;
  ink = mix(vec3(0.035,0.055,0.07),vec3(0.93,0.97,0.99),smoothstep(0.30,0.80,brush_coordinate.y));
 }
 // Continuous wash dispersion: no periodic perforations, lattice or dot masks.
 alpha *= (1.0-close_progress*0.48)*(1.0-smoothstep(0.78,1.0,close_progress));
 if (brush_metadata.b > 0.5) {
  // Remains fixed at actual radius until expiry, but never a thick opaque UI ring.
  alpha = brush_metadata.a*(0.32+0.68*wash_noise(vec2(s*24.7,4.1)))*(0.35+0.65*sin(3.14159265*brush_coordinate.y));
  ink = vec3(0.075,0.10,0.12);
 }
 if (alpha < 0.003) { discard; }
 ALBEDO = ink; ALPHA = clamp(alpha,0.0,0.82); ROUGHNESS = 1.0; SPECULAR = 0.0;
}
