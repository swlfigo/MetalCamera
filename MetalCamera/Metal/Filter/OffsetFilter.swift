//
//  CropFilter.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/7.
//
import Foundation
import Metal

class OffsetFilter : BaseFilter {
    //用于输入纹理在输出纹理上移动

    //Frame的定义为
    //originX 为Cropfilter的输入纹理在输出纹理左右偏移的百分比，百分比是基于输出纹理的宽度计算
    //originY 为Cropfilter的输入纹理在输出纹理上下偏移的百分比，百分比基于输出纹理的高度计算
    //如
    //如4:3输出的摄像头纹理展示在16:9的屏幕上
    //Frame则为(0,0.125,16width,9height)
    //因为 cameraPreset = .photo时候为4:3,纹理以1440:1080为例
    //显示在尺寸为16:9的 1920 1080上,纹理居中时候,y为0.125,即 ((1920-1440)/2) / 1920
    
    //由于是OffsetFilter,完整展示纹理
    //则设置好便宜坐标好,只需x,y + 2则为右边与下边的最边坐标
    //因为纹理坐标是-1-1,+2是因为入参时候方便设置，不需要设置负数换算,则直接在内部做好换算
    var outputFrame : CGRect = .zero
    
    private var cropVertext = standardImageVertices
    
    override func internalRenderFunction(commandBuffer: any MTLCommandBuffer, outputTexture: MetalTexture) {
        commandBuffer.renderQuad(
            pipelineState: renderPipelineState,
            inputTextures: inputTextures,
            useNormalizedTextureCoordinates: useNormalizedTextureCoordinates, imageVertices: cropVertext,
            outputTexture: outputTexture)
        
    }
    
    override func newTextureAvailable(_ texture: MetalTexture) {
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
        defer {
            textureInputSemaphore.signal()
        }
        
        
        guard let commandBuffer = MetalManager.shared.commandQueue.makeCommandBuffer()
        else { return }
        
        inputTextures[0] = texture
        let outputWidth: Int
        let outputHeight: Int
        if  outputFrame.equalTo(.zero) {
            let firstInputTexture = texture
            if firstInputTexture.orientation.rotationNeeded(for: .portrait).flipsDimensions() {
                outputWidth = firstInputTexture.texture.height
                outputHeight = firstInputTexture.texture.width
            } else {
                outputWidth = firstInputTexture.texture.width
                outputHeight = firstInputTexture.texture.height
            }
        }else {
            outputWidth = Int(outputFrame.size.width)
            outputHeight = Int(outputFrame.size.height)
        }

        
        let outputTexture : MetalTexture
       
        if outputFrame.equalTo(.zero) {
            fatalError("Should Set Output Frame First")
        }

        outputTexture = MetalTexture(
            orientation: .portrait,
            width: Int(outputWidth), height: Int(outputHeight)
        )

        let left = Float (outputFrame.origin.x - 1 )
        let right = left + 2
        let top =  2 * (1.0 - Float(outputFrame.origin.y)) - 1
        let bottom =  top - 2
        cropVertext = [left,top,right,top,left,bottom,right,bottom]
        
        
        internalRenderFunction(commandBuffer: commandBuffer, outputTexture: outputTexture)
        commandBuffer.commit()
        textureInputSemaphore.signal()
        updateTargetsWithTexture(outputTexture)
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
}


