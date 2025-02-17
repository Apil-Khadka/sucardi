shader_type spatial;
render_mode cull_disabled, unshaded, depth_prepass_alpha;

uniform sampler2D grassImage : source_color; // 2D grass image with transparency

void vertex() {
    // No rotation needed; only position the vertex as defined in the mesh
}

void fragment() {
    // Sample the 2D grass image texture
    vec4 grassColor = texture(grassImage, UV);

    // Set the texture color as ALBEDO and the alpha for transparency
    ALBEDO = grassColor.rgb;
    ALPHA = grassColor.a;
}
