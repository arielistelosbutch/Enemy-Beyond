shader_type spatial;
// (2026-11-17) A puddle after the rain (scripts/weather_fx.gd): a dark, mirror-smooth blob whose edge
// comes from noise in world space (no two alike), shrinking as it dries; in the rain rings spread on it.
render_mode blend_mix, depth_draw_never, cull_back;

uniform float wet = 1.0;     // 0 dry .. 1 full
uniform float rain = 0.0;    // 0 none .. 1 storm
uniform vec4 tint : source_color = vec4(0.03, 0.035, 0.04, 0.88);
uniform vec3 sky_col : source_color = vec3(0.05, 0.06, 0.09);   // what the water mirrors at a low angle (WeatherFx)

varying vec3 w_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void vertex() {
	w_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float sh = vnoise(w_pos.xz * 1.6) * 0.55 + vnoise(w_pos.xz * 4.3 + 7.0) * 0.25;
	float edge = 1.0 - r + (sh - 0.4) * 0.9;
	float thr = mix(0.62, 0.06, clamp(wet, 0.0, 1.0));
	float a = smoothstep(thr, thr + 0.07, edge);
	if (a < 0.01) {
		discard;
	}
	vec2 nm = vec2(0.0);
	if (rain > 0.0) {
		// rings: a drop per cell, each at its own moment
		for (int k = 0; k < 2; k++) {
			vec2 g = w_pos.xz * (2.6 + float(k) * 1.3) + float(k) * 3.1;
			vec2 cell = floor(g);
			vec2 f = fract(g) - 0.5;
			vec2 off = vec2(hash(cell), hash(cell + 9.1)) - 0.5;
			vec2 d = f - off * 0.5;
			float ph = fract(TIME * (1.1 + 0.5 * rain) + hash(cell + 3.7));
			float dl = length(d);
			float ring = sin((dl - ph * 0.45) * 70.0) * exp(-abs(dl - ph * 0.45) * 40.0) * (1.0 - ph) * rain;
			nm += normalize(d + 0.0001) * ring * 0.6;
		}
	}
	NORMAL_MAP = vec3(nm * 0.5 + 0.5, 1.0);
	NORMAL_MAP_DEPTH = 1.0;
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.05;
	// the sky in the water, stronger the flatter you look across it
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	EMISSION = sky_col * (0.25 + 1.6 * fres);
	ALPHA = a * tint.a;
}

// A lamp in the water: a broad glow towards it and a sharp glint where it mirrors (no screen-space
// reflections needed - every light the puddle is lit by shows in it).
void light() {
	vec3 r = reflect(-LIGHT, NORMAL);
	float rv = max(dot(r, VIEW), 0.0);
	float k = ATTENUATION;
	// the long streak a lamp draws across wet ground towards you (the ripples stretch its mirror image)
	vec3 lh = normalize(LIGHT - NORMAL * dot(LIGHT, NORMAL) + vec3(0.0001));
	vec3 vh = normalize(VIEW - NORMAL * dot(VIEW, NORMAL) + vec3(0.0001));
	float streak = pow(max(dot(lh, -vh), 0.0), 40.0) * (1.0 - dot(VIEW, NORMAL) * 0.6);
	SPECULAR_LIGHT += LIGHT_COLOR * k * (pow(rv, 14.0) * 0.9 + pow(rv, 160.0) * 5.0 + streak * 1.4);
	DIFFUSE_LIGHT += LIGHT_COLOR * k * max(dot(NORMAL, LIGHT), 0.0) * 0.15;
}
