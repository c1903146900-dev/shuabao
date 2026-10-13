shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
uniform float age=0.0;
uniform float remaining=1.0;
float hash2(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float mist(vec2 p){vec2 c=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash2(c),hash2(c+vec2(1,0)),f.x),mix(hash2(c+vec2(0,1)),hash2(c+vec2(1,1)),f.x),f.y);}
void vertex(){
 MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0]*length(MODEL_MATRIX[0].xyz),INV_VIEW_MATRIX[1]*length(MODEL_MATRIX[1].xyz),INV_VIEW_MATRIX[2]*length(MODEL_MATRIX[2].xyz),MODEL_MATRIX[3]);
}
void fragment(){
 vec2 p=UV*2.0-1.0;
 float noise=mist(p*3.2+vec2(age*.07,-age*.11));
 float r=length(p*vec2(1.0,.86));
 float cloud=(1.0-smoothstep(.23,.96,r+noise*.17))*(.38+.62*noise);
 ALBEDO=vec3(.29,.37,.23);
 ALPHA=cloud*.18*smoothstep(0.0,.30,remaining);
}
