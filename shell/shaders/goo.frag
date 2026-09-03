#version 440

// One surface for the rail and the open card: two rounded boxes as signed distance
// fields, joined by a circular smooth minimum so they meet in a fillet instead of a seam.
// Distances are in pixels; the shape is filled and outlined by a 1 px line inside its edge.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 size;
    vec4 rail;       // x, y, w, h
    vec4 railRadii;  // top-right, bottom-right, bottom-left, top-left
    vec4 cardBox;    // x, y, w, h; w <= 0 when no card is open
    float cardRadius;
    float smoothing;
    vec4 fill;
    vec4 line;
};

// Rounded box with per-corner radii, after Inigo Quilez.
float roundedBox(vec2 p, vec2 halfSize, vec4 r) {
    r.xy = p.x > 0.0 ? r.xy : r.wz;
    r.x = p.y > 0.0 ? r.y : r.x;
    vec2 q = abs(p) - halfSize + r.x;
    return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r.x;
}

float box(vec2 p, vec4 rect, vec4 radii) {
    vec2 halfSize = rect.zw * 0.5;
    return roundedBox(p - rect.xy - halfSize, halfSize, radii);
}

// Circular smooth minimum (Quilez): the blend between two shapes is an arc of radius k.
float smin(float a, float b, float k) {
    k *= 1.0 / (1.0 - sqrt(0.5));
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - k * 0.5 * (1.0 + h - sqrt(1.0 - h * (h - 2.0)));
}

void main() {
    vec2 p = qt_TexCoord0 * size;
    float d = box(p, rail, railRadii);
    if (cardBox.z > 0.0)
        d = smin(d, box(p, cardBox, vec4(cardRadius)), smoothing);

    float aa = fwidth(d);
    float inside = 1.0 - smoothstep(-aa, aa, d);
    float edge = smoothstep(-1.0 - aa, -1.0 + aa, d);
    vec4 colour = mix(fill, line, edge);
    fragColor = colour * inside * qt_Opacity;
}
