shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform sampler2D painting : source_color;
uniform float open=0.0;
uniform float age=0.0;
void fragment(){
 vec2 uv=(UV-.5)*vec2(20.0/15.2,20.0/7.0)+.5;
 vec4 c=texture(painting,uv);
 float edge=1.0-smoothstep(open*.5-.012,open*.5,abs(UV.x-.5));
 float cloud=.5+.5*sin(UV.y*12.0+UV.x*3.0-age*.24);
 ALBEDO=mix(c.rgb,vec3(.72,.75,.72),cloud*.14);
 float round_edge=1.0-smoothstep(.83,1.0,length((UV-.5)*2.0));
 float painted_bounds=step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
 ALPHA=c.a*.34*edge*round_edge*painted_bounds;
}
