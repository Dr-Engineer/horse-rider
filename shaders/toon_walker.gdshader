// toon.gdshader with a walk cycle in the vertex stage, for the animals (yak, mule, sheep, dog, kiang). The models are
// static, so the legs are told apart by where they are: everything below the hip joint height swings about it, front
// and back by the sign of z (model -Z is forward), left and right by the sign of x. A diagonal or four-beat gait, a
// foot lift, a body bob and a head nod. ArtKit.prop_walker() sets the per-animal numbers, ArtKit.set_stride() the phase.
//
//   stride_phase  radians, grows with the distance walked        stride_amp  0 (standing) to 1 (full stride)
//   walk_cfg      (hip height m, gait 0 walk to 1 trot, leg swing radians, body bob m)
//   head_cfg      (neck z, neck y, nod radians, personal phase)
shader_type spatial;
render_mode cull_back, specular_disabled;

uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform float class_id : hint_range(0.0, 1.0) = 0.5;
uniform float band_low = 0.04;
uniform float band_high = 0.58;
uniform float mid_light = 0.62;
uniform vec3 tint : source_color = vec3(1.0);

instance uniform vec3 slot_a : source_color = vec3(0.84, 0.23, 0.13);
instance uniform vec3 slot_b : source_color = vec3(0.95, 0.71, 0.2);
instance uniform vec3 slot_c : source_color = vec3(0.55, 0.35, 0.2);
instance uniform vec3 slot_d : source_color = vec3(0.09, 0.07, 0.08);
instance uniform float flash = 0.0;
instance uniform float stride_phase = 0.0;
instance uniform float stride_amp = 0.0;
instance uniform vec4 walk_cfg = vec4(0.55, 0.0, 0.45, 0.03);
instance uniform vec4 head_cfg = vec4(-0.9, 0.9, 0.1, 0.0);

void vertex() {
	vec3 v = VERTEX;
	float hip = walk_cfg.x;
	float amp = stride_amp;
	float bob = sin(stride_phase * 2.0 + 0.6) * amp * walk_cfg.w;
	if (v.y < hip) {
		float r = hip - v.y;
		float side = v.x >= 0.0 ? 1.0 : 0.0;
		float front = v.z < 0.0 ? 1.0 : 0.0;
		float walk_off = front > 0.5 ? (side > 0.5 ? 0.75 : 0.25) : (side > 0.5 ? 0.5 : 0.0);
		float trot_off = ((front > 0.5) == (side > 0.5)) ? 0.0 : 0.5;
		float a = stride_phase + mix(walk_off, trot_off, walk_cfg.y) * TAU;
		float th = sin(a) * amp * walk_cfg.z;
		float lift = max(0.0, cos(a)) * amp * walk_cfg.z * 0.18;
		v.z -= sin(th) * r;
		v.y = hip - r * cos(th) + lift * (r / max(hip, 0.05));
	}
	// The body rides up and down with the steps, the feet stay planted.
	v.y += bob * smoothstep(0.0, max(hip, 0.1), VERTEX.y);
	// Head nod: everything forward of the neck pivots about it. A slow idle nod, a quicker one in step.
	float hw = smoothstep(0.0, 0.45, head_cfg.x - VERTEX.z) * smoothstep(head_cfg.y - 0.25, head_cfg.y, VERTEX.y);
	if (hw > 0.0) {
		float nod = head_cfg.z * (0.5 * sin(TIME * 1.4 + head_cfg.w * 6.2831) * (1.0 - amp) + amp * sin(stride_phase * 2.0 + 1.4));
		float dz = v.z - head_cfg.x;
		float dy = v.y - head_cfg.y;
		float c = cos(nod * hw);
		float s = sin(nod * hw);
		v.z = head_cfg.x + dz * c - dy * s;
		v.y = head_cfg.y + dz * s + dy * c;
	}
	VERTEX = v;
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
