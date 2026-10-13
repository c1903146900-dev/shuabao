shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform sampler2D landscape_atlas : source_color,filter_linear_mipmap;
uniform float age=0.0;
uniform float cell=0.0;
uniform float opacity=.70;
uniform float dissolve=0.0;
uniform float exchange_progress=-1.0;
uniform vec3 partner_center=vec3(0.0);
uniform float partner_radius=0.0;
varying vec3 world_point;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
vec4 painting(vec2 uv,float index){
 uv=clamp(uv,vec2(.002),vec2(.998));
 return texture(landscape_atlas,vec2((uv.x+index)*.5,uv.y));
}
void vertex(){world_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 uv=UV;
 float radius=length((uv-.5)*2.);
 float edge_noise=noise(uv*18.)*.045+noise(uv*43.)*.018;
 float rim=1.-smoothstep(.73+edge_noise,1.,radius);
 // Only the painted lower water is displaced; the rock silhouettes are stationary.
 float water=smoothstep(.60,.73,uv.y)*smoothstep(.18,.40,uv.x)*(1.-smoothstep(.83,.96,uv.x));
 float waterfall=cell*exp(-pow((uv.x-(.837-.08*(uv.y-.38)))/.018,2.))*smoothstep(.30,.39,uv.y)*(1.-smoothstep(.62,.72,uv.y));
 vec2 displacement=vec2(sin(uv.y*85.-age*2.1),sin(uv.x*71.+age*1.7))*.0025*water;
 displacement.y+=sin(uv.y*96.-age*4.2)*.002*waterfall;
 vec4 art=painting(uv+displacement,cell);
 if(exchange_progress>=0.){
  float inkfront=smoothstep(.0,.75,exchange_progress);
  float cross_x=mix(uv.x,1.-uv.x,cell);
  float seep=smoothstep(cross_x*.65+noise(uv*15.)*.19-.12,cross_x*.65+noise(uv*15.)*.19+.15,inkfront);
  art=mix(art,painting(uv-displacement,1.-cell),seep);
 }
 float paper=dot(art.rgb,vec3(.299,.587,.114));
 float richness=clamp(1.-paper,0.,1.);
 // Genuine painting colour retained, low-alpha paper and fringe desaturation.
 vec3 color=mix(vec3(paper),art.rgb,.72);
 float saturated=max(color.r,max(color.g,color.b))-min(color.r,min(color.g,color.b));
 color=mix(color,vec3(paper),smoothstep(.20,.48,saturated)*(1.-art.a));
 float water_noise=noise(vec2(uv.x*19.-age*.7,uv.y*65.+age*.24));
 float ripple=smoothstep(.68,.91,water_noise)*(.5+.5*sin(uv.y*164.+uv.x*13.-age*3.3));
 color+=water*(ripple-.20)*.20;
 float stream1=exp(-pow((uv.y-(.755+.018*sin(uv.x*9.)))/.012,2.));
 float stream2=exp(-pow((uv.y-(.858+.015*sin(uv.x*7.+1.)))/.009,2.));
 float streaks=(stream1+stream2)*smoothstep(.23,.55,noise(vec2(uv.x*13.-age*1.5,1.7)));
 color=mix(color,vec3(.72,.79,.75),water*streaks*.35);
 color+=waterfall*(.5+.5*sin(uv.y*130.-age*5.8))*.09;
 // Crossing strata are local cloud/ink motion, not whole-picture wobble.
 float mist_band=exp(-pow((uv.y-(.43+.055*sin(uv.x*7.)))/.10,2.));
 float mist=noise(vec2(uv.x*8.-age*.24,uv.y*16.+cell*3.))*noise(vec2(uv.x*17.-age*.41,uv.y*8.));
 color=mix(color,vec3(.72,.77,.73),mist_band*mist*.45);
 float mist_head=fract(age*.19+cell*.37);
 float drift=exp(-pow((uv.x-mist_head)/.18,2.))*exp(-pow((uv.y-(.47+.04*sin(uv.x*5.+cell)))/.045,2.));
 color=mix(color,vec3(.74,.79,.73),drift*.32);
 float born=.18+.82*smoothstep(.0,.42,age-radius*.08+noise(uv*12.)*.07);
 float wash_alpha=.21+.68*pow(richness,.65);
 float overlap=partner_radius>0. ? 1.-smoothstep(partner_radius*.65,partner_radius,distance(world_point.xz,partner_center.xz)) : 0.;
 ALBEDO=color;
 ALPHA=art.a*rim*wash_alpha*opacity*born*(1.-dissolve)/(1.+overlap*.35);
}
