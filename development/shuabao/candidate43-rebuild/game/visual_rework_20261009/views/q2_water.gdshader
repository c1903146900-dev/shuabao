shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform float age=0.0;
uniform float source_lifetime=4.0;
uniform float river_length=12.0;
uniform float sun_energy=1.0;
uniform float layer=0.0;
uniform sampler2D flow_texture:source_color,filter_linear_mipmap;
varying float s;
varying float across;
void vertex(){
 s=UV.x*river_length;across=UV.y;
 VERTEX.y+=(.010*sin(s*2.5-age*1.9+across*.7)+.004*sin(s*6.1-age*4.2))*sin(UV.y*PI)*smoothstep(0.0,.55,age);
}
float moving_paint(float distance,float v,float speed,float spacing,vec4 region,float seed){
 float index=floor((distance-speed*age)/spacing);float density=0.0;
 for(int j=-1;j<=1;j++){
  float k=index+float(j);float center=k*spacing+.28*sin(k*1.7+seed)+speed*age;
  float length=3.7+.6*sin(k*1.31+seed);float u=(distance-center)/length+.5;
  if(u>0.0 && u<1.0){
   float y=clamp(.12+.76*v+.055*sin(k*2.1+seed),0.0,1.0);
   vec4 paint=texture(flow_texture,region.xy+vec2(u,y)*region.zw);
   float ends=smoothstep(0.0,.10,u)*(1.0-smoothstep(.89,1.0,u));
   density+=max(0.0,(paint.a-.00784)/.99216)*ends;
  }
 }
 return clamp(density,0.0,1.0);
}
void fragment(){
 float growth=smoothstep(0.0,.55,age);float side=abs(across-.5)*2.0;
 float phase=s*2.5+.26*sin(s*.7)-age*1.9+across*.7;
 float wave=pow(.5+.5*cos(phase),5.0);
 vec3 water=mix(vec3(.25,.345,.365),vec3(.35,.405,.39),smoothstep(.32,1.0,side));
 water+=vec3(.025,.031,.033)*wave;
 float flow_a=moving_paint(s,across,.52,4.0,vec4(.05582,.22329,.38517,.16746),.7);
 float flow_b=moving_paint(s+.9,across,.83,4.7,vec4(.55183,.22967,.41467,.16109),3.8);
 water=mix(water,vec3(.47,.525,.505),flow_a*.27);
 water=mix(water,vec3(.39,.47,.475),flow_b*.20);
 float sunset=exp(-pow((UV.x-.96)/.23,2.0))*(1.0-smoothstep(.5,1.0,side));
 float reflected=pow(max(0.0,cos(phase)),12.0)*(.3+.7*smoothstep(.05,.7,sin(across*17.0+s*.61-age*.4)));
 water=mix(water,vec3(.62,.48,.30),sunset*(reflected*.43+flow_b*.14)*sun_energy);
 ALBEDO=water;
 // Full-width damp fragments fade before the mesh boundary; never a pointed tip.
 float terminal=.985-.014*sin(across*11.0+.7)-.009*sin(across*23.0);
 float tail=1.0-smoothstep(terminal-.090,terminal,UV.x);
 float ends=smoothstep(-.01,.025,UV.x)*tail;
 float fill=.38+.62*smoothstep(side-.12,side+.12,.32+.68*growth);
 // Paint changes color only. The continuous bed never inherits atlas holes.
 float head=clamp((age-.20)/.62,0.0,1.0);
 float reveal=(1.0-smoothstep(head-.045,head,UV.x))*step(.201,age);
 ALPHA=reveal*fill*ends*(1.0-.42*smoothstep(max(0.0,source_lifetime-.5),source_lifetime,age))*.88;
}
