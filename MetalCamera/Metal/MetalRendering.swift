//
//  MetalRendering.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/5.
//

import Foundation
import MetalKit

//左上，右上，左下，右下
public let standardImageVertices: [Float] = [-1.0, 1.0, 1.0, 1.0, -1.0, -1.0, 1.0, -1.0]


extension MTLCommandBuffer {
    func renderQuad(
        pipelineState: MTLRenderPipelineState,
        inputTextures: [UInt: MetalTexture], useNormalizedTextureCoordinates: Bool = true,
        imageVertices: [Float] = standardImageVertices, outputTexture: MetalTexture,
        outputOrientation: ImageOrientation = .portrait
    ) {
        let vertexBuffer = MetalManager.shared.device.makeBuffer(
            bytes: imageVertices,
            length: imageVertices.count * MemoryLayout<Float>.size,
            options: [])!
        vertexBuffer.label = "Vertices"

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = outputTexture.texture
        renderPass.colorAttachments[0].clearColor = MTLClearColorMake(1, 0, 0, 1)
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].loadAction = .clear

        guard let renderEncoder = self.makeRenderCommandEncoder(descriptor: renderPass) else {
            fatalError("Could not create render encoder")
        }
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        for textureIndex in 0..<inputTextures.count {
            let currentTexture = inputTextures[UInt(textureIndex)]!

            let inputTextureCoordinates = currentTexture.textureCoordinates(
                for: outputOrientation, normalized: useNormalizedTextureCoordinates)
            let textureBuffer = MetalManager.shared.device.makeBuffer(
                bytes: inputTextureCoordinates,
                length: inputTextureCoordinates.count * MemoryLayout<Float>.size,
                options: [])!
            textureBuffer.label = "Texture Coordinates"

            renderEncoder.setVertexBuffer(textureBuffer, offset: 0, index: 1 + textureIndex)
            renderEncoder.setFragmentTexture(currentTexture.texture, index: textureIndex)
        }
        
        renderEncoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        renderEncoder.endEncoding()
    }
}
