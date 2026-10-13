shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform float age=0.0;
uniform float source_lifetime=4.0;
uniform float layer=0.0;
uniform float river_length=12.0;
uniform sampler2D pigment_texture:source_color,filter_linear_mipmap;
uniform sampler2D stroke_texture:source_color,filter_linear_mipmap;
varying vec3 n_world;
void vertex(){
 float growth=.35+.65*smoothstep(0.0,.55,age);
 VERTEX.y=.046+(VERTEX.y-.046)*growth;n_world=NORMAL;
}
float dry_segment(float u,float across,float ridge,float start,float finish,float seed){
 float x=(u-start)/(finish-start);
 float y=.5+(across-ridge)/.42;
 if(x<0.0 || x>1.0 || y<0.0 || y>1.0){return 0.0;}
 vec4 paint=texture(stroke_texture,vec2(.05582+x*.38517,.22329+y*.16746));
 float ends=smoothstep(0.0,.08,x)*(1.0-smoothstep(.9,1.0,x));
 return max(0.0,(paint.a-.00784)/.99216)*ends*(.74+.26*sin(x*19.0+seed));
}
void fragment(){
 float u=UV.x;float across=UV.y;
 float presence=.30+.70*smoothstep(0.0,.55,age);
 float illumination=.68+.32*max(0.0,dot(normalize(n_world),normalize(vec3(-.25,.91,.34))));
 float wet=1.0-smoothstep(.02,.18,across);
 vec4 pigment=texture(pigment_texture,vec2(.04+.92*clamp(u,0.0,1.0),.15+.68*across));
 float deposit=(1.0-dot(pigment.rgb,vec3(.299,.587,.114)))*pigment.a;
 // Preserve the broad wash's warm light and cool deposits, not only dark luma.
 float warm_light=clamp(dot(pigment.rgb,vec3(.299,.587,.114)),0.0,1.0);
 vec3 sand=mix(vec3(.49,.435,.35),vec3(.65,.59,.47),warm_light*pigment.a*.72);
 sand=mix(sand,vec3(.39,.365,.32),deposit*.60);
 sand+=vec3(.020,.004,-.012)*pigment.a;
 vec3 cool_wet=vec3(.325,.37,.345);
 vec3 land=mix(sand,cool_wet,wet*.66)*illumination;
 float ridge=UV2.y;
 float dry=dry_segment(u,across,ridge,.28,.53,.7);
 if(layer>.5){dry*=.35;}
 land=mix(land,vec3(.24,.22,.19),clamp(dry,0.0,1.0)*.24);
 ALBEDO=land;
 float fade_start=.51+.06*sin(u*7.3+.8)+.035*sin(u*16.1);
 float outside=1.0-smoothstep(fade_start,.93-.035*sin(u*11.3+.8),across);
 float terminal=.983-.018*sin(across*9.1+.7);
 float ends=smoothstep(-.01,.025,u)*(1.0-smoothstep(terminal-.085,terminal,u));
 float head=clamp((age-.20)/.62,0.0,1.0);
 float reveal=(1.0-smoothstep(head-.045,head,UV.x))*step(.201,age);
 ALPHA=reveal*outside*ends*presence*mix(.38,.24,step(.5,layer))*(1.0-.36*smoothstep(max(0.0,source_lifetime-.5),source_lifetime,age));
}
