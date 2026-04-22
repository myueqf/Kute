#ifdef CELSHADING
float get_cel_depth(vec2 Coord) {
    return texture2D(depthtex0, Coord).x;
}

vec3 apply_celshading(vec3 Color, vec2 Coord) {
    float Depth = get_cel_depth(Coord);
    if (Depth >= 1.0) {
        return Color;
    }

    vec2 Texel = resolutionInv;
    float Threshold = 1.0 / (far - near) * 0.0005;

    vec4 SamplesA = vec4(
        get_cel_depth(Coord + vec2(-Texel.x, -Texel.y)),
        get_cel_depth(Coord + vec2( Texel.x, -Texel.y)),
        get_cel_depth(Coord + vec2(-Texel.x,  0.0)),
        get_cel_depth(Coord + vec2( 0.0,      Texel.y))
    );

    vec4 SamplesB = vec4(
        get_cel_depth(Coord + vec2( Texel.x,  Texel.y)),
        get_cel_depth(Coord + vec2(-Texel.x,  Texel.y)),
        get_cel_depth(Coord + vec2( Texel.x,  0.0)),
        get_cel_depth(Coord + vec2( 0.0,     -Texel.y))
    );

    vec4 Edges = abs(2.0 * Depth - SamplesA - SamplesB) - Threshold;
    Edges = step(Edges, vec4(0.0));

    float EdgeMask = clamp(dot(Edges, vec4(0.25)), 0.0, 1.0);
    return Color * EdgeMask;
}
#endif
