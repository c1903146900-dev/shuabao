shader_type spatial;
render_mode unshaded,cull_disabled;
uniform float age=0.0;
uniform float fade=1.0;
varying vec3 local_position;
varying vec3 local_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){local_position=VERTEX;local_normal=NORMAL;}
void fragment(){
 float brush=noise(vec2(UV.x*55.0+noise(UV*9.0)*1.5,UV.y*4.0));
 float grain=noise(UV*vec2(190.,55.));
 float crease=smoothstep(.15,.85,brush);
 float lighting=.5+.5*abs(dot(normalize(local_normal),normalize(vec3(-.8,1.,1.))));
 vec3 ink=mix(vec3(.10,.16,.15),vec3(.46,.50,.43),crease*lighting);
 ink=mix(ink,vec3(.48,.41,.31),noise(UV*7.0)*.13);
 ink+=(grain-.5)*.045;
 ALBEDO=ink;ROUGHNESS=1.;
 float edge=min(min(UV.x,1.-UV.x)*4.5,min(UV.y,1.-UV.y)*1.4);
 ALPHA=fade*smoothstep(.005,.10+noise(UV*31.)*.065,edge);
}
