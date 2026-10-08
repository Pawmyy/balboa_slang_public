import hw1_common;

interface IShape{
  bool inside(float2 pixel);

  bool onStroke(float2 pixel, float half_width);
};

float2 transform(float2 pixel, float3x3 transformation_matrix){
    float3 result = mul(transformation_matrix, float3(pixel, 1.0));
    return result.xy;
  }

void drawShape<T: IShape> (T draw, Shape style, float2 pixel, uint2 tid, RWTexture2D<float4> image){
  /*
  uint width, height;
  image.GetDimensions(width, height);
  float2 pixel = float2(tid.x, height - 1 - tid.y);
  */

  if(style.use_fill && draw.inside(pixel)){
    image[tid] = style.fill_rgba;
  }

  if(style.use_stroke && draw.onStroke(pixel, style.stroke_width / 2)){
    image[tid] = style.stroke_rgba;
  }

}

struct CircleShape : IShape {
  Circle data;

  bool inside(float2 pixel) { return length(pixel - data.center) <= data.radius; }
  bool onStroke(float2 pixel, float half_width) { return (abs(length(pixel - data.center) - data.radius)) < half_width; }
};

struct PolylineShape : IShape {
  Polyline data;
  StructuredBuffer<float2> points;

  bool inside(float2 pixel) {
    if(!data.closed) return false;
    int num_polyline = data.pts_end - data.pts_begin;
    int around = 0;


    for(int i = 0; i < num_polyline; i++){

      int j = (i + 1) % num_polyline;

      float2 pi = points[data.pts_begin + i]; // polyline coord[i]
      float2 pj = points[data.pts_begin + j]; // polyline coord[j]

      float2 v = pj - pi;
      float2 u = pixel - pi;

      // cross upward
      if (pi.y >= pixel.y && pj.y < pixel.y){
        float edge_cross = (v.x * u.y) - (u.x * v.y);   // 2D scalar cross product between vectors
        if(edge_cross > 0){
          around++;
        }
      } 
      // cross downward
      else if(pi.y < pixel.y && pj.y >= pixel.y){
        float edge_cross = (v.x * u.y) - (u.x * v.y);   // 2D scalar cross product between vectors
        if(edge_cross < 0){
          around--;
        }
      }

    }
    return around != 0;
  }

  bool onStroke(float2 pixel, float half_width){
    int num_polyline = data.pts_end - data.pts_begin;
    int stroke_count = data.closed ? num_polyline : num_polyline - 1;

    for(int i = 0; i < stroke_count; i++){
        float2 pa = points[data.pts_begin + i];
        float2 pb = points[data.pts_begin + (i + 1) % num_polyline];

        float2 p_diff = pb - pa;
        float2 offset_pixel = pixel - pa;

        float cross_product = offset_pixel.x * p_diff.y - offset_pixel.y * p_diff.x;
        float dot_product = dot(offset_pixel, p_diff);
        float length_squared = dot(p_diff, p_diff);
        
        // round caps
        if(!((i == 0 || i == stroke_count - 1) && !data.closed)){
            if (length(pixel - pb) <= half_width || length(pixel - pa) <= half_width){
              return true;              
              }
          }
        float distance = abs(cross_product) / sqrt(length_squared);
        if(distance < half_width && dot_product >= 0 && dot_product <= length_squared){
            return true;
          }

  }
    return false;

  }
};

void drawCircle(uint2 tid,
                Circle circle,
                Shape style,
                float2 pixel,
                RWTexture2D<float4> image){
  CircleShape c;
  c.data = circle;
  drawShape(c, style, pixel, tid, image);
}

void drawPolyline(uint2 tid, 
                  Polyline polyline,
                  Shape style,
                  float2 pixel,
                  StructuredBuffer<float2> points,
                  RWTexture2D<float4> image){
  PolylineShape p1;
  p1.data = polyline;
  p1.points = points;
  drawShape(p1, style, pixel, tid, image);
}
