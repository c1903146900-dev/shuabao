shader_type spatial;
render_mode unshaded,cull_disabled,blend_mix,depth_draw_never;
uniform vec4 tint:source_color=vec4(.8,.77,.65,.8);
uniform float effect_radius=10.0;
uniform vec3 effect_center=vec3(0.0);
varying vec3 world_pos;
void vertex(){world_pos=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){float edge=1.0-smoothstep(effect_radius*.83,effect_radius,length(world_pos.xz-effect_center.xz));ALBEDO=tint.rgb;ALPHA=tint.a*edge;}
