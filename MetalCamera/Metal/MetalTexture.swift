//
//  MetalTexture.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/3.
//
import MetalKit

public enum ImageOrientation {
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight

    func rotationNeeded(for targetOrientation: ImageOrientation) -> Rotation {
        switch (self, targetOrientation) {
        case (.portrait, .portrait), (.portraitUpsideDown, .portraitUpsideDown),
            (.landscapeLeft, .landscapeLeft), (.landscapeRight, .landscapeRight):
            return .noRotation
        case (.portrait, .portraitUpsideDown): return .rotate180
        case (.portraitUpsideDown, .portrait): return .rotate180
        case (.portrait, .landscapeLeft): return .rotateCounterclockwise
        case (.landscapeLeft, .portrait): return .rotateClockwise
        case (.portrait, .landscapeRight): return .rotateClockwise
        case (.landscapeRight, .portrait): return .rotateCounterclockwise
        case (.landscapeLeft, .landscapeRight): return .rotate180
        case (.landscapeRight, .landscapeLeft): return .rotate180
        case (.portraitUpsideDown, .landscapeLeft): return .rotateClockwise
        case (.landscapeLeft, .portraitUpsideDown): return .rotateCounterclockwise
        case (.portraitUpsideDown, .landscapeRight): return .rotateCounterclockwise
        case (.landscapeRight, .portraitUpsideDown): return .rotateClockwise
        }
    }
}

public enum Rotation {
    case noRotation
    case rotateCounterclockwise
    case rotateClockwise
    case rotate180
    case flipHorizontally
    case flipVertically
    case rotateClockwiseAndFlipVertically
    case rotateClockwiseAndFlipHorizontally

    func flipsDimensions() -> Bool {
        switch self {
        case .noRotation, .rotate180, .flipHorizontally, .flipVertically: return false
        case .rotateCounterclockwise, .rotateClockwise, .rotateClockwiseAndFlipVertically,
            .rotateClockwiseAndFlipHorizontally:
            return true
        }
    }
}


class MetalTexture {
    public var orientation: ImageOrientation

    public let texture: MTLTexture
    
    init(orientation: ImageOrientation, texture: MTLTexture) {
        self.orientation = orientation
        self.texture = texture
    }
}

extension MetalTexture {
    func textureCoordinates(for outputOrientation: ImageOrientation, normalized: Bool) -> [Float] {
        let inputRotation = self.orientation.rotationNeeded(for: outputOrientation)
        
        let xLimit: Float
        let yLimit: Float
        if normalized {
            xLimit = 1.0
            yLimit = 1.0
        } else {
            xLimit = Float(self.texture.width)
            yLimit = Float(self.texture.height)
        }
        
        switch inputRotation {
        case .noRotation: return [0.0, 0.0, xLimit, 0.0, 0.0, yLimit, xLimit, yLimit]
        case .rotateCounterclockwise: return [0.0, yLimit, 0.0, 0.0, xLimit, yLimit, xLimit, 0.0]
        case .rotateClockwise: return [xLimit, 0.0, xLimit, yLimit, 0.0, 0.0, 0.0, yLimit]
        case .rotate180: return [xLimit, yLimit, 0.0, yLimit, xLimit, 0.0, 0.0, 0.0]
        case .flipHorizontally: return [xLimit, 0.0, 0.0, 0.0, xLimit, yLimit, 0.0, yLimit]
        case .flipVertically: return [0.0, yLimit, xLimit, yLimit, 0.0, 0.0, xLimit, 0.0]
        case .rotateClockwiseAndFlipVertically:
            return [0.0, 0.0, 0.0, yLimit, xLimit, 0.0, xLimit, yLimit]
        case .rotateClockwiseAndFlipHorizontally:
            return [xLimit, yLimit, xLimit, 0.0, 0.0, yLimit, 0.0, 0.0]
        }
    }
    
}
