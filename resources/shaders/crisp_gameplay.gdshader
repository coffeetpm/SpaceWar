shader_type canvas_item;
render_mode blend_mix, unshaded;

uniform float crisp_scale : hint_range(0.5, 1.0) = 0.84;

void fragment() {
	COLOR = texture(TEXTURE, UV) * COLOR;
	COLOR.rgb *= crisp_scale;
}
