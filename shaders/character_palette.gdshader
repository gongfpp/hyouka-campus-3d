shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
// glTF COLOR_0 is linear. Compatibility shades in sRGB; Forward+/Mobile do not.
// This is a color-space transfer, shared by every palette channel, not a skin tint.
uniform float palette_roughness = 0.85;
uniform float palette_metallic = 0.0;
uniform float palette_specular = 0.5;
vec3 linear_to_srgb(vec3 value) {
	vec3 low = value * 12.92;
	vec3 high = 1.055 * pow(max(value, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055;
	return mix(high, low, lessThanEqual(value, vec3(0.0031308)));
}
void fragment() {
	ALBEDO = OUTPUT_IS_SRGB ? linear_to_srgb(COLOR.rgb) : COLOR.rgb;
	ROUGHNESS = palette_roughness;
	METALLIC = palette_metallic;
	SPECULAR = palette_specular;
}
