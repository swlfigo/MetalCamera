//
//  FaceRectangleFilter.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/11.
//

import Foundation
import Metal
class FaceRectangleFilter: BaseFilter {
    
    var lineRenderPipelineState: MTLRenderPipelineState
    
    override init(vertexFunctionName: String? = nil, fragmentFunctionName: String, numberOfInputs: UInt = 1) {
        
        //初始化框Shader
        // 设置线条渲染管线
        let lineVertexFunction = MetalManager.shared.shaderLibrary.makeFunction(name: "lineVertexShader")
        let lineFragmentFunction = MetalManager.shared.shaderLibrary.makeFunction(name: "lineFragmentShader")
        
        let linePipelineDescriptor = MTLRenderPipelineDescriptor()
        linePipelineDescriptor.vertexFunction = lineVertexFunction
        linePipelineDescriptor.fragmentFunction = lineFragmentFunction
        linePipelineDescriptor.colorAttachments[0].pixelFormat =  MTLPixelFormat.bgra8Unorm
        // 启用混合以便线条可以正确叠加在视频帧上
        linePipelineDescriptor.colorAttachments[0].isBlendingEnabled = true
        linePipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
        linePipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        
        do {
            lineRenderPipelineState = try MetalManager.shared.device.makeRenderPipelineState(descriptor: linePipelineDescriptor)
        } catch {
            fatalError("Failed to create line pipeline state: \(error)")
        }
        
        super.init(vertexFunctionName: vertexFunctionName, fragmentFunctionName: fragmentFunctionName , numberOfInputs: numberOfInputs)
    }
    
    // 线条顶点结构体
    struct LineVertex {
        var position: SIMD2<Float>
        var color: SIMD4<Float>
    }
    
    override func internalRenderFunction(commandBuffer: any MTLCommandBuffer, outputTexture: MetalTexture) {
        
        let vertexBuffer = MetalManager.shared.device.makeBuffer(
            bytes: textureCoordinate,
            length: textureCoordinate.count * MemoryLayout<Float>.size,
            options: [])!
        vertexBuffer.label = "Vertices"
        
        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = outputTexture.texture
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear
        
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
//        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(renderPipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        for textureIndex in 0..<inputTextures.count {
            let currentTexture = inputTextures[UInt(textureIndex)]!
            
            let inputTextureCoordinates = currentTexture.textureCoordinates(
                for: .portrait, normalized: useNormalizedTextureCoordinates)
            let textureBuffer = MetalManager.shared.device.makeBuffer(
                bytes: inputTextureCoordinates,
                length: inputTextureCoordinates.count * MemoryLayout<Float>.size,
                options: [])!
            textureBuffer.label = "Texture Coordinates"
            
            renderEncoder.setVertexBuffer(textureBuffer, offset: 0, index: 1 + textureIndex)
            renderEncoder.setFragmentTexture(currentTexture.texture, index: textureIndex)
        }
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        uniformSettings.restoreShaderSettings(renderEncoder: renderEncoder)
        drawRectangle(renderEncoder: renderEncoder)
        
        renderEncoder.endEncoding()
    }
    
    
    func drawRectangle(renderEncoder: MTLRenderCommandEncoder){
        guard let faces = inputParams[FaceLandmarkKey] as? [CGRect] else {
            return
        }
        // 切换到线条渲染管线
        renderEncoder.setRenderPipelineState(lineRenderPipelineState)
        for face in faces {
            let rect = face
//            print(rect)
            // 转换坐标到Metal坐标系统（-1 到 1）
            let left = Float(rect.minX) * 2 - 1
            let right = Float(rect.maxX) * 2 - 1

            //Camera Front Facing Position
            var top = 1 - Float(1 - rect.minY) * 2
            var bottom = 1 - Float(1 - rect.maxY) * 2
            if let cameraPosition = inputParams[CameraPhysicalPositionKey] as? PhysicalCameraLocation , cameraPosition == .backFacing {
                //Back Facing Position
                top = Float(1 - rect.minY) * 2 - 1
                bottom = Float(1 - rect.maxY) * 2 - 1
            }
            // 创建矩形的顶点数据
            let lineColor = SIMD4<Float>(0, 1, 0, 1) // 绿色
            let vertices: [LineVertex] = [
                // 左边
                LineVertex(position: SIMD2<Float>(left, bottom), color: lineColor),
                LineVertex(position: SIMD2<Float>(left, top), color: lineColor),
                
                // 上边
                LineVertex(position: SIMD2<Float>(left, top), color: lineColor),
                LineVertex(position: SIMD2<Float>(right, top), color: lineColor),
                
                // 右边
                LineVertex(position: SIMD2<Float>(right, top), color: lineColor),
                LineVertex(position: SIMD2<Float>(right, bottom), color: lineColor),
                
                // 下边
                LineVertex(position: SIMD2<Float>(right, bottom), color: lineColor),
                LineVertex(position: SIMD2<Float>(left, bottom), color: lineColor)
            ]
            
            // 创建顶点缓冲区
            let vertexBuffer = MetalManager.shared.device.makeBuffer(bytes: vertices,
                                                 length: vertices.count * MemoryLayout<LineVertex>.stride,
                                                 options: [])
            
            // 设置顶点缓冲区
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            // 设置线条颜色
            var color = SIMD4<Float>(0, 1, 0, 1) // 绿色
            renderEncoder.setFragmentBytes(&color,
                                           length: MemoryLayout<SIMD4<Float>>.size,
                                           index: 0)
            
            // 绘制线条
            renderEncoder.drawPrimitives(type: .line,
                                         vertexStart: 0,
                                         vertexCount: vertices.count)
        }
    }
}
