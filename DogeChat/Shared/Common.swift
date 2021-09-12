//
//  Common.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/25.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

let livePhotoDir = "livephotos"
let videoDir = "videos"
let voiceDir = "voice"
let drawDir = "draws"
let pasteDir = "paste"

var maxID: Int {
    (UserDefaults.standard.value(forKey: "maxID") as? Int) ?? 0
}

public func syncOnMainThread(block: () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.sync {
            block()
        }
    }
}

public func fileURLAt(dirName: String, fileName: String) -> URL? {
    let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        .appendingPathComponent(dirName)
        .appendingPathComponent(fileName)
    let path = (url.absoluteString as NSString).substring(from: 7)
    if FileManager.default.fileExists(atPath: path) {
        return url
    } else {
        return nil
    }
}

public func saveFileToDisk(dirName: String, fileName: String, data: Data) {
    let folderName = dirName
    let fileManager = FileManager.default
    let documentsFolder = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let folderURL = documentsFolder.appendingPathComponent(folderName)
    let folderExists = (try? folderURL.checkResourceIsReachable()) ?? false
    do {
        if !folderExists {
            try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: false)
        }
        let fileURL = folderURL.appendingPathComponent(fileName)
        try data.write(to: fileURL)
        
    } catch {
        print(error)
    }
}

public func deleteFile(dirName: String, fileName: String) {
    let folderName = dirName
    let fileManager = FileManager.default
    let documentsFolder = try! fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
    let folderURL = documentsFolder.appendingPathComponent(folderName)
    let fileURL = folderURL.appendingPathComponent(fileName)
    try? fileManager.removeItem(at: fileURL)
}

extension String {
    var fileURL: URL {
        return URL(fileURLWithPath: self)
    }
    
    func documentURLWithDir(_ dirName: Self) -> URL {
        let url = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.fileURL.appendingPathComponent(dirName).appendingPathComponent(self)
        return url
    }
    
}

extension URL {
    var filePath: String {
        return self.absoluteString.replacingOccurrences(of: "file://", with: "")
    }
}

extension UIImage {
    func circle(width: CGFloat) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: width), false, 0)
        let context = UIGraphicsGetCurrentContext()
        let rect = CGRect(x: 0, y: 0, width: width, height: width)
        context?.addEllipse(in: rect)
        context?.clip()
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: width))
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? self
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: minX + width / 2, y: minY + height / 2)
    }
}

extension Dictionary where Key == String {
    
    mutating func remove(key: String) -> Value? {
        if let index = self.index(forKey: key) {
            return self.remove(at: index).value
        } else {
            return nil
        }
    }
    
}

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
