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
    
    func compressEmojis(_ image: UIImage, needBig: Bool = false, askedSize: CGSize? = nil) -> Data {
        if needBig {
            return image.pngData()!
        }
        var width: CGFloat = 100
        var size: CGSize?
        if let askedSize = askedSize {
            if image.size.width > askedSize.width && image.size.height > askedSize.height {
                width = askedSize.width
            } else {
                size = image.size
            }
        }
        if size == nil {
            size = CGSize(width: width, height: floor(image.size.height * (width / image.size.width)))
        }
        UIGraphicsBeginImageContextWithOptions(size!, false, 0.0)
        DispatchQueue.global().sync {
            image.draw(in: CGRect(x: 0, y: 0, width: size!.width, height: size!.height))
        }
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!.pngData()!
    }

}


