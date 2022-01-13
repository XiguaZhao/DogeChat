//
//  iOSCatalystCommon.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/13.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatCommonDefines

public struct ColorUtil {
    
    public static func getColorFrom(rgb: CustomizedColor.ColorRGB) -> UIColor {
        let r = CGFloat(rgb.r) / 255
        let g = CGFloat(rgb.g) / 255
        let b = CGFloat(rgb.b) / 255
        let a = CGFloat(rgb.a) / 255

        return UIColor(red: r, green: g, blue: b, alpha: a)
    }
    
    public static func getColorRGBFrom(color: UIColor) -> CustomizedColor.ColorRGB {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return .init(r: r, g: g, b: b, a: a)
    }
    
}
