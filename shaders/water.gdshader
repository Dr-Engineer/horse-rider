// Flat turquoise water with slow pixel bands. Lit by nothing: colour comes from emission so it stays clean.
shader_type spatial;
render_mode cull_disabled, specular_disabled, depth_draw_opaque;

uniform vec3 col_a : source_color = vec3(0.18, 0.72, 0.69);
uniform vec3 col_b : source_color = vec3(0.5, 0.85, 0.81);
uniform vec3 col_c : source_color = vec3(0.09, 0.47, 0.61);
uniform float speed = 0.05;
uniform float cell = 1.0;
uniform vec2 flow = vec2(0.0, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 g = floor(UV / cell);
	float t = TIME * speed;
	// Two drifting wave sets, quantised to a coarse grid so the bands look hand-painted.
	float w1 = sin(g.x * 0.9 + g.y * 0.35 - dot(flow, vec2(1.0)) * t * 6.0 + sin(g.y * 0.21) * 2.0);
	float w2 = sin(g.y * 0.55 - g.x * 0.3 + t * 4.0);
	float v = w1 * 0.6 + w2 * 0.4 + (hash(g) - 0.5) * 0.25;
	vec3 c = col_a;
	c = mix(c, col_b, step(0.55, v));
	c = mix(c, col_c, step(v, -0.6));
	ALBEDO = vec3(0.0);
	EMISSION = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.0;
}
