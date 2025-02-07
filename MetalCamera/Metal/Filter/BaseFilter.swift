//
//  BaseFilter.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/6.
//
import MetalKit

public func defaultVertexFunctionNameForInputs(_ inputCount: UInt) -> String {
    switch inputCount {
    case 1:
        return "oneInputVertex"
    case 2:
        return "twoInputVertex"
    default:
        return "oneInputVertex"
    }
}

class BaseFilter : Producer  {
    var targets = TargetContainer()
    
    let renderPipelineState: MTLRenderPipelineState
    let operationName: String = #file
    
    var inputTextures = [UInt: MetalTexture]()
    let textureInputSemaphore = DispatchSemaphore(value: 1)
    var useNormalizedTextureCoordinates = true
    
    init(vertexFunctionName: String? = nil, fragmentFunctionName: String , numberOfInputs: UInt = 1) {
        let concreteVertexFunctionName =
        vertexFunctionName ?? defaultVertexFunctionNameForInputs(numberOfInputs)
        
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        
        guard let vertexFunction = MetalManager.shared.shaderLibrary.makeFunction(name: concreteVertexFunctionName) else {
            fatalError("Can't Read VertexFunction")
        }
        guard let fragmentFunction = MetalManager.shared.shaderLibrary.makeFunction(name: fragmentFunctionName) else {
            fatalError("Can't Read FragmentFunction")
        }
        
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        do {
            self.renderPipelineState = try MetalManager.shared.device.makeRenderPipelineState(descriptor: descriptor)
        } catch  {
            fatalError("Can't create renderPipelineState")
        }
    }
    
}


extension BaseFilter : Consumer{
    func newTextureAvailable(_ texture: MetalTexture) {
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }
        
        inputTextures[0] = texture
        
        let outputWidth: Int
        let outputHeight: Int
        let firstInputTexture = texture
        if firstInputTexture.orientation.rotationNeeded(for: .portrait).flipsDimensions() {
            outputWidth = firstInputTexture.texture.height
            outputHeight = firstInputTexture.texture.width
        } else {
            outputWidth = firstInputTexture.texture.width
            outputHeight = firstInputTexture.texture.height
        }
        
        guard let commandBuffer = MetalManager.shared.commandQueue.makeCommandBuffer()
        else { return }
        
        let outputTexture = MetalTexture(
            orientation: .portrait,
            width: outputWidth, height: outputHeight
        )
        internalRenderFunction(commandBuffer: commandBuffer, outputTexture: outputTexture)
        commandBuffer.commit()
        textureInputSemaphore.signal()
        updateTargetsWithTexture(outputTexture)
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    
    func internalRenderFunction(commandBuffer: MTLCommandBuffer, outputTexture: MetalTexture) {
        commandBuffer.renderQuad(
            pipelineState: renderPipelineState,
            inputTextures: inputTextures,
            useNormalizedTextureCoordinates: useNormalizedTextureCoordinates,
            outputTexture: outputTexture)
    }
}

