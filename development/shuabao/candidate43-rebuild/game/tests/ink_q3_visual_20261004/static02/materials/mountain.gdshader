shader_type spatial;
render_mode cull_disabled, diffuse_burley, specular_disabled;
uniform sampler2D authored_brush : source_color, filter_linear, repeat_disable;
uniform vec3 wet_ink : source_color = vec3(0.19, 0.29, 0.26);
uniform vec3 dry_reserve : source_color = vec3(0.81, 0.84, 0.72);
uniform vec3 actor_feet[16];
uniform int actor_count = 0;
uniform bool preserve_actor_readability = true;
varying vec3 world_vertex;
void vertex() { world_vertex = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
    // Only occluding mountain pixels near actual detached actor positions are cut.
    // This cannot alter terrain collision; the continuous ground seam is separate.
    if (preserve_actor_readability && world_vertex.y > 0.08) {
        for (int i=0; i<16; i++) {
            if (i >= actor_count) break;
            vec3 foot = (VIEW_MATRIX * vec4(actor_feet[i],1.0)).xyz;
            vec2 delta = VERTEX.xy - foot.xy;
            float edge = max(abs(delta.x)/0.48, abs(delta.y-0.58)/0.77);
            if (VERTEX.z > foot.z-0.10 && edge < 1.0) discard;
        }
    }
    vec4 ink = texture(authored_brush, UV);
    vec3 tone = mix(COLOR.rgb, wet_ink, ink.r * 0.59);
    ALBEDO = mix(tone, dry_reserve, ink.g * 0.83);
    ROUGHNESS = 1.0;
    METALLIC = 0.0;
}
