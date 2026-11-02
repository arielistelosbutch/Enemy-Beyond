shader_type spatial;
// Grass blades (MultiMesh): sway in the wind, darker at the root, fade out far away.
render_mode cull_disabled, diffuse_lambert, specular_disabled;

uniform vec4 root_color : source_color = vec4(0.10, 0.16, 0.07, 1.0);
uniform vec4 tip_color : source_color = vec4(0.32, 0.42, 0.18, 1.0);
uniform float sway = 0.25;
uniform float fade_start = 22.0;
uniform float fade_end = 34.0;
global uniform float wind_strength;

varying float v_h;
varying float v_tint;

void vertex() {
	v_h = clamp(VERTEX.y / 0.5, 0.0, 1.0);
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_tint = INSTANCE_CUSTOM.r;
	float ws = max(wind_strength, 0.3);
	float ph = TIME * 1.7 + wp.x * 0.45 + wp.z * 0.3;
	float wave = sin(ph) + 0.5 * sin(ph * 2.3 + wp.z) ;
	// big slow gusts rolling across the field
	float gust = 0.5 + 0.5 * sin(TIME * 0.6 - wp.x * 0.08 - wp.z * 0.05);
	float bend = (wave * 0.5 + gust * 1.2) * sway * ws * v_h * v_h;
	// bend in world space
	vec3 off = vec3(bend, -abs(bend) * 0.3, bend * 0.4);
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	float d = length(VERTEX);
	if (d > fade_end) discard;
	// dithered fade so there is no hard edge
	float f = clamp((d - fade_start) / (fade_end - fade_start), 0.0, 1.0);
	ivec2 q = ivec2(FRAGCOORD.xy) % 4;
	float th = float((q.x * 4 + q.y * 7) % 16) / 16.0;
	if (f > th) discard;
	vec3 c = mix(root_color.rgb, tip_color.rgb, v_h) * (0.8 + v_tint * 0.4);
	ALBEDO = c;
	ROUGHNESS = 1.0;
	BACKLIGHT = vec3(0.15) * v_h;
}
