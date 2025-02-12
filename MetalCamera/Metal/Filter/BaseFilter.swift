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

class BaseFilter : Producer , Consumer {
    var targets = TargetContainer()
    var inputParams: [String : Any] = [:]
    
    let renderPipelineState: MTLRenderPipelineState
    let operationName: String = #file
    
    var inputTextures = [UInt: MetalTexture]()
    let textureInputSemaphore = DispatchSemaphore(value: 1)
    var useNormalizedTextureCoordinates = true
    
    var textureCoordinate = standardImageVertices
    var uniformSettings: ShaderUniformSettings
    
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
        
        //Get Fragment Shader Params
        do {
            var reflection: MTLAutoreleasedRenderPipelineReflection?
            let pipelineState = try MetalManager.shared.device.makeRenderPipelineState(
                descriptor: descriptor, options: [.bufferTypeInfo, .argumentInfo],
                reflection: &reflection)
            
            var uniformLookupTable: [String: (Int, MTLStructMember)] = [:]
            var bufferSize: Int = 0
            if let fragmentArguments = reflection?.fragmentArguments {
                for fragmentArgument in fragmentArguments where fragmentArgument.type == .buffer {
                    if fragmentArgument.bufferDataType == .struct,
                       let members = fragmentArgument.bufferStructType?.members.enumerated()
                    {
                        bufferSize = fragmentArgument.bufferDataSize
                        for (index, uniform) in members {
                            uniformLookupTable[uniform.name] = (index, uniform)
                        }
                    }
                }
            }
            
            uniformSettings = ShaderUniformSettings(
                uniformLookupTable: uniformLookupTable, bufferSize: bufferSize)
            
        } catch {
            fatalError("Could Not Read Fragment Params")
        }
    }
    
    func internalRenderFunction(commandBuffer: MTLCommandBuffer, outputTexture: MetalTexture) {
        commandBuffer.renderQuad(
            pipelineState: renderPipelineState,
            uniformSettings: uniformSettings,
            inputTextures: inputTextures,
            useNormalizedTextureCoordinates: useNormalizedTextureCoordinates,
            imageVertices: textureCoordinate ,
            outputTexture: outputTexture)
    }
    
    func newInputParamsAvailable(_ inputParams: [String : Any]) {
        self.inputParams = inputParams
    }
    
    func newTextureAvailable(_ texture: MetalTexture) {
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }
        
        guard let commandBuffer = MetalManager.shared.commandQueue.makeCommandBuffer()
        else { return }
        
        let outputTexture = generateOutputTexture(texture)
        
        internalRenderFunction(commandBuffer: commandBuffer, outputTexture: outputTexture)
        commandBuffer.commit()
        textureInputSemaphore.signal()
        updateTargetsWithParams(self.inputParams)
        updateTargetsWithTexture(outputTexture)
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
    
    
    func generateOutputTexture(_ inputTexture:MetalTexture) -> MetalTexture {
        inputTextures[0] = inputTexture
        
        let outputWidth: Int
        let outputHeight: Int
        let firstInputTexture = inputTexture
        if firstInputTexture.orientation.rotationNeeded(for: .portrait).flipsDimensions() {
            outputWidth = firstInputTexture.texture.height
            outputHeight = firstInputTexture.texture.width
        } else {
            outputWidth = firstInputTexture.texture.width
            outputHeight = firstInputTexture.texture.height
        }
        

        
        let outputTexture = MetalTexture(
            orientation: .portrait,
            width: outputWidth, height: outputHeight
        )
        
        return outputTexture
    }
}



