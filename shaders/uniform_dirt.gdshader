shader_type spatial;
// 0.70 Facelift II: dirt and blood over the soldier's clothes (material_overlay on every skinned piece).
// COLOR carries the vertex's place in the rest pose (x, y, z; baked once by uniform_dirt.gd), so the
// stains stay on the cloth when the body moves.
render_mode blend_mix, depth_draw_never, cull_back, diffuse_burley;

uniform float dirt = 0.0;                    // all over (lying, falling, crawling)
uniform float low = 0.0;                     // boots, shins and knees
uniform vec3 mud : source_color = vec3(0.29, 0.22, 0.14);
uniform vec4 blood[8];                       // rest place (x, y, z) + radius (0 = no stain)
uniform float blood_age[8];                  // 0 fresh red .. 1 dried brown
uniform float seed = 0.0;

varying vec3 rp;

void vertex() {
	rp = vec3((COLOR.r - 0.5) * 2.0, COLOR.g * 2.0, (COLOR.b - 0.5) * 2.0);
}

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.17, 0.13) + seed);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i + vec3(0, 0, 0)), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
	return noise(p) * 0.55 + noise(p * 2.03 + 3.1) * 0.3 + noise(p * 4.1 + 7.7) * 0.15;
}

void fragment() {
	float n = fbm(rp * 9.0);
	float fine = noise(rp * 38.0);
	// lower legs collect it first; lying down spreads it everywhere
	float lowness = 1.0 - smoothstep(0.08, 0.75, rp.y);
	float amount = clamp(low * lowness * 1.1 + dirt * (0.5 + 0.4 * lowness), 0.0, 1.0) * 0.85;
	float m = smoothstep(1.0 - amount, 1.0 - amount + 0.3, n * 0.8 + fine * 0.2) * min(1.0, amount * 3.0);
	vec3 col = mud * (0.75 + 0.5 * fine);
	float a = m * (0.7 + 0.25 * fine);
	float rough = 0.95;
	for (int i = 0; i < 8; i++) {
		float r = blood[i].w;
		if (r <= 0.0) { continue; }
		float d = distance(rp, blood[i].xyz) + (noise(rp * 26.0 + float(i) * 5.3) - 0.5) * r * 0.9;
		// a soaked patch with a few drops round it
		float s = 1.0 - smoothstep(r * 0.45, r, d);
		float drops = step(0.82, noise(rp * 70.0 + float(i))) * (1.0 - smoothstep(r, r * 1.8, d));
		float bm = max(s, drops) * 0.92;
		if (bm > 0.0) {
			vec3 bc = mix(vec3(0.36, 0.015, 0.02), vec3(0.17, 0.045, 0.03), blood_age[i]);
			col = mix(col, bc * (0.8 + 0.4 * fine), bm / max(0.001, max(a, bm)));
			rough = mix(rough, mix(0.35, 0.85, blood_age[i]), bm);
			a = max(a, bm);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	ALPHA = a;
}
