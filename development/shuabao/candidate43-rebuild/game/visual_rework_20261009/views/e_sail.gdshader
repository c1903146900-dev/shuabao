shader_type spatial;
render_mode cull_disabled;
uniform float age=0.0;
varying vec3 local;
void vertex(){
 float free=clamp(VERTEX.x/.9,0.0,1.0);
 VERTEX.z+=free*(.045*sin(VERTEX.y*5.0-age*2.3)+.018*sin(VERTEX.y*11.0-age*3.1));local=VERTEX;
}
void fragment(){
 float batten=pow(.5+.5*cos(local.y*25.0),15.0);
 float edge=smoothstep(.04,.18,local.x);
 ALBEDO=mix(vec3(.34,.36,.31),vec3(.70,.70,.59),edge)*(1.0-batten*.14);ROUGHNESS=.95;
}
