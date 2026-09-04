// grid_floor.gdshader
// 基于世界坐标 XZ 平面的抗锯齿网格地面 Shader
shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_lambert, specular_schlick_ggx;

uniform vec2 cell_size = vec2(0.5, 0.5);
uniform vec4 line_color : source_color = vec4(0.3, 0.6, 0.9, 1.0);
uniform vec4 base_color : source_color = vec4(0.12, 0.12, 0.14, 1.0);
uniform float line_thickness : hint_range(0.001, 0.1) = 0.02;

varying vec3 world_position;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// 计算世界空间中网格单元的相对坐标 (0.0 到 1.0)
	vec2 coord = world_position.xz / cell_size;
	vec2 grid = abs(fract(coord - 0.5) - 0.5) / fwidth(coord);
	float line = min(grid.x, grid.y);
	
	// 使用导数消除远距离摩尔纹锯齿
	float c = 1.0 - min(line * line_thickness, 1.0);
	
	ALBEDO = mix(base_color.rgb, line_color.rgb, c);
	ROUGHNESS = 0.8;
}