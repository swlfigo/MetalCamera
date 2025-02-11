//
//  Pipeline.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/3.
//
import Foundation

protocol Producer {
    var targets : TargetContainer {get}
}

extension Producer {
    func addTarget(_ target:Consumer){
        targets.append(target)
    }
    
    func updateTargetsWithParams(_ params:[String:Any] = [:]) {
        targets.targets.forEach { weakConsumer in
            weakConsumer.value?.newInputParamsAvailable(params)
        }
    }
    
    func updateTargetsWithTexture(_ texture: MetalTexture) {
        targets.targets.forEach { weakConsumer in
            weakConsumer.value?.newTextureAvailable(texture)
        }
    }
}


protocol Consumer : AnyObject {
    
    var inputParams : [String:Any] {get}
    
    func newInputParamsAvailable(_ inputParams: [String:Any])
    
    func newTextureAvailable(_ texture: MetalTexture)
}


class TargetContainer {
    var targets = [WeakConsumer]()
    var count : Int {return targets.count}
    let queue = DispatchQueue(label:"Target Container Queue")
    
    func append(_ target: Consumer) {
        
        queue.async {
            self.targets.append(WeakConsumer(value: target))
        }
    }
    
    func removeAll() {
        queue.async {
            self.targets.removeAll()
        }
    }
}

class WeakConsumer {
    weak var value : Consumer?
    init(value: Consumer? = nil) {
        self.value = value
    }
}
