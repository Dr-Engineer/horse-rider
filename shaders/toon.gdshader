// Master material for every model in the game. docs/STYLE_GUIDE.md section "Light and shade".
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
// Encoded into ROUGHNESS, read by ink.gdshader. Riders 0.2, props 0.5, terrain 0.85.
uniform float class_id : hint_range(0.0, 1.0) = 0.5;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform float rim_strength = 0.0;
uniform vec3 tint : source_color = vec3(1.0);

instance uniform vec3 slot_a : source_color = vec3(0.84, 0.23, 0.13);
instance uniform vec3 slot_b : source_color = vec3(0.95, 0.71, 0.2);
instance uniform vec3 slot_c : source_color = vec3(0.55, 0.35, 0.2);
instance uniform vec3 slot_d : source_color = vec3(0.09, 0.07, 0.08);
instance uniform float flash = 0.0;

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
	// Row 0 of the atlas holds grey cells multiplied by per-instance colours.
	if (UV.y < 0.03125 && UV.x < 0.5) {
		float slot = floor(UV.x * 8.0);
		vec3 team = slot < 1.0 ? slot_a : (slot < 2.0 ? slot_b : (slot < 3.0 ? slot_c : slot_d));
		c *= team;
	}
	ALBEDO = mix(c * COLOR.rgb * tint, vec3(1.0, 0.95, 0.85), flash);
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = class_id;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float lit = ndl * ATTENUATION;
	float band = smoothstep(band_low - 0.01, band_low + 0.01, lit) * mid_light
		+ smoothstep(band_high - 0.01, band_high + 0.01, lit) * (1.0 - mid_light);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0) * rim_strength * step(0.0, ndl);
	DIFFUSE_LIGHT += (band + rim) * LIGHT_COLOR / PI;
}
