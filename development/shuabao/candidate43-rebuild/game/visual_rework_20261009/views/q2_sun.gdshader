shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform float age=0.0;
uniform float source_lifetime=4.0;
uniform float sun_energy=1.0;
uniform sampler2D pigment_texture:source_color,filter_linear_mipmap;
uniform sampler2D dust_texture:source_color,filter_linear_mipmap;
float haze(vec2 p){return sin(p.x*2.6+sin(p.y*3.2))*.5+.5;}
void fragment(){
 vec2 p=(UV-.5)*2.0;
 float radius=.82+.004*sin(atan(p.y,p.x)*7.0);
 float disk=1.0-smoothstep(radius-.022,radius+.022,length(p));
 float horizon_y=-.04+.012*sin(p.x*5.0)+.007*sin(p.x*13.0);
 float horizon=smoothstep(horizon_y-.035,horizon_y+.075,p.y);
 float growth=smoothstep(0.0,.18,age);
 vec4 paper=texture(pigment_texture,vec2(.10+UV.x*.75,.16+UV.y*.68));
 float grain=dot(paper.rgb,vec3(.299,.587,.114));
 vec3 color=mix(vec3(.52,.15,.09),vec3(.88,.46,.21),smoothstep(-.05,.80,p.y));
 color*=.90+.16*grain;
 float cloud1=p.y-.20-.024*sin(p.x*6.0-age*.47);
 float cloud2=p.y-.52-.017*sin(p.x*4.5-age*.33);
 float cloud=exp(-cloud1*cloud1/.0015)*(.3+.7*haze(vec2(p.x*3.0-age*.35,p.y)))*.48;
 cloud+=exp(-cloud2*cloud2/.0008)*(.3+.7*haze(vec2(p.x*4.0-age*.27,p.y+2.0)))*.24;
 vec3 solar=mix(color,vec3(.38,.25,.20),cloud);
 float ridge=exp(-pow((p.y-horizon_y)/.026,2.0))*(1.0-smoothstep(.64,1.0,abs(p.x)))*.40;
 float solar_alpha=disk*horizon*.85;
 float fog=exp(-pow((p.y-horizon_y+.012)/.067,2.0))*(1.0-smoothstep(.76,1.0,abs(p.x)))*.23;
 ALBEDO=mix(solar,vec3(.45,.385,.305),max(ridge,fog*1.6))*(.94+.06*sun_energy);
 ALPHA=max(solar_alpha,max(ridge,fog))*growth*(1.0-.38*smoothstep(max(0.0,source_lifetime-.5),source_lifetime,age));
}
