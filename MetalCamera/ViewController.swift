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
    let cropFilter = CropFilter(fragmentFunctionName: "passthroughFragment")

    var camera : Camera!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        renderView.frame = self.view.frame

        self.view.addSubview(renderView)
        do {
            camera = try Camera(sessionPreset: .photo , location: .frontFacing)
            
            if camera.cameraPreset == .photo {
                camera.addTarget(cropFilter)
                cropFilter.outputFrame = CGRectMake(0, 0.125, 1080, 1920)
                cropFilter.addTarget(renderView)
            }else {
                camera.addTarget(baseFilter)
                baseFilter.addTarget(renderView)
            }
            

            

            self.camera.startCapture()

            
        } catch {
            fatalError("Can't Create Camera")
        }
    }


}

