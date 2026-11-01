// Churned mud across the road. A lumpy blob painted in pixels at the road's scale, so its edge steps like the road
// texture and is never a straight line: pale dry cracked crust at the rim, dried clods, mid-brown churn, a darker wet
// heart with sky-tinted puddles, and hoof pocks. Every value stays well above black. Palette values only (sand, tan,
// ochre, wood_light, sienna, umber, azure, sky_pale). Terrain ink class, so no outline is drawn around it.
//
// The mesh (hazards.gd) follows the road. UV is metres from the patch centre (x across, y along the road). UV2 is
// (lateral position of the pixel on the road in metres, road half width), so the blob stops at the verge.
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform float px = 0.19;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform vec3 crust_a : source_color = vec3(0.847, 0.745, 0.557);
uniform vec3 crust_b : source_color = vec3(0.725, 0.553, 0.353);
uniform vec3 dry_a : source_color = vec3(0.788, 0.584, 0.247);
uniform vec3 mud_a : source_color = vec3(0.659, 0.455, 0.247);
uniform vec3 mud_b : source_color = vec3(0.549, 0.353, 0.200);
uniform vec3 mud_c : source_color = vec3(0.353, 0.239, 0.169);
uniform vec3 sky_lo : source_color = vec3(0.290, 0.561, 0.851);
uniform vec3 sky_hi : source_color = vec3(0.749, 0.878, 0.910);
uniform float sky_mix = 0.0;
instance uniform float seed = 0.0;
instance uniform vec2 half_size = vec2(6.0, 10.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.3, 9.1);
		a *= 0.5;
	}
	return s / 0.875;
}

void fragment() {
	vec2 p = UV;
	vec2 cell = floor(p / px);
	vec2 q = (cell + 0.5) * px;
	float sd = seed;
	// Fine pixel detail fades once a painted pixel is smaller than a screen pixel, so far patches stay calm.
	float fwp = max(fwidth(p.x), fwidth(p.y));
	float det = 1.0 - smoothstep(px * 0.8, px * 3.0, fwp);

	// Lumpy outline: a rounded rectangle pushed in and out by two scales of noise, plus pixel raggedness.
	vec2 n = q / half_size;
	float e = pow(pow(abs(n.x), 2.6) + pow(abs(n.y), 2.6), 1.0 / 2.6);
	e += (fbm(q * 0.15 + sd * 3.7) - 0.5) * 0.62;
	e += (vnoise(q * 0.62 + sd * 1.9) - 0.5) * 0.16;
	e += (hash(cell + sd * 5.0) - 0.5) * 0.07;
	// The blob stops at the verge, with a wobbling stair-stepped edge there too.
	float d_q = UV2.x + (q.x - p.x);
	float limit = UV2.y - 0.45 + (vnoise(q * 0.5 + sd) - 0.5) * 1.1 + (hash(cell * 1.7 + sd) - 0.5) * 0.3;
	if (e > 1.0 || abs(d_q) > limit) {
		discard;
	}

	float t = 1.0 - e;
	float tt = t + (fbm(q * 0.7 + 9.1 + sd) - 0.5) * 0.24;
	float grain = hash(cell + 3.3 + sd);
	vec3 col;
	if (tt < 0.1) {
		// Dry crust blending into the road: pale, cracked.
		col = crust_a;
		float crack = abs(vnoise(q * 1.8 + sd * 2.0) - 0.5);
		if (crack < 0.05 * det + 0.012) {
			col = crust_b;
		}
		if (grain > 0.9) {
			col = mix(col, vec3(0.93, 0.88, 0.78), det);
		}
	} else if (tt < 0.27) {
		// Dried clods: tan and ochre, split by cracks.
		float cl = vnoise(q * 1.1 + sd * 4.0);
		col = cl > 0.55 ? crust_b : (cl > 0.38 ? dry_a : mix(crust_b, mud_a, 0.6));
		float crack2 = abs(vnoise(q * 2.3 + 4.0 + sd) - 0.5);
		if (crack2 < 0.04 * det) {
			col = mud_a;
		}
	} else if (tt < 0.58) {
		// Churned mud: three flat steps with light ridges where hooves threw it up.
		float ch = fbm(q * 0.85 + sd * 2.0);
		col = ch < 0.36 ? mix(mud_b, mud_c, 0.45) : (ch < 0.6 ? mud_b : mud_a);
		float ridge = abs(vnoise(q * vec2(1.4, 0.8) + 7.0 + sd) - 0.5);
		if (ridge < 0.045 * det) {
			col = mix(mud_a, dry_a, 0.45);
		}
	} else {
		// Wet heart: darker, glossy, with puddles that carry the sky.
		col = mix(mud_b, mud_c, 0.5);
		if (grain > 0.82) {
			col = mix(col, mud_b, det);
		}
		float pf = fbm(q * 0.34 + sd * 2.6 + 31.0);
		if (pf > 0.6 && tt > 0.62) {
			float depth = clamp((pf - 0.6) / 0.22, 0.0, 1.0);
			vec3 sky = mix(sky_lo, sky_hi, sky_mix);
			col = depth < 0.18 ? mud_c : mix(sky, sky_hi, step(0.55, depth) * 0.55 + step(0.85, depth) * 0.3);
			// a glint along the far edge of the water
			if (depth > 0.18 && fbm((q + vec2(0.0, px)) * 0.34 + sd * 2.6 + 31.0) <= 0.6 + 0.0) {
				col = sky_hi;
			}
		}
	}
	// Hoof pocks: small pits with a lit lip, one per few pixels' worth of cells, never in the crust.
	if (tt > 0.08) {
		vec2 big = floor(cell / 5.0);
		vec2 local = cell - big * 5.0;
		float hh = hash(big + sd * 7.0);
		if (hh > 0.45) {
			vec2 pk = floor(vec2(hash(big + 2.0), hash(big + 5.0)) * 3.0) + 1.0;
			vec2 dlt = local - pk;
			bool pit = dlt.x >= 0.0 && dlt.x <= 1.0 && dlt.y >= 0.0 && dlt.y <= 1.0 && !(dlt.x == 1.0 && dlt.y == 1.0);
			bool lip = dlt.x == -1.0 && dlt.y >= 0.0 && dlt.y <= 1.0;
			if (pit) {
				col = mix(col, mix(mud_b, mud_c, 0.8), det);
			} else if (lip) {
				col = mix(col, mix(mud_a, dry_a, 0.5), det * 0.8);
			}
		}
	}
	ALBEDO = col;
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
