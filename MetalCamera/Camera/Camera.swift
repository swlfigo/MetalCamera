//
//  Camera.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/3.
//

import Foundation
import AVFoundation
import Vision


let FaceLandmarkKey = "FaceLandmarkKey"
let CameraPhysicalPositionKey = "CameraPhysicalPositionKey"

public enum PhysicalCameraLocation {
    case backFacing
    case frontFacing
    
    func imageOrientation() -> ImageOrientation {
        switch self {
        case .backFacing: return .landscapeRight
#if os(iOS)
        case .frontFacing: return .landscapeLeft
#else
        case .frontFacing: return .portrait
#endif
        }
    }
    
    func captureDevicePosition() -> AVCaptureDevice.Position {
        switch self {
        case .backFacing: return .back
        case .frontFacing: return .front
        }
    }
    
}


class Camera : NSObject , Producer{
    let targets =  TargetContainer()
    var location: PhysicalCameraLocation
    
    var enableFaceDetect = false
    
    let captureSession: AVCaptureSession
    let inputCamera: AVCaptureDevice!
    let videoInput : AVCaptureDeviceInput!
    let videoOutput: AVCaptureVideoDataOutput!
    var videoTextureCache: CVMetalTextureCache?
    
    var faceLandmark : [CGRect] = []
    
    let frameRenderingSemaphore = DispatchSemaphore(value: 1)
    let cameraProcessingQueue = DispatchQueue.global()
    let cameraFrameProcessingQueue = DispatchQueue(
        label: "cameraFrameProcessingQueue",
        attributes: [])
    
    var cameraPreset : AVCaptureSession.Preset{
        get {
            captureSession.sessionPreset
        }
    }
    
    init(sessionPreset: AVCaptureSession.Preset , location: PhysicalCameraLocation = .backFacing) throws{
        self.location = location
        self.captureSession = AVCaptureSession()
        self.captureSession.beginConfiguration()
        self.inputCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: (location == .backFacing) ? .back:.front)
        do {
            self.videoInput = try AVCaptureDeviceInput(device: inputCamera)
        }catch {
            fatalError("Can not Create Camera")
        }
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }else {
            fatalError("Can not add videoInput")
        }
        // Add the video frame output
        videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = false
        //Not Capture with YUV
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: NSNumber(
                value: Int32(kCVPixelFormatType_32BGRA)),
        ]
        
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }else {
            fatalError("Can not add videoOutput")
        }
        
        captureSession.sessionPreset = sessionPreset
        captureSession.commitConfiguration()
        
        super.init()
        
        let _ = CVMetalTextureCacheCreate(
            kCFAllocatorDefault, nil, MetalManager.shared.device, nil, &videoTextureCache)
        
        videoOutput.setSampleBufferDelegate(self, queue: cameraProcessingQueue)
    }
    
    deinit {
        cameraFrameProcessingQueue.sync {
            self.stopCapture()
            self.videoOutput?.setSampleBufferDelegate(nil, queue: nil)
        }
    }
    
    func startCapture() {
        
        let _ = frameRenderingSemaphore.wait(timeout: DispatchTime.distantFuture)
        self.frameRenderingSemaphore.signal()
        
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }
    
    func stopCapture() {
        if captureSession.isRunning {
            let _ = frameRenderingSemaphore.wait(timeout: DispatchTime.distantFuture)
            captureSession.stopRunning()
            self.frameRenderingSemaphore.signal()
        }
    }
}


extension Camera : AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard
            frameRenderingSemaphore.wait(timeout: DispatchTime.now())
                == DispatchTimeoutResult.success
        else { return }
        
        let cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer)!
        let bufferWidth = CVPixelBufferGetWidth(cameraFrame)
        let bufferHeight = CVPixelBufferGetHeight(cameraFrame)

        CVPixelBufferLockBaseAddress(
            cameraFrame, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
        
        cameraFrameProcessingQueue.async {[weak self] in
            guard let self = self else { return }
            CVPixelBufferUnlockBaseAddress(
                cameraFrame, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
            
            var texture : MetalTexture?
            var textureRef: CVMetalTexture? = nil
            let _ = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, self.videoTextureCache!, cameraFrame, nil, .bgra8Unorm,
                bufferWidth, bufferHeight, 0, &textureRef)
            if let concreteTexture = textureRef,
               let cameraTexture = CVMetalTextureGetTexture(concreteTexture) {
                texture = MetalTexture(
                    orientation:  self.location.imageOrientation(),
                    texture: cameraTexture
                )
            }
            if enableFaceDetect {
                self.detectFace(in: cameraFrame)
            }
//            let startTime = CFAbsoluteTimeGetCurrent()
            self.updateTargetsWithParams([FaceLandmarkKey:self.faceLandmark , CameraPhysicalPositionKey : location])
            if let t = texture {
                self.updateTargetsWithTexture(t)
            }
            //Test Filter Chain Time
//            let currentFrameTime = (CFAbsoluteTimeGetCurrent() - startTime)
//            print(currentFrameTime)
            
            
            self.frameRenderingSemaphore.signal()
        }
    }
}

extension Camera {
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest { [weak self] request, error in
            guard let self = self else { return }
            guard error == nil else {
                print("人脸检测错误: \(error!.localizedDescription)")
                return
            }
            
            self.handleFaceDetectionResults(request.results as? [VNFaceObservation] ?? [])
        }
        
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: location == .frontFacing ? .leftMirrored : .rightMirrored)
        
        do {
            try imageRequestHandler.perform([faceDetectionRequest])
        } catch let e {
            print("Error:\(e)")
        }
    }
    
    private func handleFaceDetectionResults(_ results: [VNFaceObservation]) {
        faceLandmark = []
        for faceObservation in results {
            
            faceLandmark.append(faceObservation.boundingBox)
            // 如果有面部特征点，绘制关键点
            if let landmarks = faceObservation.landmarks {
//                print("""
//                LeftEye:\(String(describing: landmarks.leftEye?.normalizedPoints))
//                RightEye:\(String(describing: landmarks.rightEye?.normalizedPoints))
//
// """)
//                landmarks.leftEye?.normalizedPoints,
//                          landmarks.rightEye?.normalizedPoints,
//                          landmarks.leftEyebrow?.normalizedPoints,
//                          landmarks.rightEyebrow?.normalizedPoints,
//                          landmarks.nose?.normalizedPoints,
//                          landmarks.outerLips?.normalizedPoints,
//                          landmarks.innerLips?.normalizedPoints
            }
        }
    }
}
