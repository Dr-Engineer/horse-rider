// Grass tufts and other tiny ground cover: the toon light bands, a gentle sway, and no depth write, so the ink pass
// never outlines something a few pixels wide.
shader_type spatial;
render_mode cull_back, specular_disabled, depth_draw_never;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform float sway = 0.12;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float k = clamp(VERTEX.y / 0.9, 0.0, 1.0);
	VERTEX.x += sin(TIME * 2.3 + w.x * 0.55 + w.z * 0.7) * sway * k * k;
	VERTEX.z += cos(TIME * 1.9 + w.x * 0.4 - w.z * 0.6) * sway * 0.6 * k * k;
}

void fragment() {
	ALBEDO = texture(atlas, UV).rgb * COLOR.rgb;
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
}

void light() {
	float lit = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = smoothstep(band_low - 0.01, band_low + 0.01, lit) * mid_light
		+ smoothstep(band_high - 0.01, band_high + 0.01, lit) * (1.0 - mid_light);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
