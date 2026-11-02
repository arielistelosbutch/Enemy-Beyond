shader_type canvas_item;
// Enemy Beyond screen filter: reduced palette with ordered (Bayer) dithering,
// film grain, a soft vignette and a whisper of VHS colour bleed.

uniform sampler2D screen : hint_screen_texture, filter_nearest;
uniform float levels = 24.0;        // colour steps per channel
uniform float dither = 1.0;
uniform float grain = 0.06;
uniform float vignette = 0.55;
uniform float bleed = 0.0015;
uniform float time_offset = 0.0;

float bayer4(vec2 p) {
	ivec2 i = ivec2(mod(p, 4.0));
	int m[16] = int[](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return float(m[i.y * 4 + i.x]) / 16.0 - 0.5;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 c;
	c.r = texture(screen, uv + vec2(bleed, 0.0)).r;
	c.g = texture(screen, uv).g;
	c.b = texture(screen, uv - vec2(bleed, 0.0)).b;
	vec2 px = FRAGCOORD.xy;
	// film grain, stronger in the dark
	float lum = dot(c, vec3(0.3, 0.59, 0.11));
	float n = hash(px + fract(TIME * 7.13 + time_offset) * 100.0) - 0.5;
	c += n * grain * (1.2 - lum);
	// vignette
	vec2 d = uv - 0.5;
	c *= 1.0 - dot(d, d) * vignette * 1.6;
	// palette reduction with ordered dithering
	c = floor(c * levels + 0.5 + bayer4(px) * dither) / levels;
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
