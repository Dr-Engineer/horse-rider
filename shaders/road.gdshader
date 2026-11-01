// The racing surface. Hard pixel texture so its scroll gives the strongest sense of speed. The texture spans the
// whole ribbon once across (dark verges on the edges) and repeats along it. No symbols, ever.
//
// A tile is about 30 to 40 m long, so on its own the repeat would show. Macro variation hides it: broad flat steps of
// brightness at two scales, a slow drift between a warmer and a cooler dust, damper patches along the lanes, and
// sparse world-placed pebbles that never repeat. All of it is in road space (metres across and along), so it follows
// the bends, and all of it is quiet enough that riders stay the strongest thing on the road.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D tile : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec3 tint : source_color = vec3(1.0);
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform float patch_strength = 0.045;
// Pulls the pixel texture toward a dusty mean, so riders stay the strongest thing on the road.
uniform vec3 road_mean : source_color = vec3(0.82, 0.73, 0.56);
uniform float road_contrast = 0.8;
// Metres one tile spans across the road and along it (set by TrackBuilder).
uniform float tile_len = 37.0;

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
	vec3 tex = texture(tile, uv).rgb;
	vec3 c = mix(road_mean, tex, road_contrast) * tint;
	float lum = dot(tex, vec3(0.3333));
	float road_part = smoothstep(0.38, 0.52, lum);       // the light dust, not the dark verge

	vec2 rp = vec2(UV.x, UV.y) * tile_len;               // metres across and along the road
	// Flat steps of brightness at two scales.
	float n1 = 0.6 * vnoise(rp * 0.045 + 3.1) + 0.4 * vnoise(rp * 0.09 + 11.7);
	float n2 = vnoise(rp * 0.17 + 5.3);
	c *= 1.0 + (floor(n1 * 3.0) - 1.0) * patch_strength * road_part + (floor(n2 * 3.0) - 1.0) * patch_strength * 0.55 * road_part;
	// A slow drift between warmer and cooler dust.
	float wv = vnoise(rp * 0.028 + 7.0);
	c *= mix(vec3(0.975, 0.99, 1.03), vec3(1.035, 1.0, 0.95), step(0.5, wv));
	// Damper, darker patches along the hoof lanes.
	float lane = max(exp(-pow((UV.x - 0.31) / 0.055, 2.0)), exp(-pow((UV.x - 0.69) / 0.055, 2.0)));
	c *= 1.0 - 0.075 * lane * step(0.6, vnoise(vec2(UV.x * 3.0, rp.y * 0.09 + 2.0))) * road_part;
	// Pebbles placed in the world, sparse, fading out where they would be smaller than a screen pixel.
	float cell_m = 0.17;
	vec2 cell = floor(rp / cell_m);
	float h = hash(cell + 41.0);
	float fw = max(fwidth(rp.x), fwidth(rp.y)) / cell_m;
	float vis = (1.0 - smoothstep(0.7, 1.6, fw)) * road_part;
	if (h > 0.972) {
		c *= 1.0 + 0.15 * vis;
	} else if (h < 0.022) {
		c *= 1.0 - 0.14 * vis;
	}
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
