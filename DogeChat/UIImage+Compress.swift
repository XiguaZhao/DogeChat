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
    try? image.jpegData(compressionQuality: 1)?.write(to: fileUrl)
    let scale = UIScreen.main.scale
    size.width *= scale
    size.height *= scale
    let image = imageFromURL(fileUrl, size: size)
    try? FileManager.default.removeItem(at: fileUrl)
    let finalURL = URL(string: "file://" + NSTemporaryDirectory() + UUID().uuidString + ".jpg")!
    try? image?.jpegData(compressionQuality: 0.3)?.write(to: finalURL)
    return (image ?? UIImage(), finalURL, size)
}

func imageFromURL(_ url: URL, size: CGSize) -> UIImage? {
    guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    let options: [NSString : Any] = [
        kCGImageSourceThumbnailMaxPixelSize: max(size.width, size.height),
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true
    ]
    guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
    return UIImage(cgImage: cgImage)
}
