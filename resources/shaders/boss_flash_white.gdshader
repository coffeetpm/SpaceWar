shader_type canvas_item;

// Boss 受擊白光：喺 flash_modifier=1 時覆寫輸出為純白 HDR，flash_modifier=0 時保留原色。
// 用法：ShaderMaterial 套落 Polygon2D / Line2D / Sprite2D，take_damage 時 Tween flash_modifier。

uniform float flash_modifier : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float flash_boost : hint_range(1.0, 6.0) = 2.4;

void fragment() {
    // COLOR 已包含 polygon/line vertex color * texture * modulate（Godot 預設）。
    vec4 base_tint = COLOR * texture(TEXTURE, UV);
    vec4 white_flash = vec4(flash_color.rgb * flash_boost, base_tint.a);
    COLOR = mix(base_tint, white_flash, flash_modifier);
}
