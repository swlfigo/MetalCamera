//
//  Cropfilter.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/9.
//

import Foundation

import Metal

class Cropfilter : BaseFilter {
    
    /*
     关于裁剪的顶点坐标:
        1. 顶点坐标的设置是将该需要裁剪的纹理绘制在输出画布纹理上时的位置,并不是相对于当前输入纹理计算好的相对点裁剪,刚开始容易混淆概念
        2. 裁剪意思是将需要裁剪的纹理平铺在输出纹理上后，超过输出纹理边缘的地方不显示裁掉意思,除了通过顶点坐标来做这个裁剪功能，也可以通过修改纹理坐标实现,二选一实现即可;GPUImage1中也是对顶点坐标做操作
     
     (x,y)
     {~~~~~~~~~~}
     {          }
     |__________|
     |          |
     |          |
     |          |
     |__________|
     {          }
     {~~~~~~~~~~}
     
     如上图表示,框表示为输出纹理的大小,花括号波浪线和框表示当前纹理大小，目标是将当前纹理裁剪成框大小的纹理输出到下一级显示
     核心思想就是通过计算调整(x,y),使大的纹理在框体中移动，达到裁剪效果
     */
    
    //将输入纹理画到输出纹理上,rect的4个参数为对应的输入纹理在输出纹理的相对位置
    //如4:3的视频帧裁剪成1:1的输出纹理上
    //以1440 1080 -> 1080 1080为例
    //输出的纹理为1080
    //1440 1080的纹理平铺在输出纹理上,要达到1:1的尺寸
    //则上下需要裁掉 (1440 - 1080) / 2 = 180的长度
    //换算成输出纹理的百分比表示则为 180 / 1440 = 0.125
    //顶点坐标的范围为-1~1 ,超出部分为需要裁掉部分
    //(left,top,cropWidth,cropHeight)
    //则cropRegion的输入应该为(-1,1.125,1080,1440)
    var cropRegion : CGRect = .zero

    
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
        

        if cropRegion.equalTo(.zero) {
            fatalError("Should Set CropRegion First")
        }
        
        inputTextures[0] = texture
        
        
        
        let outputTexture = MetalTexture(
            orientation: .portrait,
            width: Int(cropRegion.width), height: Int(cropRegion.height)
        )
       
        //计算相对坐标
        let firstInputTexture = inputTextures[0]!
        var contentSizeWidth : Float = Float(firstInputTexture.texture.width)
        var contentSizeHeight : Float = Float(firstInputTexture.texture.height)
        if firstInputTexture.orientation.rotationNeeded(for: .portrait).flipsDimensions() {
            contentSizeWidth = Float(firstInputTexture.texture.height)
            contentSizeHeight = Float(firstInputTexture.texture.width)
        }
        

        let left = Float(cropRegion.origin.x)
        let right = left + Float(contentSizeWidth) / Float(cropRegion.width) * 2
        let top = Float(cropRegion.origin.y)
        let bottom = top - (Float(contentSizeHeight) / contentSizeHeight ) * 2

                                                                     
        cropVertext = [left,top,right,top,left,bottom,right,bottom]
        
        
        internalRenderFunction(commandBuffer: commandBuffer, outputTexture: outputTexture)
        commandBuffer.commit()
        textureInputSemaphore.signal()
        updateTargetsWithTexture(outputTexture)
        let _ = textureInputSemaphore.wait(timeout: DispatchTime.distantFuture)
    }
}
