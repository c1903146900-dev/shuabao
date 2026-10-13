shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform float open=1.0;
void fragment(){
 vec2 p=vec2((UV.x-.5)*open,UV.y-.5)*2.0;
 float round_edge=1.0-smoothstep(.83,1.0,length(p));
 ALBEDO=vec3(.79,.77,.67);ALPHA=.29*round_edge;
}
