shader_type spatial;

uniform sampler2D mterrain_heightmap: filter_nearest;
uniform sampler2D mterrain_normals: filter_nearest;
uniform sampler2D mterrain_road: filter_nearest; // Road mask

uniform sampler2D texture1; // Flat ground (grass, dirt)
uniform sampler2D texture2; // Steep slopes (rock)
uniform sampler2D texture3; // Blended ground (mud, sand)
uniform sampler2D road_texture; // Road texture

uniform vec3 region_world_position;
uniform float region_size;
uniform float region_a;
uniform float region_b;
uniform int min_lod;
varying vec3 world_pos;
varying vec2 region_uv;

varying float slope_mask;
varying float road_mask;
varying float blend_factor;

void vertex() {
    world_pos = (NODE_POSITION_WORLD + VERTEX);
    region_uv = (world_pos.xz - region_world_position.xz) / region_size;
    region_uv = region_uv * region_a + region_b;

    // Sample height from heightmap
    VERTEX.y = texture(mterrain_heightmap, region_uv).r;
    world_pos.y = VERTEX.y;

    // Sample normal and adjust
    vec3 n = texture(mterrain_normals, region_uv).rgb;
    n.rb = fma(n.rb, vec2(2.0), vec2(-1.0));
	float nxz = abs(n.x) + abs(n.z);

	    // Compute slope (steeper areas will have a higher value)
    slope_mask = smoothstep(0.2, 0.3, nxz);

    // Sample road mask (grayscale, assumed to be in the red channel)
    road_mask = texture(mterrain_road, region_uv).r;
    // Height-based blending factor
    blend_factor = smoothstep(0.9, 0.6, 0.87-nxz); // Adjust for transition

    world_pos /= 2.0;
    NORMAL = n;
}

void fragment() {


    // Sample textures using world position for tiling
    vec2 uv1 = world_pos.xz * 0.1;
    vec2 uv2 = world_pos.xz * 0.2;

    vec3 tex1 = texture(texture1, uv1).rgb; // Flat ground
    vec3 tex2 = texture(texture2, uv2).rgb; // Steep slopes
    vec3 tex3 = texture(texture3, uv1).rgb; // Blended terrain
    vec3 road_tex = texture(road_texture, world_pos.xz * 0.06).rgb; // Road


    // Mix ground textures based on height
    vec3 ground_mix = mix(tex1, tex3, blend_factor);

    // Final mix: steep areas get texture2, ground areas mix texture1 & texture3
    vec3 terrain_texture = mix(ground_mix, tex2, slope_mask);

    // Blend road texture using the road mask
    vec3 final_texture = mix(terrain_texture, road_tex, road_mask);

    ALBEDO = final_texture;
}
