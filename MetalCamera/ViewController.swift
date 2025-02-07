//
//  ViewController.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/2.
//

import UIKit

class ViewController: UIViewController {

    let renderView = RenderMTKView()
    let baseFilter = BaseFilter(fragmentFunctionName: "passthroughFragment")
    var camera : Camera!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        renderView.frame = self.view.frame
        self.view.addSubview(renderView)
        do {
            camera = try Camera(sessionPreset: .high , location: .frontFacing)
            camera.addTarget(baseFilter)
            baseFilter.addTarget(renderView)
            self.camera.startCapture()

            
        } catch {
            fatalError("Can't Create Camera")
        }
    }


}

