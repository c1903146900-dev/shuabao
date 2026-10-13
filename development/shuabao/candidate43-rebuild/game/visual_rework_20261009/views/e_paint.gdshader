shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform float age=0.0;
uniform float presence=1.0;
uniform int mode=0;
uniform vec3 pigment=vec3(.12,.20,.22);
float hash21(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash21(i),hash21(i+vec2(1,0)),f.x),mix(hash21(i+vec2(0,1)),hash21(i+vec2(1,1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float alpha=0.0;vec3 c=pigment;
 if(mode==0){
  float slot=floor((p.x+p.y*.16)*12.0);
  float seed=hash21(vec2(slot,2.17));
  float lane=fract((p.x+p.y*.16)*12.0);
  float stroke=1.0-smoothstep(.025,.09,abs(lane-(.25+seed*.48)));
  float cell=fract(p.y*(1.3+seed*.8)+age*(2.1+seed*.8)+seed*7.0);
  float flow=smoothstep(.12,.21,cell)*(1.0-smoothstep(.39,.76,cell));
  float soft=exp(-p.x*p.x*4.4-p.y*p.y*2.8);
  float mist=noise(vec2(p.x*4.4+p.y*.2,p.y*3.1+age*1.8));
  alpha=(stroke*flow*.58+soft*smoothstep(.24,.65,mist)*.42)*(1.0-smoothstep(.76,1.0,length(p)));
  c=mix(vec3(.12,.20,.21),vec3(.57,.65,.62),stroke*flow*.70);
 }else if(mode==1){
  float r=length(p);float ring=1.0-smoothstep(.025,.085,abs(r-(.67+.018*sin(atan(p.y,p.x)*5.0+age*.8))));
  float angle=atan(p.y,p.x);float dry=.48+.52*smoothstep(-.55,.35,sin(angle*8.0+age*.6)+.4*sin(angle*17.0));
  alpha=ring*dry*.66+exp(-r*r*5.0)*.055;
  c=mix(pigment,vec3(.47,.53,.47),.3+.2*sin(angle*2.0-age));
 }else if(mode==2){
  float edge=(1.0-smoothstep(.5,1.0,abs(p.y)))*(1.0-smoothstep(.70,1.0,abs(p.x)));
  float thread=pow(.5+.5*sin(p.y*14.0+p.x*3.0-age*4.0),5.0);
  alpha=edge*(.11+thread*.25);c=mix(pigment,vec3(.54,.60,.56),thread*.65);
 }else if(mode==4){
  float r=length(vec2(p.x*.83,p.y*1.2));
  float wet=noise(vec2(p.x*3.2-age*.4,p.y*3.1+age*.6));
  float core=exp(-r*r*4.6);
  float edge=1.0-smoothstep(.35+.10*wet,.78+.10*wet,r);
  alpha=(core*.50+edge*.40)*(1.0-smoothstep(.80,1.0,r));
  c=mix(vec3(.055,.11,.12),vec3(.18,.29,.30),wet*.52);
 }else{
  float r=length(p);float front=clamp(age/.45,0.0,1.0);
  float ring=exp(-pow((r-front*.93)/.065,2.0));
  alpha=ring*(1.0-smoothstep(.16,.65,age))*.7;c=mix(pigment,vec3(.65,.69,.59),.45);
 }
 ALBEDO=c;ALPHA=alpha*presence;
}
