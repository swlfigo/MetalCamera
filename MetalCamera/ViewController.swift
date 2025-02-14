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
    let offsetFilter = OffsetFilter(fragmentFunctionName: "passthroughFragment")
    let faceRectangleFilter = FaceRectangleFilter(fragmentFunctionName: "passthroughFragment")
    let cropFilter = Cropfilter(fragmentFunctionName: "passthroughFragment")
    let brightnessFilter = BrightnessAdjustmentFilter(0)
    var camera : Camera!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        renderView.frame = self.view.frame

        self.view.addSubview(renderView)
        do {
            camera = try Camera(sessionPreset: .photo , location: .frontFacing)
            let topGap = (self.view.frame.height - self.view.frame.width) * UIScreen.main.nativeScale / 2 / self.view.frame.height / 2
            offsetFilter.outputFrame = CGRectMake(0, topGap, self.view.frame.width * UIScreen.main.nativeScale, self.view.frame.height * UIScreen.main.nativeScale)
            if camera.cameraPreset == .photo {
                //4:3 display on 16:9
//                camera.addTarget(offsetFilter)
//                offsetFilter.addTarget(renderView)
                
                //1:1
//                camera.addTarget(cropFilter)
//                cropFilter.cropRegion = .init(x: -1, y: 1.125, width: self.view.frame.width * UIScreen.main.nativeScale, height: self.view.frame.width * UIScreen.main.nativeScale)
//                cropFilter.addTarget(offsetFilter)
//                offsetFilter.addTarget(renderView)

                //Face Recognize
                camera.enableFaceDetect = true
                camera.addTarget(faceRectangleFilter)
                faceRectangleFilter.addTarget(brightnessFilter)
                brightnessFilter.addTarget(offsetFilter)
                offsetFilter.addTarget(renderView)

                
            }else {
                camera.addTarget(baseFilter)
                baseFilter.addTarget(renderView)
            }
            

            
            DispatchQueue.global(qos: .background).async {
                self.camera.startCapture()
            }

            
        } catch {
            fatalError("Can't Create Camera")
        }
        
        
        let valueSlider = UISlider.init(frame: .init(x: 20, y: self.view.frame.height - 100, width: self.view.frame.width - 40, height: 20))
        self.view.addSubview(valueSlider)
        valueSlider.maximumValue = 1.0
        valueSlider.minimumValue = 0.0
        valueSlider.addTarget(self, action: #selector(sliderValueChange), for: .valueChanged)
    }
    
    @objc func sliderValueChange(_ slider:UISlider) {
        brightnessFilter.brightness = slider.value
    }

}

