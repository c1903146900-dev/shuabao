shader_type spatial;
render_mode cull_disabled, blend_mix;
uniform float age=0.0;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void fragment(){float fold=pow(abs(sin(UV.x*31.0+sin(UV.y*8.0)*1.1)),4.0);float grain=hash(floor(UV*420.0));ALBEDO=mix(vec3(.12,.29,.28),vec3(.31,.49,.36),UV.y)*(.75+.25*fold)+vec3(grain*.025);ROUGHNESS=.94;ALPHA=(1.0-smoothstep(.21,.3,age))*smoothstep(0.0,.015,age);}
