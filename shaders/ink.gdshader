// Full-screen ink lines from depth, normals and the material class. docs/STYLE_GUIDE.md section "Ink".
shader_type spatial;
render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest, repeat_disable;
uniform sampler2D nr_tex : hint_normal_roughness_texture, filter_nearest, repeat_disable;
uniform vec3 ink : source_color = vec3(0.07, 0.05, 0.07);
uniform float width_px = 1.25;
uniform float fade_start = 70.0;
uniform float fade_end = 260.0;

void vertex() {
	POSITION = vec4(VERTEX.xy, 1.0, 1.0);
}

float decode_class(vec4 s) {
	float r = s.w;
	if (r > 0.5) {
		r = 1.0 - r;
	}
	return r / (127.0 / 255.0);
}

void fragment() {
	vec2 px = width_px * max(VIEWPORT_SIZE.y / 1080.0, 1.0) / VIEWPORT_SIZE;
	vec2 uv = SCREEN_UV;
	float d0 = texture(depth_tex, uv).r;
	float dl = texture(depth_tex, uv - vec2(px.x, 0.0)).r;
	float dr = texture(depth_tex, uv + vec2(px.x, 0.0)).r;
	float du = texture(depth_tex, uv - vec2(0.0, px.y)).r;
	float dd = texture(depth_tex, uv + vec2(0.0, px.y)).r;
	float dmax = max(max(d0, dl), max(dr, max(du, dd)));

	vec4 n0 = texture(nr_tex, uv);
	vec4 nl = texture(nr_tex, uv - vec2(px.x, 0.0));
	vec4 nr = texture(nr_tex, uv + vec2(px.x, 0.0));
	vec4 nu = texture(nr_tex, uv - vec2(0.0, px.y));
	vec4 nd = texture(nr_tex, uv + vec2(0.0, px.y));
	float c0 = decode_class(n0);
	float cl = decode_class(nl), cr = decode_class(nr), cu = decode_class(nu), cd = decode_class(nd);
	float cmin = min(c0, min(cl, min(cr, min(cu, cd))));

	// Depth is linear across screen space on any plane, so a second difference only fires at
	// occlusions and creases. Terrain needs a far larger step before it draws a line.
	float crease = max(abs(dl + dr - 2.0 * d0), abs(du + dd - 2.0 * d0)) / max(dmax, 1e-6);
	float depth_edge = cmin > 0.7 ? smoothstep(0.12, 0.2, crease) : smoothstep(0.03, 0.07, crease);

	float class_edge = step(0.12, max(max(abs(c0 - cl), abs(c0 - cr)), max(abs(c0 - cu), abs(c0 - cd))));

	vec3 v0 = n0.xyz * 2.0 - 1.0;
	float nmin = min(min(dot(v0, nl.xyz * 2.0 - 1.0), dot(v0, nr.xyz * 2.0 - 1.0)), min(dot(v0, nu.xyz * 2.0 - 1.0), dot(v0, nd.xyz * 2.0 - 1.0)));
	float normal_edge = c0 < 0.35 ? smoothstep(0.45, 0.25, nmin) * 0.85 : 0.0;

	vec4 view = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, dmax, 1.0);
	float z = -view.z / view.w;
	float fade = 1.0 - smoothstep(fade_start, fade_end, z);
	float sky = step(dmax, 1e-6);
	ALBEDO = ink;
	ALPHA = max(max(depth_edge, class_edge), normal_edge) * fade * (1.0 - sky);
}
