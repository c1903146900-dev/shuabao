shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled;
// The approved Q1 paint provides all grain and erosion. Regraded for a readable
// bronze body / ivory crest at gameplay zoom, without additive white bloom.
uniform sampler2D art_texture : source_color, filter_linear_mipmap, repeat_disable;
uniform sampler2D erosion_texture : filter_linear_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity : hint_range(0.0,1.0) = 1.0;
uniform float erosion : hint_range(0.0,1.0) = 0.0;
uniform float erosion_strength = 1.0;
uniform float reveal = 1.0;
uniform float directional_reveal = 0.0;
uniform vec2 erosion_offset = vec2(0.0);
void fragment() {
    vec4 art = texture(art_texture, UV);
    float grain = texture(erosion_texture, UV * vec2(2.11,1.13) + erosion_offset).r;
    float dissolve = 1.0 - smoothstep(grain - 0.10, grain + 0.10, erosion * 1.02);
    float crest = smoothstep(0.18,0.52,art.g);
    vec3 bronze = mix(vec3(0.17,0.095,0.042),vec3(0.54,0.35,0.15),art.r);
    vec3 paint = mix(bronze,vec3(0.89,0.81,0.61),crest);
    ALBEDO = paint * tint.rgb * COLOR.rgb;
    ALPHA = art.a * tint.a * opacity * mix(1.0,dissolve,erosion_strength) * COLOR.a;
}
