shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float grid_scale : hint_range(1.0, 50.0) = 18.0;
uniform float scanline_speed : hint_range(0.0, 5.0) = 0.8;
uniform float distortion_strength : hint_range(0.0, 0.02) = 0.006;
uniform vec4 line_color : source_color = vec4(0.35, 0.3, 0.5, 0.06);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	float n = noise(uv * 4.0 + TIME);
	uv.x += n * distortion_strength;
	uv.y += noise(uv * 3.0 - TIME * 0.5) * distortion_strength;
	vec2 g = uv * grid_scale;
	vec2 grid = abs(fract(g - 0.5) - 0.5) / fwidth(g);
	float grid_line = 1.0 - min(min(grid.x, grid.y), 1.0);
	float scan = sin((uv.y + TIME * scanline_speed) * 200.0) * 0.5 + 0.5;
	scan = smoothstep(0.4, 0.6, scan);
	float a = (grid_line * 0.5 + scan * 0.3) * line_color.a;
	COLOR = vec4(line_color.rgb, a);
}
