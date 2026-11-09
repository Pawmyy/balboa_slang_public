import hw3_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Sphere> spheres,
                  StructuredBuffer<PointLight> lights,
                  uniform int num_lights,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    const float PI = 3.14159;

    float aspect = float(width) / float(height);
    float u = (float(tid.x) + 0.5) / float(width);
    float v = (float(tid.y) + 0.5) / float(height);
    float3 origin = float3(0.0);
    float3 dir = float3(-aspect + 2.0 * aspect * u, 1.0 - 2.0 * v, -1);

    float t_closest = 1e30;
    int hit_id = -1;
    for(int i = 0; i < num_shapes; i++){
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
        float t = t0 > EPSILON ? t0 : t1;
        if(t > EPSILON && t < t_closest){
            t_closest = t;
            hit_id = i;
        }
    }

    if(hit_id < 0){
        image[tid] = float4(background, 1.0);
        return;
    }

    Shape shape = shapes[hit_id];
    Sphere hit_sphere = spheres[shape.index];
    float3 p = origin + t_closest * dir;
    float3 n = normalize(p - hit_sphere.center);

    if(dot(n,dir) > 0){
        n = -n;
    }

    float3 color = float3(0.0);
    for(int l_id = 0; l_id < num_lights; l_id++){
        PointLight light = lights[l_id];
        float3 to_light = light.position - p;
        float d2 = dot(to_light, to_light);
        float3 l = to_light / sqrt(d2);
        float ndotl = dot(n, l);
        if (ndotl <= 0){
            continue;
        }
        
        bool blocked = false;
        for(int i = 0; i < num_shapes; i++){
            Sphere s = spheres[shapes[i].index];
            float3 oc = p - s.center;
            float a = dot(to_light, to_light);
            float b = 2.0 * dot(to_light, oc);
            float c = dot(oc,oc) - pow(s.radius, 2);
            float2 roots;
            if(!solve_quadratic(a, b, c, roots)){
                continue;
            }
            float t0 = min(roots.x, roots.y);
            float t1 = max(roots.x, roots.y);
            if((t0 > EPSILON && t0 < 1.0 - EPSILON) ||
               (t1 > EPSILON && t1 < 1.0 - EPSILON)){
                blocked = true;
                break;
            }
        }

        if(blocked){
            continue;
        }

        color += shape.Kd * ndotl * light.intensity / (PI * d2);
    }

    image[tid] = float4(color, 1.0);
}
