//
//  FaceRectangle.metal
//  MetalCamera
//
//  Created by sylar on 2025/2/11.
//

#include <metal_stdlib>
using namespace metal;


// 线条顶点结构体
struct LineVertex {
    float2 position;
    float4 color;
};

// 线条顶点着色器
vertex float4 lineVertexShader(const device LineVertex* vertices [[buffer(0)]],
                              uint vid [[vertex_id]]) {
    LineVertex vert = vertices[vid];
    return float4(vert.position, 0.0, 1.0);
}

// 线条片段着色器
fragment float4 lineFragmentShader(float4 position [[stage_in]],
                                  constant float4 &color [[buffer(0)]]) {
    return color;
}
