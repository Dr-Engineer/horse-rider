// The racing surface. Hard pixel texture so its scroll gives the strongest sense of speed. The texture spans the
// whole ribbon once across (dark verges on the edges) and repeats along it. No symbols, ever.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D tile : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform float patch_strength = 0.035;
// Pulls the pixel texture toward a dusty mean, so riders stay the strongest thing on the road.
uniform vec3 road_mean : source_color = vec3(0.82, 0.73, 0.56);
uniform float road_contrast = 0.74;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = vec2(clamp(UV.x, 0.003, 0.997), UV.y);
	vec3 c = mix(road_mean, texture(tile, uv).rgb, road_contrast) * tint;
	// Three flat steps of brightness in wide patches break up the repeat without a gradient.
	float n = vnoise(world_pos.xz * 0.18);
	c *= 1.0 + (floor(n * 3.0) - 1.0) * patch_strength;
	ALBEDO = c;
	NORMAL = normalize(cross(dFdy(VERTEX), dFdx(VERTEX)));
	ROUGHNESS = 0.86;
	SPECULAR = 0.0;
}

void light() {
	float lit = dot(NORMAL, LIGHT) * ATTENUATION;
	float band = smoothstep(band_low - 0.01, band_low + 0.01, lit) * mid_light
		+ smoothstep(band_high - 0.01, band_high + 0.01, lit) * (1.0 - mid_light);
	DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
}
