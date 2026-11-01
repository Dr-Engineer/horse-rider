// Terrain: flat facets coloured per triangle (vertex colour is authored in sRGB), plus a world-space pixel
// speckle that sells speed. Same three light bands as the toon shader.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform float speckle_density = 2.0;
uniform float speckle_strength = 0.06;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;

varying vec3 world_pos;
varying float view_dist;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	view_dist = length((VIEW_MATRIX * vec4(world_pos, 1.0)).xyz);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 to_linear(vec3 c) {
	return mix(pow((c + vec3(0.055)) / vec3(1.055), vec3(2.4)), c / vec3(12.92), lessThan(c, vec3(0.04045)));
}

void fragment() {
	vec2 cell = floor(world_pos.xz * speckle_density);
	float h = hash(cell);
	float fw = max(fwidth(world_pos.x), fwidth(world_pos.z)) * speckle_density;
	float fade = 1.0 - smoothstep(0.5, 1.6, fw);
	float k = (step(0.82, h) - step(h, 0.16)) * speckle_strength * fade;
	ALBEDO = to_linear(COLOR.rgb) * (1.0 + k);
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
}

void light() {
	float lit = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = smoothstep(band_low - 0.01, band_low + 0.01, lit) * mid_light
		+ smoothstep(band_high - 0.01, band_high + 0.01, lit) * (1.0 - mid_light);
	// Distant land stays quiet: light bands close up so hills read as shapes, not patterns.
	band = mix(band, 0.72, smoothstep(45.0, 320.0, view_dist) * 0.7);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
