import hw3_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  StructuredBuffer<Sphere> spheres,
                  uniform int num_spheres,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    float aspect = float(width) / float(height);
    float u = (float(tid.x) + 0.5) / float(width);
    float v = (float(tid.y) + 0.5) / float(height);
    float3 origin = float3(0.0);
    float3 dir = float3(-aspect + 2.0 * aspect * u, 1.0 - 2.0 * v, -1);

    float t_closest = 1e30;
    int hit_id = -1;
    for(int i = 0; i < num_spheres; i++){
        Sphere s = spheres[i];

        float3 oc = origin - s.center;
        float a = dot(dir, dir);
        float b = 2.0 * dot(dir,oc);
        float c = dot(oc,oc) - pow(s.radius, 2);
        float2 roots;
        if(!solve_quadratic(a, b, c, roots)){
                continue;
        }

        float t0 = min(roots.x, roots.y);
        float t1 = max(roots.x, roots.y);
        float t = t0 > 0.0 ? t0 : t1;
        if(t > 0.0 && t < t_closest){
            t_closest = t;
            hit_id = i;
        }
    }

    float3 color = background;
    if (hit_id >= 0){
        Sphere s = spheres[hit_id];
        float3 p = origin + t_closest * dir;
        float3 n = (p - s.center) / s.radius;
        color =  (n + 1.0) / 2.0;
    }

    image[tid] = float4(color, 1.0);
}
