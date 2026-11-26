// (2026-11-26) The eyepiece of a scope seen from behind, in the first-person view (Ari: "rifle,
// scope, still that black mess"). Before, the eye lens was clear glass in front of the closed black
// eyepiece - a big black disc right before the eye at the hip and while the gun came up. Now the
// lens shows the scope's own picture (its camera looks along the scope), cut to the exit pupil:
// with the eye on the axis and at the right distance the whole lens is the picture, from aside or
// from further away the bright circle shrinks and slides off, round it the dark coated glass.
// The disc is the game's own (player._scope_lens_setup puts it just behind the eyepiece's back
// face), so it works on every scope model, also on the sniper's, which has no eye lens at all.
shader_type spatial;
render_mode unshaded, cull_back, blend_mix, depth_draw_opaque, fog_disabled, shadows_disabled;

uniform sampler2D pic : source_color, filter_linear, repeat_disable;
uniform vec3 eye_c;            // the eyepiece's centre (world)
uniform vec3 fwd = vec3(0.0, 0.0, -1.0);   // along the scope, away from the eye
uniform vec3 t1 = vec3(1.0, 0.0, 0.0);     // the gun's right
uniform vec3 t2 = vec3(0.0, 1.0, 0.0);     // the gun's up
uniform float relief = 0.075;  // eye relief (m)
uniform float live = 0.0;      // 1 = the picture is being drawn

void fragment() {
	vec2 lp = vec2(UV.x - 0.5, 0.5 - UV.y) * 2.0;
	float l = length(lp);
	if (l > 1.0) {
		discard;
	}
	vec3 v = normalize((INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz - CAMERA_POSITION_WORLD);
	float dist = max(dot(eye_c - CAMERA_POSITION_WORLD, fwd), 0.001);
	vec2 off = vec2(dot(v, t1), dot(v, t2));
	// the exit pupil: the whole lens at the right eye distance, a smaller circle further back,
	// sliding off when the eye looks from aside (kept generous: never just a black disc)
	float pr = clamp(relief / dist, 0.7, 1.0);
	vec2 c = off * 1.5;
	float m = 1.0 - smoothstep(pr * 0.8, pr + 0.1, length(lp - c));
	vec3 img = texture(pic, UV).rgb * live;
	// coated glass round the picture: dark blue-green, a little sheen at a slant, a darker rim
	float slant = 1.0 - abs(dot(v, fwd));
	vec3 glass = vec3(0.03, 0.05, 0.06) + vec3(0.07, 0.1, 0.12) * slant;
	ALBEDO = mix(glass, img, m * live) * (1.0 - 0.35 * smoothstep(0.85, 1.0, l));
}
