shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;
uniform sampler2D erosion_map : filter_linear_mipmap, repeat_enable;
uniform float life : hint_range(0.0, 1.0) = 0.0;
uniform float strength = 1.0;
uniform float core = 0.0;
uniform vec4 silver : source_color = vec4(0.52, 0.62, 0.70, 1.0);
uniform vec4 oxblood : source_color = vec4(0.20, 0.018, 0.026, 1.0);
void fragment() {
	float vein = texture(erosion_map, vec2(UV.x * 1.6 - life * 0.25, UV.y)).r;
	float opening = smoothstep(0.0, 0.15, life);
	float ending = 1.0 - smoothstep(0.35, 1.0, life);
	float front = 1.0 - smoothstep(min(1.0, life * 6.0) - 0.12, min(1.0, life * 6.0), UV.x);
	float torn = smoothstep(0.12 + life * 0.22, 0.6 + life * 0.18, vein);
	float tip = pow(max(0.0, sin(UV.x * 3.14159)), 0.35);
	ALBEDO = mix(oxblood.rgb, silver.rgb, max(core, smoothstep(0.38, 0.76, vein)));
	EMISSION = ALBEDO * (0.30 + vein * 0.25) * strength;
	ALPHA = opening * ending * front * max(torn, core * 0.75) * tip * 0.75;
}
