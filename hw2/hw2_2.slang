[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float2 sp0, // vertex at screen space
                  uniform float2 sp1,
                  uniform float2 sp2,
                  uniform float inv_depth0, // inverse depth in camera space
                  uniform float inv_depth1,
                  uniform float inv_depth2,
                  uniform int2 aabb_min,
                  uniform float3 c0, // vertex color
                  uniform float3 c1,
                  uniform float3 c2,
                  uniform float s,
                  uniform float a,
                  RWTexture2D<float4> color_image,
                  RWTexture2D<float> depth_image) {
    int2 ipixel = int2(tid) + int2(aabb_min);
    uint width, height;
    color_image.GetDimensions(width, height);
    if (ipixel.x < 0 || ipixel.y < 0 || ipixel.x >= width || ipixel.y >= height) {
        return;
    }

    // TODO: HW 2.1
    float2 e01 = sp1 - sp0;
    float2 e12 = sp2 - sp1;
    float2 e20 = sp0 - sp2;

    float2 n01 = float2(e01.y, - e01.x);
    float2 n12 = float2(e12.y, - e12.x);
    float2 n20 = float2(e20.y, - e20.x);

    float E01 = dot(float2(ipixel.x + 0.5, ipixel.y + 0.5) - sp0, n01);
    float E12 = dot(float2(ipixel.x + 0.5, ipixel.y + 0.5) - sp1, n12);
    float E20 = dot(float2(ipixel.x + 0.5, ipixel.y + 0.5) - sp2, n20);

    if(( E01 <= 0 && E12 <= 0 && E20 <= 0) || (E01 >= 0 && E12 >= 0 && E20 >= 0)){
        float area = signed_area(sp0, sp1, sp2);
        float bp0 = signed_area(float2(ipixel.x + 0.5, ipixel.y + 0.5), sp1, sp2) / area;
        float bp1 = signed_area(sp0, float2(ipixel.x + 0.5, ipixel.y + 0.5), sp2) / area;
        float bp2 = signed_area(sp0, sp1, float2(ipixel.x + 0.5, ipixel.y + 0.5)) / area;

        float w0 = bp0 * inv_depth0;
        float w1 = bp1 * inv_depth1;
        float w2 = bp2 * inv_depth2;
        float inverse_depth = w0 + w1 + w2;

        float b0 = (bp0 * inv_depth0) / inverse_depth;
        float b1 = (bp1 * inv_depth1) / inverse_depth;
        float b2 = (bp2 * inv_depth2) / inverse_depth;

        float depth = 1.0 / inverse_depth;

        if(depth < depth_image[ipixel]){
            depth_image[ipixel] = depth;
            color_image[ipixel] = float4(b0 * c0 + b1 * c1 + b2 * c2, 1.0);
        }
    }
}

float signed_area(float2 a, float2 b, float2 c){
    float2 ab = b - a;
    float2 ac = c - a;
    return length(ab.x * ac.y - ab.y * ac.x) / 2;
}
