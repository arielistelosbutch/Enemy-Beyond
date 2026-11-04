shader_type canvas_item;
// Night vision (PVS-7 style image intensifier): brightness amplified, everything in green phosphor,
// grainy, a round tube view with a dark edge, bright lights bloom and burn out.

uniform sampler2D screen : hint_screen_texture, filter_linear;
uniform float gain = 5.0;
uniform float grain = 0.1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 c = texture(screen, SCREEN_UV).rgb;
	float l = dot(c, vec3(0.3, 0.55, 0.15));
	// a little blur of the neighbours: the tube is soft
	vec2 px = SCREEN_PIXEL_SIZE * 1.5;
	l = l * 0.6 + 0.1 * (dot(texture(screen, SCREEN_UV + vec2(px.x, 0)).rgb, vec3(0.33))
		+ dot(texture(screen, SCREEN_UV - vec2(px.x, 0)).rgb, vec3(0.33))
		+ dot(texture(screen, SCREEN_UV + vec2(0, px.y)).rgb, vec3(0.33))
		+ dot(texture(screen, SCREEN_UV - vec2(0, px.y)).rgb, vec3(0.33)));
	float v = 1.0 - exp(-l * gain);                       // amplified, saturating towards white
	float n = hash(floor(FRAGCOORD.xy / 2.0) + vec2(TIME * 61.0, TIME * 17.0)) - 0.5;
	v = clamp(v + n * grain + 0.035, 0.0, 1.0);
	vec3 g = vec3(0.12, 1.0, 0.22) * v + vec3(0.55, 0.75, 0.55) * pow(v, 6.0);
	// the round tube: the edge of the view is black
	vec2 d = (SCREEN_UV - 0.5) * vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	float r = length(d);
	float tube = 1.0 - smoothstep(0.6, 0.75, r);
	// scan lines, faint
	g *= 0.93 + 0.07 * sin(FRAGCOORD.y * 1.6);
	COLOR = vec4(g * tube, 1.0);
}
