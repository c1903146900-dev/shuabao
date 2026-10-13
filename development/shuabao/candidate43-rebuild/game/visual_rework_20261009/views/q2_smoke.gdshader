shader_type spatial;
render_mode unshaded,cull_back,blend_mix,depth_draw_never;
uniform float flow_time=0.0;
uniform float strength=1.0;
uniform vec3 root_world=vec3(0.0);
uniform vec3 eye_direction=vec3(0.0,-.64,-.77);
varying vec3 world_point;
float hash3(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise3(vec3 p){
 vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 float z0=mix(mix(hash3(i),hash3(i+vec3(1,0,0)),f.x),mix(hash3(i+vec3(0,1,0)),hash3(i+vec3(1,1,0)),f.x),f.y);
 float z1=mix(mix(hash3(i+vec3(0,0,1)),hash3(i+vec3(1,0,1)),f.x),mix(hash3(i+vec3(0,1,1)),hash3(i+vec3(1,1,1)),f.x),f.y);
 return mix(z0,z1,f.z);
}
float density_at(vec3 p){
 if(p.y<0.0 || p.y>3.05){return 0.0;}
 float y=p.y;
 float arrived=1.0-smoothstep(flow_time*1.75-.18,flow_time*1.75+.12,y);
 float bend=.044*y*y;
 vec2 center=vec2(bend,-bend*.32);
 float width=.105+.14*y;
 vec2 q=(p.xz-center)/vec2(width,width*.79);
 vec3 advected=vec3(p.x*4.2,y*2.15-flow_time*1.40,p.z*4.2);
 float large=noise3(advected);
 float fine=noise3(advected*2.10+vec3(2.1,-flow_time*.24,1.7));
 float gaps=smoothstep(.30,.66,large*.72+fine*.28);
 float core=exp(-dot(q,q)*1.60)*(.055+gaps*.92);
 // Overlapping rising folds breathe locally and do not wave the whole column.
 float folds=0.0;
 for(int i=0;i<3;i++){
  float z=float(i)*.93;
  float a=mod(flow_time+z,2.80);
  float h=.30+a*.88;
  vec2 offset=vec2(.11*sin(z*3.7+a*.38),.075*cos(z*2.8));
  vec3 r=vec3((p.xz-center-offset)/vec2(.17+.105*a,.15+.086*a),(y-h)/(.22+.09*a));
  float mass=exp(-dot(r,r)*1.25);
  folds+=mass*gaps*smoothstep(0.0,.24,a)*(1.0-smoothstep(2.25,2.8,a))*.55;
 }
 float filament=exp(-dot(q,q)*5.0)*.25*(1.0-smoothstep(.4,1.7,y));
 float neck=exp(-dot(p.xz,p.xz)/.040)*(1.0-smoothstep(.30,.70,y))*1.4;
 float top=1.0-smoothstep(1.88,3.02,y);
 return (core+folds+filament+neck)*mix(1.0,.73,smoothstep(.25,1.0,dot(q,q)))*top*smoothstep(0.0,.075,y)*arrived*1.28;
}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec3 direction=normalize(eye_direction);
 vec3 p=world_point-root_world+direction*.002;
 vec3 low=vec3(-.75,0.0,-.825),high=vec3(1.45,3.05,.825);
 vec3 safe=direction;
 if(abs(safe.x)<.00001){safe.x=.00001;}
 if(abs(safe.y)<.00001){safe.y=.00001;}
 if(abs(safe.z)<.00001){safe.z=.00001;}
 vec3 t0=(low-p)/safe,t1=(high-p)/safe;
 vec3 far3=max(t0,t1);
 float length=max(0.0,min(far3.x,min(far3.y,far3.z)));
 float step_size=length/16.0;
 vec3 color=vec3(0.0);float alpha=0.0;
 for(int i=0;i<16;i++){
  vec3 sample_at=p+direction*((float(i)+.5)*step_size);
  float density=density_at(sample_at);
  if(density>.008){
   float shadow=density_at(sample_at+vec3(-.10,.10,.07));
   float light=clamp(.62+(density-shadow)*.70,.22,1.0);
   vec3 pigment=mix(vec3(.060,.067,.085),vec3(.29,.285,.325),light*.60);
   float upper=smoothstep(1.15,2.90,sample_at.y);
   pigment=mix(pigment,vec3(.48,.435,.38),upper*.58);
   density*=1.0-upper*.24;
   float a=1.0-exp(-density*step_size*2.10*strength);
   color+=(1.0-alpha)*a*pigment;alpha+=(1.0-alpha)*a;
  }
 }
 ALBEDO=color/max(alpha,.0001);ALPHA=alpha;
}
