import hw3_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform Camera camera,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Sphere> spheres,
                  StructuredBuffer<TriangleMesh> meshes,
                  StructuredBuffer<float3> vertices,
                  StructuredBuffer<float3> vertex_normals,
                  StructuredBuffer<uint3> triangles,
                  StructuredBuffer<BVHNode> bvh_nodes,
                  StructuredBuffer<PointLight> lights,
                  uniform int num_lights,
                  uniform int max_depth,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    float PI = 3.14159;

    float aspect = float(width) / float(height);
    float plane_w = 2.0 * tan(radians(camera.fov_x) / 2.0);
    float plane_h = plane_w / aspect;
    float u = (float(tid.x) + 0.5) / float(width);
    float v = (float(tid.y) + 0.5) / float(height);
    float3 dir_cam = float3((u - 0.5) * plane_w, (0.5 - v) * plane_h, -1.0);

    float3 origin = mul(camera.cam_to_world, float4(0.0, 0.0, 0.0, 1.0)).xyz;
    float3 dir = mul(camera.cam_to_world, float4(dir_cam, 0.0)).xyz;

    float3 color = float3(0.0);
    float3 throughput = float3(1.0);

    for(int depth = 0; depth < max_depth; depth++){
        float t_closest = 1e30;
        int hit_id = -1;
        float3 n_obj_hit = float3(0.0,0.0,1.0);

        for(int i = 0; i < num_shapes; i++){
            Shape sh = shapes[i];
            float3 o_obj = mul(sh.world_to_obj, float4(origin, 1.0)).xyz;
            float3 d_obj = mul(sh.world_to_obj, float4(dir, 0.0)).xyz;

            if (sh.type == ShapeType.Sphere){
                Sphere s = spheres[sh.index];
                float3 oc = o_obj - s.center;
                float a = dot(d_obj, d_obj);
                float b = 2.0 * dot(d_obj, oc);
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
                    n_obj_hit = (o_obj + t * d_obj) - s.center;
                }
            } else{
                TriangleMesh mesh = meshes[sh.index];
                int node_id = int(mesh.bvh_root_index);
                int end_id = bvh_nodes[node_id].next_index;
                while(node_id < end_id){
                    BVHNode node = bvh_nodes[node_id];
                    if(!intersect_aabb(node.bbox_min, node.bbox_max,
                                       o_obj, d_obj, EPSILON, t_closest)){
                        node_id = node.next_index;
                        continue;
                    }

                    if(node.is_leaf){
                        for (int j = node.triangle_begin; j < node.triangle_end; j++){
                            int3 tri = triangles[j] + mesh.vertex_offset;
                            float3 b;
                            float t;
                            if (intersect_tri(vertices[tri.x], vertices[tri.y], vertices[tri.z],
                                o_obj, d_obj, EPSILON, t_closest, b, t)){
                                t_closest = t;
                                hit_id = i;
                                n_obj_hit = b.x * vertex_normals[tri.x] +
                                            b.y * vertex_normals[tri.y] +
                                            b.z * vertex_normals[tri.z];
                            }
                        }
                    }
                    node_id++;
                }
            }
        }

        if(hit_id < 0){
            color += throughput * background;
            break;
        }
        Shape shape = shapes[hit_id];
        float3 p = origin + t_closest * dir;

        float3 n = normalize(mul(float4(n_obj_hit, 0.0), shape.world_to_obj).xyz);

        if(dot(n,dir) > 0){
            n = -n;
        }

        float3 contribution = float3(0.0);
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
                Shape sh = shapes[i];
                float3 o_obj = mul(sh.world_to_obj, float4(p, 1.0)).xyz;
                float3 d_obj = mul(sh.world_to_obj, float4(to_light, 0.0)).xyz;

                if (sh.type == ShapeType.Sphere){
                    Sphere s = spheres[sh.index];
                    float3 oc = o_obj - s.center;
                    float a = dot(d_obj, d_obj);
                    float b = 2.0 * dot(d_obj, oc);
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
                } else{
                    TriangleMesh mesh = meshes[sh.index];
                    int node_id = int(mesh.bvh_root_index);
                    int end_id = bvh_nodes[node_id].next_index;
                    while(node_id < end_id){
                        BVHNode node = bvh_nodes[node_id];
                        if(!intersect_aabb(node.bbox_min, node.bbox_max,
                                        o_obj, d_obj, EPSILON, t_closest)){
                            node_id = node.next_index;
                            continue;
                        }

                        if(node.is_leaf){
                            for (int j = node.triangle_begin; j < node.triangle_end; j++){
                                int3 tri = triangles[j] + mesh.vertex_offset;
                                float3 b;
                                float t;
                                if (intersect_tri(vertices[tri.x], vertices[tri.y], vertices[tri.z],
                                    o_obj, d_obj, EPSILON, t_closest, b, t)){
                                    blocked = true;
                                    break;
                                }
                            }
                        }
                        node_id++;
                    }
                }
            }

            if(blocked){
                continue;
            }

            contribution += shape.Kd * ndotl * light.intensity / (PI * d2);
        }
        color += throughput * contribution;

        throughput *= shape.Kr;
        if (all(throughput <= 0.0)){
            break;
        }

         origin = p;
         dir = reflect(normalize(dir), n);
    }

    image[tid] = float4(color, 1.0);
}
