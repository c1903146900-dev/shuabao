shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform float age=0.0;
uniform float source_lifetime=4.0;
uniform float river_length=12.0;
uniform float layer=0.0;
uniform sampler2D dust_texture:source_color,filter_linear_mipmap;
void fragment(){
 float x=(UV.x-.34)/.58-age*.018*(.6+UV.y);
 float y=(UV.y-.16)/.71;
 float domain=step(0.0,x)*step(x,1.0)*step(0.0,y)*step(y,1.0);
 vec4 pigment=texture(dust_texture,vec2(clamp(x,0.0,1.0),clamp(y,0.0,1.0)/3.0));
 float mass=exp(-pow((UV.x-.65)/.25,2.0)-pow((UV.y-.48)/.36,2.0));
 float alpha=max(0.0,(pigment.a-.00784)/.99216);
 ALBEDO=mix(pigment.rgb,vec3(.52,.425,.385),.30);
 ALPHA=alpha*mass*domain*.10*smoothstep(.20,.80,age)*(1.0-.46*smoothstep(max(0.0,source_lifetime-.5),source_lifetime,age));
}
