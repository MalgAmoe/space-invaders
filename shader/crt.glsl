#version 330

in vec2 fragTexCoord;
out vec4 finalColor;

uniform sampler2D texture0;
uniform vec4 colDiffuse;
uniform float iTime;

uniform vec2 screenResolution;
uniform float curvature;

vec2 curveRemapUV(vec2 uv)
{
    // Convert to centered coordinates
    uv = uv * 2.0 - 1.0;
    
    // Calculate the distance from the center
    vec2 offset = abs(uv.yx) / vec2(curvature, curvature);
    uv = uv + uv * offset * offset;
    
    // Convert back to texture coordinates
    uv = uv * 0.5 + 0.5;

    return uv;
}

void main()
{
    vec2 uv = fragTexCoord;
    
    // CRT curvature
    
    uv = curveRemapUV(uv);
    
    // Check if the pixel is outside the screen
    if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
        finalColor = vec4(0.0, 0.0, 0.0, 1.0);
        return;
    }
    
    // Sample the texture
    vec4 color = texture(texture0, uv);
    
    // Scanline effect
    float scanline = sin((uv.y * 800.0) + iTime + 10.0) * 0.1;
    color -= scanline;
    
    // Vignette effect
    float vignette = 1.0 - length((uv - 0.5) * 1.2);
    color.rgb *= smoothstep(0.0, 0.7, vignette);
    
    finalColor = color;
}
