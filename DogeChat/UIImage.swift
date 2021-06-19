//
//  UIImage.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/11.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal
import UIKit

public extension MessageManager {
    
    func compressEmojis(_ image: UIImage, needBig: Bool = false) -> Data {
        if needBig {
            return image.pngData()!
        }
        let width: CGFloat = 100
        let size = CGSize(width: width, height: image.size.height * (width / image.size.width))
        UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
        image.draw(in: CGRect(x: 0, y: 0, width: size.width, height: size.height))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!.pngData()!
    }

}


