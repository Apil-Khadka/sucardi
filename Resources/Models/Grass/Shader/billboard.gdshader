shader_type spatial;
render_mode cull_disabled, unshaded, depth_prepass_alpha;

uniform sampler2D grassImage : source_color; // 2D grass image with transparency (alpha)

void vertex() {
    // Calculate direction to the camera in the XZ plane
    vec3 dir = CAMERA_POSITION_WORLD - NODE_POSITION_WORLD;
    dir.y = 0.0;  // Keep the billboard upright (align only in the XZ plane)
    dir = normalize(dir);

    // Construct a rotation matrix to orient the grass plane towards the camera
    vec3 up = vec3(0.0, 1.0, 0.0); // Up direction for vertical alignment
    mat3 billboardMatrix = mat3(cross(up, dir), up, dir);

    // Rotate the vertex to make the plane face the camera
    VERTEX = billboardMatrix * VERTEX;

    // Update normal to match camera-facing direction
    NORMAL = dir;
}

void fragment() {
    // Sample the 2D grass image for color and alpha transparency
    vec4 grassColor = texture(grassImage, UV);

    // Set the fragment's color and transparency
    ALBEDO = grassColor.rgb;
    ALPHA = grassColor.a;
}
