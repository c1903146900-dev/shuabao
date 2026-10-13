shader_type spatial;
render_mode cull_back;
uniform vec3 stone_color=vec3(.5,.4,.3);
uniform float presence=1.0;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 float row=floor(local.y/.18);
 float vertical=abs(fract((local.x+local.z)/.32+mod(row,2.0)*.5)-.5);
 float horizontal=abs(fract(local.y/.18)-.5);
 float mortar=max(smoothstep(.455,.50,vertical),smoothstep(.43,.50,horizontal));
 float variation=.94+.06*sin(floor((local.x+local.z)*9.0)*2.8+row*1.4);
 ALBEDO=stone_color*variation*(1.0-mortar*.24);ROUGHNESS=.95;
 ALPHA=presence;
}
