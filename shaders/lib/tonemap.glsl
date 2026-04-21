
#define to_linear(sRGB) ( sRGB * (sRGB * (sRGB * 0.305306011 + 0.682171111) + 0.012522878) )

vec3 apply_tonemap(vec3 X) {
    #if TONEMAP_OPERATOR == 1
    return ACESFilm(X);
    #elif TONEMAP_OPERATOR == 2
    return reinhard_jodie(X);
    #elif TONEMAP_OPERATOR == 3
    return ACES_slow(X);
    #elif TONEMAP_OPERATOR == 4
    return Hejl2015(X);
    #endif
}

vec2 R2_samples(int n) {
    return fract(vec2(0.75487765, 0.56984026) * float(n));
}

float dynamic_exposure_from_luminance(float Luminance) {
    Luminance = max(Luminance, 1e-8);
    return 0.18 / log2(Luminance * 2.5 + 1.045) * 0.62;
}

float read_dynamic_exposure() {
    #ifdef DYNAMIC_EXPOSURE
    float StoredExposure = texelFetch2D(gaux1, ivec2(10, 37), 0).r;
    if (StoredExposure <= 0.0) StoredExposure = 1.0;
    StoredExposure = clamp(StoredExposure, 0.05, 12.0);
    return mix(1.0, StoredExposure, DYNAMIC_EXPOSURE_STRENGTH);
    #else
    return 1.0;
    #endif
}

vec2 calculate_dynamic_exposure() {
    const int SampleCount = 50;
    float LogLuminance = 0.0;

    for (int i = 0; i < SampleCount; i++) {
        vec2 Xi = R2_samples((frameCounter % 2000) * SampleCount + i);
        vec2 Coord = 0.5 + (Xi - 0.5) * 0.7;
        vec3 SampleColor = texture2D(colortex0, Coord).rgb;
        LogLuminance += log(max(get_luminance(SampleColor), 0.00003051757));
    }

    float AvgLuminance = exp(LogLuminance / float(SampleCount));
    float PrevLuminance = texelFetch2D(gaux1, ivec2(10, 37), 0).g;
    if (PrevLuminance <= 0.0) PrevLuminance = AvgLuminance;
    AvgLuminance = clamp(mix(AvgLuminance, PrevLuminance, 0.95), 0.00003051757, 65000.0);

    float TargetExposure = dynamic_exposure_from_luminance(AvgLuminance) * 1.35;
    float PrevExposure = texelFetch2D(gaux1, ivec2(10, 37), 0).r;
    if (PrevExposure <= 0.0) PrevExposure = TargetExposure;
    PrevExposure = clamp(PrevExposure, 0.05, 12.0);

    float AdaptRate = clamp(DYNAMIC_EXPOSURE_SPEED * exp(-0.016 / max(frameTime, 0.0001) + 1.0), 0.0, 1.0);
    float Exposure = mix(PrevExposure, TargetExposure, AdaptRate);
    return vec2(clamp(Exposure, 0.05, 12.0), AvgLuminance);
}

vec3 apply_saturation(vec3 Color, float Sat) {
    float luminance = get_luminance(Color);
    return mix(vec3(luminance), Color, Sat);
}

vec3 apply_vibrance(vec3 color, float intensity) {
    float mn = min(color.r, min(color.g, color.b));
    float mx = max(color.r, max(color.g, color.b));
    float sat = (1.0 - clamp(mx - mn, 0, 1)) * clamp(1.0 - mx, 0, 1) * get_luminance(color) * 5.0;
    vec3 lightness = vec3((mn + mx) * 0.5);

    return mix(color, mix(lightness, color, intensity), sat);
}

vec3 apply_contrast(vec3 color, float contrast) {
    return (color - 0.5) * contrast + 0.5;
}

// Mix colors, preserving the luminance of c1
vec3 mix_preserve_c1lum(vec3 C1, vec3 C2, float Weight) {
    float L1 = get_luminance(C1);

    vec3 CMixed = mix(C1, C2, Weight);
    float L = get_luminance(CMixed);

    float Scale = L1 / L;

    return CMixed * Scale;
}
