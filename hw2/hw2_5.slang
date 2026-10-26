[shader("compute")]
[numthreads(64, 1, 1)]
void clear_buffers(uint tid : SV_DispatchThreadID,
                   uniform uint num_pixels,
                   RWStructuredBuffer<uint> depth_buffer,
                   RWStructuredBuffer<uint> triangle_id_buffer) {
    if (tid >= num_pixels)
        return;

    depth_buffer[tid] = 0xffffffff;
    triangle_id_buffer[tid] = 0xffffffff;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void transform_vertices(
    uint tid : SV_DispatchThreadID,
    uniform uint num_vertices,
    uniform uint vertex_offset,
    uniform float4x4 MVP,
    StructuredBuffer<float3> vertices,
    RWStructuredBuffer<float3> projected_vertices)
{
    if (tid >= num_vertices)
        return;

    uint i = vertex_offset + tid;
    float4 p = mul(MVP, float4(vertices[i], 1.0));
    projected_vertices[i] = p.xyz / p.w;
}

[shader("compute")]
[numthreads(64, 1, 1)]
void rasterize_depth(
        uint tid : SV_DispatchThreadID,
        uniform uint num_triangles,
        uniform uint width,
        uniform uint height,
        uniform float s,
        uniform float a,
        StructuredBuffer<uint3> faces,
        // A projected vertex store the screen space coordinates
        // in xy, and the inverse depth in z.
        StructuredBuffer<float3> projected_vertices,
        RWStructuredBuffer<uint> depth_buffer) {
    // HW 2.5 TODO
    if(tid >= num_triangles){ return;}

    uint3 face_id = faces[tid];
    float3 sp0 = projected_vertices[face_id.x];
    float3 sp1 = projected_vertices[face_id.y];
    float3 sp2 = projected_vertices[face_id.z];

    float2 e01 = sp1.xy - sp0.xy;
    float2 e12 = sp2.xy - sp1.xy;
    float2 e20 = sp0.xy - sp2.xy;

    float2 n01 = float2(e01.y, - e01.x);
    float2 n12 = float2(e12.y, - e12.x);
    float2 n20 = float2(e20.y, - e20.x);

    float area = dot(sp2.xy - sp0.xy, n01);
    if (area <= 1e-12) return;
    
    float2 aabb_min = min(min(sp0.xy, sp1.xy), sp2.xy);
    float2 aabb_max = max(max(sp0.xy, sp1.xy), sp2.xy);
    
    int i0 = max(0, int(aabb_min.x));
    int j0 = max(0, int(aabb_min.y));
    int i1 = min(width, int(aabb_max.x));
    int j1 = min(height, int(aabb_max.y));

    for(int i = i0; i <= i1; i++){
        for(int j = j0; j <= j1; j++){
            float E01 = dot(float2(i + 0.5, j + 0.5) - sp0.xy, n01);
            float E12 = dot(float2(i + 0.5, j + 0.5) - sp1.xy, n12);
            float E20 = dot(float2(i + 0.5, j + 0.5) - sp2.xy, n20);
            if(( E01 <= 0 && E12 <= 0 && E20 <= 0) || (E01 >= 0 && E12 >= 0 && E20 >= 0)){
                float3 bp = float3(E12, E20, E01) / area;
                float3 w = bp * float3(sp0.z, sp1.z, sp2.z);
                float inverse_depth = w.x + w.y + w.z;

                float3 b = (bp * float3(sp0.z, sp1.z, sp2.z) / inverse_depth);

                float depth = 1.0 / inverse_depth;

                InterlockedMin(depth_buffer[j * width + i], asuint(depth));
            }
        }
    }
}

[shader("compute")]
[numthreads(64, 1, 1)]
void rasterize_id(
        uint tid : SV_DispatchThreadID,
        uniform uint num_triangles,
        uniform uint width,
        uniform uint height,
        uniform float s,
        uniform float a,
        StructuredBuffer<uint3> faces,
        StructuredBuffer<float3> projected_vertices,
        RWStructuredBuffer<uint> depth_buffer,
        RWStructuredBuffer<uint> triangle_id_buffer) {
    // HW 2.5 TODO
    if(tid >= num_triangles){ return;}

    uint3 face_id = faces[tid];
    float3 sp0 = projected_vertices[face_id.x];
    float3 sp1 = projected_vertices[face_id.y];
    float3 sp2 = projected_vertices[face_id.z];

    float2 e01 = sp1.xy - sp0.xy;
    float2 e12 = sp2.xy - sp1.xy;
    float2 e20 = sp0.xy - sp2.xy;

    float2 n01 = float2(e01.y, - e01.x);
    float2 n12 = float2(e12.y, - e12.x);
    float2 n20 = float2(e20.y, - e20.x);

    float area = dot(sp2.xy - sp0.xy, n01);
    if (abs(area) <= 1e-12) return;
    
    float2 aabb_min = min(min(sp0.xy, sp1.xy), sp2.xy);
    float2 aabb_max = max(max(sp0.xy, sp1.xy), sp2.xy);
    
    int i0 = max(0, int(aabb_min.x));
    int j0 = max(0, int(aabb_min.y));
    int i1 = min(width, int(aabb_max.x));
    int j1 = min(height, int(aabb_max.y));

    for(int i = i0; i <= i1; i++){
        for(int j = j0; j <= j1; j++){
            float E01 = dot(float2(i + 0.5, j + 0.5) - sp0.xy, n01);
            float E12 = dot(float2(i + 0.5, j + 0.5) - sp1.xy, n12);
            float E20 = dot(float2(i + 0.5, j + 0.5) - sp2.xy, n20);
            if(( E01 <= 0 && E12 <= 0 && E20 <= 0) || (E01 >= 0 && E12 >= 0 && E20 >= 0)){
                float3 bp = float3(E12, E20, E01) / area;
                float3 w = bp * float3(sp0.z, sp1.z, sp2.z);
                float inverse_depth = w.x + w.y + w.z;

                float3 b = (bp * float3(sp0.z, sp1.z, sp2.z) / inverse_depth);

                float depth = 1.0 / inverse_depth;

                uint idx = j * width + i;
                if(asuint(depth) == depth_buffer[idx]){
                    InterlockedMin(triangle_id_buffer[idx], tid);
                }
            }
        }
    }
}

[shader("compute")]
[numthreads(8, 8, 1)]
void shade(
        uint2 tid : SV_DispatchThreadID,
        uniform uint width,
        uniform uint height,
        uniform float s,
        uniform float a,
        StructuredBuffer<uint3> faces,
        StructuredBuffer<float3> vertex_colors,
        StructuredBuffer<float3> projected_vertices,
        StructuredBuffer<uint> triangle_id_buffer,
        RWTexture2D<float4> image) {
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    // HW 2.5 TODO
    uint face_id = triangle_id_buffer[tid.y * width + tid.x];
    if (face_id == 0xffffffff) return;

    uint3 f = faces[face_id];
    float3 sp0 = projected_vertices[f.x];
    float3 sp1 = projected_vertices[f.y];
    float3 sp2 = projected_vertices[f.z];

    float2 e01 = sp1.xy - sp0.xy;
    float2 e12 = sp2.xy - sp1.xy;
    float2 e20 = sp0.xy - sp2.xy;

    float2 n01 = float2(e01.y, - e01.x);
    float2 n12 = float2(e12.y, - e12.x);
    float2 n20 = float2(e20.y, - e20.x);

    float area = dot(sp2.xy - sp0.xy, n01);
    if (abs(area) <= 1e-12) return;

    float2 p = float2(tid) + 0.5;
    float E01 = dot(float2(p.x + 0.5, p.y + 0.5) - sp0.xy, n01);
    float E12 = dot(float2(p.x + 0.5, p.y + 0.5) - sp1.xy, n12);
    float E20 = dot(float2(p.x + 0.5, p.y + 0.5) - sp2.xy, n20);

    float3 bp = float3(E12, E20, E01) / area;
    float3 w = bp * float3(sp0.z, sp1.z, sp2.z);

    float3 b = w / (w.x + w.y + w.z);

    float3 color = b.x * vertex_colors[f.x]
                 + b.y * vertex_colors[f.y]
                 + b.z * vertex_colors[f.z];
    image[tid] = float4(color, 1.0);
}

float signed_area(float2 a, float2 b, float2 c){
    float2 ab = b - a;
    float2 ac = c - a;
    return length(ab.x * ac.y - ab.y * ac.x) / 2;
}
