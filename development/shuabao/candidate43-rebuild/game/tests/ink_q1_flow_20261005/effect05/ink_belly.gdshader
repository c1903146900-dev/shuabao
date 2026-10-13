shader_type spatial;
render_mode unshaded, cull_disabled, depth_prepass_alpha;
uniform sampler2D pigment : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 dark_ink : source_color = vec4(0.028,0.050,0.060,1.0);
uniform vec4 dilute_ink : source_color = vec4(0.21,0.32,0.33,1.0);
// Fixed alpha-support envelope measured from the original authored PNG. This
// follows its loaded brush through the image, rather than sampling a rectangle
// that mostly contains transparent background at the beginning of the cast.
vec2 pigment_bounds(float x) {
    if (x<0.50) return mix(vec2(0.679,0.865),vec2(0.372,0.778),smoothstep(0.36,0.50,x));
    if (x<0.58) return mix(vec2(0.372,0.778),vec2(0.254,0.715),smoothstep(0.50,0.58,x));
    if (x<0.72) return mix(vec2(0.254,0.715),vec2(0.101,0.660),smoothstep(0.58,0.72,x));
    if (x<0.86) return mix(vec2(0.101,0.660),vec2(0.105,0.696),smoothstep(0.72,0.86,x));
    return mix(vec2(0.105,0.696),vec2(0.143,0.601),smoothstep(0.86,0.92,x));
}
void fragment() {
    // UV is still one fixed source-arc/full-width field, common to BOTH layers.
    // No front, time, screen coordinates or moving per-wave sampler window.
    float s=UV.x;
    float v=UV.y;
    float across=COLOR.b;
    float field_center=0.34+0.15*smoothstep(0.0,0.65,s)-0.055*smoothstep(0.64,1.0,s);
    float field_pressure=mix(0.24,0.97,smoothstep(0.0,0.23,s))*mix(1.0,0.40,smoothstep(0.38,1.0,s));
    float field_radius=0.40*field_pressure;
    float pigment_across=clamp((v-(field_center-0.74*field_radius))/(1.84*field_radius),0.0,1.0);
    float paint_x=0.36+0.56*s;
    vec2 bounds=pigment_bounds(paint_x);
    float paint_y=mix(bounds.x-0.014,bounds.y+0.014,pigment_across);
    vec4 paint=texture(pigment,vec2(paint_x,paint_y));
    float load=dot(paint.rgb,vec3(0.299,0.587,0.114));
    float edge=smoothstep(0.0,0.07,across)*(1.0-smoothstep(0.83,1.0,across));
    float wet_side=smoothstep(0.29,0.93,across);
    float tone=clamp(COLOR.r+0.78*load+0.12*wet_side,0.0,1.0);
    float ink_load=pow(clamp(1.0-load,0.0,1.0),0.80);
    // Transparent source pixels stay transparent. The original wet edges and
    // local fly-white are consumed directly, with no added alpha floor or a
    // separate slit that can drift outside the narrowing moving silhouette.
    ALBEDO=mix(dark_ink.rgb,dilute_ink.rgb,tone);
    ALPHA=COLOR.a*paint.a*ink_load*edge;
    ROUGHNESS=1.0;
    SPECULAR=0.0;
}
