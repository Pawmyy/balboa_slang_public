import hw1_common;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int samples_per_axis,
                  StructuredBuffer<Shape> shapes,
                  uniform int num_shapes,
                  StructuredBuffer<Circle> circles,
                  StructuredBuffer<Polyline> polylines,
                  StructuredBuffer<QuadraticBezier> /*quadratic_beziers*/, // ignore for now
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image) {
  uint width, height;
  image.GetDimensions(width, height);
  if (tid.x >= width || tid.y >= height) {
    return;
  }

  image[tid] = float4(background, 1.0);
  // TODO: your code here

  float4 accum = float4(0.0);
  for(int u = 0; u < samples_per_axis; u++){
    for(int v = 0; v < samples_per_axis; v++){
      float2 p = float2(tid.x + (u + 0.5) / samples_per_axis, height - 1 - tid.y + (v + 0.5) / samples_per_axis);

      float4 color = float4(background, 1.0);
      for(int i = num_shapes - 1; i >= 0; i--){
        // float2 pixels = float2(tid.x, height - 1 - tid.y);
        float2 pixels = p;
        int idx = shapes[i].index;
        Shape current_shape = shapes[i];
        float2 obj_pixel = transform(pixels , current_shape.world_to_obj);
        switch (shapes[i].type){
          case(ShapeType.Circle):

            bool inside = length(obj_pixel - circles[idx].center) <= circles[idx].radius;
            bool onStroke = (abs(length(obj_pixel - circles[idx].center) - circles[idx].radius)) < current_shape.stroke_width / 2;

            if(inside && current_shape.use_fill){
              color = current_shape.fill_rgba; 
            }
            if(onStroke && current_shape.use_stroke){
              color = current_shape.stroke_rgba;
            }
            break;
          case(ShapeType.Polyline):
            float2 pa; 
            float2 pb;
            int num_polyline = polylines[idx].pts_end - polylines[idx].pts_begin;

            float2 p = obj_pixel;

            // fill color
            if(polylines[idx].closed && current_shape.use_fill){
              int around = 0;

              for(int i = 0; i < num_polyline; i++){

                int j = (i + 1) % num_polyline;

                float2 pi = points[polylines[idx].pts_begin + i]; // polyline coord[i]
                float2 pj = points[polylines[idx].pts_begin + j]; // polyline coord[j]

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
                color = float4(current_shape.fill_rgba);
              }
            }

            if(current_shape.use_stroke){
              int stroke_count = polylines[idx].closed ? num_polyline: num_polyline - 1;

              for(int i = 0; i < stroke_count; i++){
                int next = (i + 1) % num_polyline;

                pa = points[polylines[idx].pts_begin + i]; // point a
                pb = points[polylines[idx].pts_begin + next]; // point b 

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

                // round caps
                if(!((i == 0 || i == stroke_count - 1) && !polylines[idx].closed)){   // exclude starting point and ending point
                  if(length(p - pb)  <= current_shape.stroke_width / 2.0 || length(p - pa) <= current_shape.stroke_width / 2.0){
                    color = current_shape.stroke_rgba;
                  }
                }
                if(distance < current_shape.stroke_width / 2.0 && 
                    dot_product >= 0 && 
                    dot_product <= length_squared)
                {
                  color = current_shape.stroke_rgba;
                }

              }

            }
            break;
        }
      }

      accum += color;
    }
  }
  image[tid] = accum / (samples_per_axis * samples_per_axis);
}

float2 transform(float2 pixel, float3x3 transformation_matrix){
  float3 result = mul(transformation_matrix, float3(pixel, 1.0));
  return result.xy;
}
