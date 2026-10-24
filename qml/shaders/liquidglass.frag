// Liquid glass for the floating navigation bar and its active-item indicator (compiled to
// liquidglass.frag.qsb, see qml/shaders/build.sh). `source` is what lies behind the bar,
// already blurred as wanted (strongly for "frosted", lightly for "clear"), captured with
// spare pixels on every side so a rim can bend light in from just outside it. Each glass
// piece says where it sits in that capture (`origin`), so the bar and the indicator share it.
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 barSize;       // size of this glass piece in pixels
    float barRadius;    // its corner radius in pixels
    vec2 origin;        // its top-left corner in the captured background, in pixels
    vec2 sourceSize;    // size of the captured background in pixels
    float edge;         // width of the refracting rim in pixels
    float refraction;   // 0..1: how strongly the rim bends what is behind
    float dispersion;   // pixels of colour fringing at the rim
    float highlight;    // brightness of the light catching the rim
    vec4 tint;          // rgb + amount mixed over the glass
};
layout(binding = 1) uniform sampler2D source;

float roundedBox(vec2 p, vec2 halfSize, float r) {
    vec2 q = abs(p) - halfSize + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

void main() {
    vec2 halfSize = barSize * 0.5;
    vec2 p = qt_TexCoord0 * barSize - halfSize;
    float d = roundedBox(p, halfSize, barRadius);            // < 0 inside the bar
    float shape = clamp(0.5 - d, 0.0, 1.0);               // anti-aliased outline

    // outward normal of the outline
    vec2 e = vec2(0.75, 0.0);
    vec2 n = vec2(roundedBox(p + e.xy, halfSize, barRadius) - roundedBox(p - e.xy, halfSize, barRadius),
                  roundedBox(p + e.yx, halfSize, barRadius) - roundedBox(p - e.yx, halfSize, barRadius));
    n = n / max(length(n), 1e-4);

    // 0 at the rim, 1 once `edge` pixels inside: the glass is thickest (bends most) at the rim
    float inner = clamp(-d / max(edge, 1.0), 0.0, 1.0);
    float rimBend = (1.0 - inner) * (1.0 - inner);
    vec2 at = (origin + qt_TexCoord0 * barSize - n * rimBend * refraction * edge) / sourceSize;
    vec2 fringe = n * dispersion * rimBend / sourceSize;

    vec3 colour = vec3(texture(source, at - fringe).r,
                       texture(source, at).g,
                       texture(source, at + fringe).b);
    colour = mix(colour, tint.rgb, tint.a);

    // light from the top left catching the rim, a faint glow along the bottom rim
    float facing = max(dot(n, normalize(vec2(-0.35, -1.0))), 0.0);
    float rim = pow(1.0 - inner, 5.0);
    colour += highlight * rim * (0.25 + 0.75 * facing);
    colour += highlight * 0.18 * pow(1.0 - inner, 2.0) * max(-n.y, 0.0);

    fragColor = vec4(colour, 1.0) * shape * qt_Opacity;
}
