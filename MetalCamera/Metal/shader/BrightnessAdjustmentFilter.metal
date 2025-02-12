//
//  BrightnessAdjustmentFilter.metal
//  MetalCamera
//
//  Created by sylar on 2025/2/12.
//

#include <metal_stdlib>
#include "ShaderHeader.h"
using namespace metal;



using namespace metal;

typedef struct
{
    float brightness;
} BrightnessUniform;

fragment half4 brightnessFragment(SingleInputVertexIO fragmentInput [[stage_in]],
                                  texture2d<half> inputTexture [[texture(0)]],
                                  constant BrightnessUniform& uniform [[ buffer(1) ]])
{
    constexpr sampler quadSampler;
    half4 color = inputTexture.sample(quadSampler, fragmentInput.textureCoordinate);
    
    return half4(color.rgb + uniform.brightness, color.a);
}
