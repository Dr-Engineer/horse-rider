// toon.gdshader with a little life for the festival crowd. Each person in a crowd mesh carries UV2 = (arm type + own
// phase, signed arm weight): arm type 0 hands down, 1 clapping, 2 cheering with arms up; the weight grows from 0 at the
// shoulder to 1 at the hand and is negative for the left arm. People bob and sway at their own phases, the cheering ones
// hop and wave, the clapping ones bring their hands together. `phase_shift` is each crowd group's own offset.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform float class_id : hint_range(0.0, 1.0) = 0.5;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform vec3 tint : source_color = vec3(1.0);
uniform float rate = 3.4;

instance uniform vec3 slot_a : source_color = vec3(0.84, 0.23, 0.13);
instance uniform vec3 slot_b : source_color = vec3(0.95, 0.71, 0.2);
instance uniform vec3 slot_c : source_color = vec3(0.55, 0.35, 0.2);
instance uniform vec3 slot_d : source_color = vec3(0.09, 0.07, 0.08);
instance uniform float flash = 0.0;
instance uniform float phase_shift = 0.0;

void vertex() {
	float typ = floor(UV2.x + 0.0001);
	float ph = fract(UV2.x) * TAU + phase_shift * TAU;
	float t = TIME * rate + ph;
	float aw = abs(UV2.y);
	float side = UV2.y < 0.0 ? -1.0 : 1.0;
	float cheer = typ > 1.5 ? 1.0 : (typ > 0.5 ? 0.55 : 0.2);
	float body = smoothstep(0.15, 1.2, VERTEX.y);
	float hop = pow(max(0.0, sin(t)), 2.0) * 0.1 * cheer;
	VERTEX.y += hop;
	VERTEX.x += sin(t * 0.5) * 0.03 * body * cheer;
	if (typ > 1.5) {
		// arms up: waving
		VERTEX.y += aw * (0.1 + 0.1 * sin(t * 2.0 + 1.3));
		VERTEX.x += side * aw * 0.05 * sin(t);
	} else if (typ > 0.5) {
		// clapping: the hands meet in front
		VERTEX.x -= side * aw * 0.13 * (0.5 + 0.5 * sin(t * 2.0));
		VERTEX.y += aw * 0.03 * sin(t * 2.0);
	} else {
		VERTEX.z += aw * 0.05 * sin(t);
	}
}

void fragment() {
	vec3 c = texture(atlas, UV).rgb;
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
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
