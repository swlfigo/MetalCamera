//
//  ShaderHeader.h
//  MetalCamera
//
//  Created by sylar on 2025/2/12.
//

#ifndef ShaderHeader_h
#define ShaderHeader_h

struct SingleInputVertexIO
{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
};

struct TwoInputVertexIO
{
    float4 position [[position]];
    float2 textureCoordinate [[user(texturecoord)]];
    float2 textureCoordinate2 [[user(texturecoord2)]];
};


#endif /* ShaderHeader_h */
