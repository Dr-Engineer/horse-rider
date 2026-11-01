// Prayer flags: same stepped toon light as everything else, with a vertex wave that grows toward the hem.
// UV2.x is how far the vertex hangs below the string, 0 at the string and 1 at the hem.
shader_type spatial;
render_mode cull_disabled, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform float class_id : hint_range(0.0, 1.0) = 0.5;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform float amplitude = 0.28;
uniform float rate = 4.2;
uniform vec2 wind = vec2(0.8, 0.6);

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float ph = TIME * rate + dot(w.xz, wind) * 0.9;
	float k = UV2.x;
	VERTEX.z += (sin(ph) * 0.7 + sin(ph * 2.3 + 1.7) * 0.3) * amplitude * k;
	VERTEX.x += sin(ph * 1.3 + 0.6) * amplitude * 0.25 * k * k;
}

void fragment() {
	ALBEDO = texture(atlas, UV).rgb * COLOR.rgb;
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = class_id;
	SPECULAR = 0.0;
}

void light() {
	float lit = abs(dot(NORMAL, LIGHT)) * ATTENUATION;
	float band = smoothstep(band_low - 0.01, band_low + 0.01, lit) * mid_light
		+ smoothstep(band_high - 0.01, band_high + 0.01, lit) * (1.0 - mid_light);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
