//
//  MetalManager.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/2.
//
import MetalKit


class MetalManager {
    
    let device : MTLDevice
    let commandQueue : MTLCommandQueue
    let shaderLibrary : MTLLibrary
    
    static let shared = MetalManager()
    
    private init() {
        
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Could not create Metal Device")
        }
        self.device = device
        
        guard let queue = self.device.makeCommandQueue() else {
            fatalError("Could not create command queue")
        }
        self.commandQueue = queue
        
        guard let defaultLibrary = device.makeDefaultLibrary() else {
            fatalError("Could not load library")
        }

        self.shaderLibrary = defaultLibrary
    }
}
