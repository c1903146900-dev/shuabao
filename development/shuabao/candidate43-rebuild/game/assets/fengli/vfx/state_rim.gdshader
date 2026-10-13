shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never;
uniform float overload=0.0;
uniform float untargetable=0.0;
void fragment() {
 float edge=pow(1.0-clamp(dot(normalize(NORMAL),normalize(VIEW)),0.,1.),3.0);
 vec3 blood=vec3(.31,.048,.072);
 vec3 steel=vec3(.47,.62,.72);
 ALBEDO=mix(blood,steel,untargetable);
 ALPHA=edge*(overload*.30+untargetable*.34);
}
