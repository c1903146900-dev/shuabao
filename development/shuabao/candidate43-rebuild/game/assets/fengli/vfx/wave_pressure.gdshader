shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform float edge_fade=1.;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) { vec2 c=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(c),hash(c+vec2(1.,0.)),f.x),mix(hash(c+vec2(0.,1.)),hash(c+vec2(1.)),f.x),f.y); }
void fragment() {
 float mass=noise(vec2(UV.x*13.,UV.y*6.));
 float bevel=pow(abs(cos(UV.y*6.2831853)),4.);
 float tips=pow(max(0.,sin(UV.x*3.14159265)),.35);
 ALBEDO=mix(vec3(.20,.035,.055),vec3(.70,.82,.90),.52+bevel*.35+mass*.10);
 ALPHA=smoothstep(.08,.40,mass+bevel*.26)*tips*edge_fade*.70;
}
