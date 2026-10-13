shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform sampler2D authored_ink : source_color, filter_linear, repeat_disable;
uniform float source_age = 0.0;
uniform bool afterlayer = true;
uniform bool white_reserve_key = true;
void fragment() {
    vec4 pigment = texture(authored_ink,UV);
    float envelope = 1.0;
    if (afterlayer) {
        float darkness = 1.0-dot(pigment.rgb,vec3(0.333333));
        // Concentrated ink lifts first; only original thin dilute edges remain.
        // No directional cutoff, UV motion, advancing front or wall-clock TIME.
        float lift = smoothstep(0.045,0.20,source_age);
        envelope = (1.0-lift*(0.72+0.24*darkness))*(1.0-smoothstep(0.13,0.34,source_age));
    }
    ALBEDO = pigment.rgb;
    float reserve = white_reserve_key ? smoothstep(0.80,0.99,max(pigment.r,max(pigment.g,pigment.b))) : 0.0;
    ALPHA = pigment.a*envelope*(1.0-reserve);
    if (ALPHA < 0.022) discard;
}
