// Sky for every course: banded lapis-to-pale gradient, flat stylised clouds, a plain sun disc.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.12, 0.31, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.88, 0.91);
uniform vec3 mid_color : source_color = vec3(0.3, 0.55, 0.85);
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.8);
uniform vec3 cloud_light : source_color = vec3(1.0, 0.99, 0.95);
uniform vec3 cloud_shade : source_color = vec3(0.76, 0.83, 0.94);
uniform float cloud_cover = 0.5;
uniform float cloud_speed = 0.004;
uniform float cloud_scale = 1.1;
uniform float sun_size = 0.03;
uniform float bands = 10.0;

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
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 dir = EYEDIR;
	float h = clamp(dir.y, 0.0, 1.0);
	float t = pow(h, 0.6);
	t = floor(t * bands) / bands;
	vec3 col = t < 0.5 ? mix(horizon_color, mid_color, t * 2.0) : mix(mid_color, top_color, (t - 0.5) * 2.0);
	if (dir.y < 0.0) {
		col = horizon_color;
	}
	if (!AT_CUBEMAP_PASS) {
		// Clouds on a plane overhead, hard-edged with a flat shaded underside.
		vec2 uv = dir.xz / (dir.y + 0.16) * 1.25 + vec2(TIME * cloud_speed, 0.0);
		float th = 0.75 - cloud_cover * 0.22;
		float n = fbm(uv * cloud_scale);
		float n2 = fbm(uv * cloud_scale + vec2(0.0, 0.07));
		float mask = smoothstep(0.03, 0.2, dir.y);
		float body = step(th, n) * mask;
		float under = step(th, n) * (1.0 - step(th, n2)) * mask;
		col = mix(col, cloud_light, body);
		col = mix(col, cloud_shade, under);
		// Sun disc with a flat halo ring.
		if (LIGHT0_ENABLED) {
			float sd = dot(dir, LIGHT0_DIRECTION);
			float disc = step(cos(sun_size), sd);
			float halo = step(cos(sun_size * 2.6), sd);
			col = mix(col, mix(col, sun_color, 0.35), halo);
			col = mix(col, sun_color, disc);
		}
	}
	COLOR = col;
}
