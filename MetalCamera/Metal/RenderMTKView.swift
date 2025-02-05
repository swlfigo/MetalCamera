//
//  RenderMTKView.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/4.
//

import MetalKit

class RenderMTKView :  MTKView {
    var currentTexture : MetalTexture?
    var renderPipelineState : MTLRenderPipelineState!
    
    public override init(frame frameRect: CGRect, device: MTLDevice?) {
        super.init(frame: frameRect, device: device != nil ? device : MetalManager.shared.device)
        commitInit()
    }
    
    required init(coder: NSCoder) {
        super.init(coder: coder)
        commitInit()
    }
    
    private func commitInit(){
        framebufferOnly = false
        autoResizeDrawable = true
        guard let vertexFunction = MetalManager.shared.shaderLibrary.makeFunction(name: "oneInputVertex") else {
            fatalError("Can't Read VertexFunction")
        }
        guard let fragmentFunction = MetalManager.shared.shaderLibrary.makeFunction(name: "passthroughFragment") else {
            fatalError("Can't Read FragmentFunction")
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.colorAttachments[0].pixelFormat = MTLPixelFormat.bgra8Unorm
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        do {
            self.renderPipelineState = try MetalManager.shared.device.makeRenderPipelineState(descriptor: descriptor)
        } catch  {
            fatalError("Can't create renderPipelineState")
        }
        /*
         MTKView 支持三种绘制模式：


         定时更新：视图根据内部计时器重绘其内容。默认情况下使用这个绘制方式，初始化时需要将 isPaused 和 enableSetNeedsDisplay 都设置为 false。游戏和更新的动画内容常用这种模式。


         绘制通知：当调用 setNeedsDisplay() 或者 当某些内容使其内容无效时，视图会重绘自身。在这种情况下，将 isPaused 和 enableSetNeedsDisplay 设置为 true。这种模式适用于具有更传统工作流程的应用程序，更新只会在数据更改时发生，而不会定期更新。


         显式绘制：当显式调用 draw() 方法时，视图才会重绘其内容。这种模式下，需要将 isPaused 设置为 true 并将 enableSetNeedsDisplay 设置为 false。一般使用此模式来创建自定义工作流程。

         
         */
        enableSetNeedsDisplay = false
        isPaused = true
    }
    
}

extension RenderMTKView : Consumer  {
    func newTextureAvailable(_ texture: MetalTexture) {
        self.drawableSize = CGSize(width: texture.texture.width, height: texture.texture.height)
        currentTexture = texture
        self.draw()
    }
    
    
    override func draw(_ rect: CGRect) {
        if let currentDrawable = self.currentDrawable , let imageTexture = self.currentTexture {
            let commandBuffer = MetalManager.shared.commandQueue.makeCommandBuffer()
            //对于最后一个consumer来说，没有下一层consumer，这个texture没什么作用
            let outputTexture = MetalTexture(orientation: .portrait, texture: currentDrawable.texture)
            commandBuffer?.renderQuad(
                pipelineState: renderPipelineState, inputTextures: [0: imageTexture],
                outputTexture: outputTexture)
            commandBuffer?.present(currentDrawable)
            commandBuffer?.commit()
        }
    }
}
