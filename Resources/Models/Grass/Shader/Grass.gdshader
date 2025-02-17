shader_type spatial;
render_mode cull_disabled, unshaded, depth_prepass_alpha;

uniform sampler2D grassTexture:source_color; // Grass texture with transparency (alpha)
uniform sampler2D noise;
uniform float noiseScale = 2.0;
uniform float windStrength = 0.1;
uniform float windSpeed = 1.0;
uniform vec3 windDirection = vec3(1.0, 0.0, 0.0); // Wind along X-axis by default

varying vec3 worldPos;

void vertex() {
    float factor = clamp((0.5 - UV.y) * 2.0, 0.0, 1.0);
    float windFactor = sin(TIME * windSpeed + (VERTEX.x + VERTEX.z) * 0.1) * windStrength * factor;
    vec3 windDisplacement = windDirection * windFactor;
    VERTEX += windDisplacement;
    worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
    vec4 grassColor = texture(grassTexture, UV);
	//grassColor = pow(grassColor,vec4(2.2));
    ALBEDO = grassColor.rgb;
    ALPHA = grassColor.a;

    // Use noise for subtle color variation
    vec3 noiseLevel = texture(noise, worldPos.xz / noiseScale).rgb;
    ALBEDO *= mix(vec3(1.0), noiseLevel, 0.2);

    if (!FRONT_FACING) {
        NORMAL = -NORMAL;
    }
    // Set alpha scissor threshold for depth sorting
    if (ALPHA < 0.1) discard;
}
