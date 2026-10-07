import hw1_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  StructuredBuffer<float2> polyline,
                  uniform int num_polyline,
                  uniform bool is_closed,
                  uniform bool use_fill_color,
                  uniform float3 fill_color,
                  uniform bool use_stroke_color,
                  uniform float3 stroke_color,
                  uniform float stroke_width,
                  RWTexture2D<float4> image) {
    uint width, height;
    image.GetDimensions(width, height);
    if (tid.x >= width || tid.y >= height) {
        return;
    }

    image[tid] = float4(1.0);

    // TODO: your code here
    float2 pa; 
    float2 pb;

    float2 p = float2(tid.x, height - 1 - tid.y);

    // fill color
    if(is_closed && use_fill_color){
        int around = 0;

        for(int i = 0; i < num_polyline; i++){

            int j = (i + 1) % num_polyline;

            float2 pi = polyline[i]; // polyline coord[i]
            float2 pj = polyline[j]; // polyline coord[j]

            bool between = ((pi.y > p.y) != (pj.y > p.y));

            float2 v = pj - pi;
            float2 u = p - pi;

            // cross upward
            if (pi.y >= p.y && pj.y < p.y){
                float edge_cross = (v.x * u.y) - (u.x * v.y);   // 2D scalar cross product between vectors
                if(edge_cross > 0){
                    around++;
                }
            } 
            // cross downward
            else if(pi.y < p.y && pj.y >= p.y){
                float edge_cross = (v.x * u.y) - (u.x * v.y);   // 2D scalar cross product between vectors
                if(edge_cross < 0){
                    around--;
                }
            }

        }

        if(around != 0){
            image[tid] = float4(fill_color, 1.0);
        }
    }

    if(use_stroke_color){
        int stroke_count = is_closed ? num_polyline: num_polyline - 1;

        for(int i = 0; i < stroke_count; i++){
            int next = (i + 1) % num_polyline;

            pa = polyline[i]; // point a
            pb = polyline[next]; // point b 

            float2 p_diff = pb - pa;    // vector differences between 2 points

            float2 offset_pixel = p - pa;     // offset for starting point to be at pa not origin

            float cross_product = offset_pixel.x * p_diff.y - offset_pixel.y * p_diff.x;    
            /*
                gives the length of the offset_pixel to the line.
                aka size of the cross product(3D)
                aka the area of the parallelogram of two input vectors
                note that the cross product(3D) is perpendicular to vector p_diff
            */

            float dot_product = dot(offset_pixel, p_diff);    
            /*
                gives how long offset_pixel is in term/direction of p_diff
                so we can compare that the pixel is beyond offset_pixel 
            */
            float length_squared = dot(p_diff, p_diff); 
            /*
                gives the length of the line segment
                we can use this to compare that the pixel is not beyond the point pb
            */

            float distance = abs(cross_product) / sqrt(length_squared); // distance from pixel to the line

            // check stroke_color
            float alpha = 0.0;
            if(use_stroke_color){
                alpha = 1.0;
            }

            // round corners
            if(length(p - pb)  <= stroke_width / 2.0 || length(p - pa) <= stroke_width / 2.0){
                image[tid] = float4(stroke_color, alpha);
            }

            if(distance < stroke_width / 2.0 && 
            dot_product >= 0 && 
            dot_product <= length_squared)
            {
                    image[tid] = float4(stroke_color, alpha);
            }

        }

    }
}
