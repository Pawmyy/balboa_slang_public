import hw1_common;
import hw1_interface;

[shader("compute")]
[numthreads(8, 8, 1)]
void compute_main(uint2 tid : SV_DispatchThreadID,
                  uniform float3 background,
                  uniform int /*samples_per_axis*/, // ignore for now
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
    for(int i = num_shapes - 1; i >= 0; i--){
      float2 pixels = float2(tid.x, height - 1 - tid.y);
      int idx = shapes[i].index;
      Shape current_shape = shapes[i];
      float2 obj_pixel = transform(pixels, current_shape.world_to_obj);
      switch (shapes[i].type){
        case(ShapeType.Circle):
          drawCircle(tid, circles[idx], current_shape, obj_pixel, image);
          break;
        case(ShapeType.Polyline):
          drawPolyline(tid, polylines[idx], current_shape, obj_pixel, points, image);
          break;
      }
    }
}

