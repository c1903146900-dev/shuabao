shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_prepass_alpha;
uniform sampler2D painting:source_color,filter_linear_mipmap;
uniform vec4 region=vec4(.1888,.0327,.1460,.9110);
uniform float age=0.0;
uniform bool sail=false;
void vertex(){
 if(sail){float free=clamp(VERTEX.x/1.05,0.0,1.0);VERTEX.z+=free*(.045*sin(VERTEX.y*4.8-age*2.15)+.018*sin(VERTEX.y*10.3-age*3.4));}
}
void fragment(){
 vec4 c=texture(painting,region.xy+UV*region.zw);
 float a=max(0.0,(c.a-.008)/.992);
 if(a<.015){discard;}
 ALBEDO=c.rgb*(.94+.03*sin(age*.6));ALPHA=a;
}
