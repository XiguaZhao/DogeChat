//
//  UIImage+Compress.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/31.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import UIKit

func compressImage(_ image: UIImage, needSave: Bool = true, saveMemory: Bool = false) -> (image: UIImage, fileUrl: URL, size: CGSize) {
    var size = image.size
    let ratio = size.width / size.height
    var width: CGFloat = min(image.size.width, UIScreen.main.bounds.width)
    width = min(1000, width)
    let height = floor(width / ratio)
    size = CGSize(width: width, height: height)
    let fileUrl = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".jpg")!
    let scale = UIScreen.main.scale
    size.width *= scale
    size.height *= scale
    let image = imageFromData(image.jpegData(compressionQuality: 0.5), size: size)
    try? FileManager.default.removeItem(at: fileUrl)
    try? image?.jpegData(compressionQuality: 0.3)?.write(to: fileUrl)
    return (image ?? UIImage(), fileUrl, size)
}

func imageFromData(_ data: Data?, size: CGSize, url: URL? = nil) -> UIImage? {
    var source: CGImageSource?
    if let data = data, let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
        source = imageSource
    } else if let url = url, let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) {
        source = imageSource
    }
    guard let imageSource = source else { return nil }
    let options: [NSString : Any] = [
        kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    let count = CGImageSourceGetCount(imageSource)
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, count/2, options as CFDictionary) else { return nil }
    return UIImage(cgImage: cgImage)
}
