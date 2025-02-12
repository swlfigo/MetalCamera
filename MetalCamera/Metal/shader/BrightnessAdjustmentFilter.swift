//
//  BrightnessAdjustmentFilter.swift
//  MetalCamera
//
//  Created by sylar on 2025/2/12.
//

import Foundation


class BrightnessAdjustmentFilter : BaseFilter {
    public var brightness: Float = 0.0 { didSet { uniformSettings["brightness"] = brightness } }

    public init(_ bright:Float)  {
        super.init(fragmentFunctionName: "brightnessFragment", numberOfInputs: 1)

        ({ brightness = bright })()
    }
}
