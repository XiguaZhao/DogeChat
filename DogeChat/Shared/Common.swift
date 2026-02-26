//
//  Common.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/25.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import CoreGraphics
import DogeChatCommonDefines

let videoIdentifier = "public.movie"
let gifIdentifier = "com.compuserve.gif"
let fileIdentifier = "public.file-url"
let audioIdentifier = "public.audio"

let livePhotoDir = "livephotos"
let videoDir = "videos"
let voiceDir = "voice"
let drawDir = "draws"
let pasteDir = "paste"
let photoDir = "photos"
let contactsDir = "contacts"
let audioDir = "audios"

let maxTextHeight: CGFloat = CGFloat.greatestFiniteMagnitude
let tableViewCellTopBottomPadding: CGFloat = 5
let maxFontSize: CGFloat = 60


let debugUsers = ["赵锡光", "username2", "username",
                  "Pino", "靓仔2号", "靓仔三号", "西瓜",
                  "仙城最靓的仔", "最强王者", "冰淇淋",
                  "🐷🐷", "菠萝包"]


public func syncOnMainThread(block: () -> Void) {
    if Thread.isMainThread {
        block()
    } else {
        DispatchQueue.main.sync {
            block()
        }
    }
}


extension String {
    var fileURL: URL {
        return URL(fileURLWithPath: self)
    }
    
    func documentURLWithDir(_ dirName: Self) -> URL {
        let url = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first!.fileURL.appendingPathComponent(dirName).appendingPathComponent(self)
        return url
    }
    
    var fileName: String {
        return URL(string: self)?.lastPathComponent.replacingOccurrences(of: "%2B", with: "+") ?? ""
    }
    
    func fileNameWithWidth(_ width: ImageWidth) -> String {
        let fileName = self.fileName
        return "\(width.rawValue)-" + fileName
    }
    
    var isGif: Bool {
        self.hasSuffix(".gif")
    }
    
    var isVideo: Bool {
        let lowerCased = self.lowercased()
        return lowerCased.hasSuffix(".mov") || lowerCased.hasSuffix(".mp4")
    }
    
    var isImage: Bool {
        let lowerCased = self.lowercased()
        return lowerCased.hasSuffix(".jpeg") || lowerCased.hasSuffix(".jpg") || lowerCased.hasSuffix(".png")
    }
    
    var isWebURL: Bool {
        self.webUrlify() != nil
    }
    
    func webUrlify() -> String? {
        if var res = self.webUrlifyWithountChange()?.str {
            if !res.hasPrefix("http") {
                res = "https://" + res
            }
            return res
        }
        return nil
    }
    
    func webUrlifyWithountChange() -> (str: String, range: NSRange)? {
        if let dataDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            if let match = dataDetector.matches(in: self, options: [], range: NSRange(location: 0, length: self.utf16.count)).first, let range = Range(match.range, in: self) {
                let res = String(self[range])
                return (res, NSRange.init(range, in: self))
            }
        }
        return nil
    }
        
    func getRange() -> NSRange? {
        let params = getParams()
        if let location = Int(params["location"] ?? ""),
           let length = Int(params["length"] ?? "") {
            return NSRange(location: location, length: length)
        }
        return nil
    }
    
    func toNSRange(_ range: Range<String.Index>) -> NSRange {
        guard let from = range.lowerBound.samePosition(in: self.utf16),
              let to = range.upperBound.samePosition(in: self.utf16) else {
                  return NSRange(location: 0, length: 0)
              }
        return NSMakeRange(utf16.distance(from: utf16.startIndex, to: from), utf16.distance(from: from, to: to))
    }

}

enum ImageWidth: CGFloat {
    case width40  = 40
    case width80  = 80
    case width100 = 100
    case width200 = 200
    case width300 = 300
    case width400 = 400
    case original
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
    
    public func isTransparent() -> Bool {
      guard let alpha: CGImageAlphaInfo = self.cgImage?.alphaInfo else { return false }
      return alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast
    }
}

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: minX + width / 2, y: minY + height / 2)
    }
}

extension Dictionary where Key == String {
    
    @discardableResult mutating func remove(key: String) -> Value? {
        if let index = self.index(forKey: key) {
            return self.remove(at: index).value
        } else {
            return nil
        }
    }
    
}

func compressEmojis(_ image: UIImage, imageWidth: ImageWidth = .width100, isGIF: Bool = false, data: Data? = nil, scale: CGFloat? = nil) -> (UIImage, Data) {
    if imageWidth == .original {
        return (image, image.jpegData(compressionQuality: 0.3) ?? Data())
    }
    let width = imageWidth.rawValue
    var size = CGSize(width: width, height: floor(image.size.height * (width / image.size.width)))
    if image.size.width < width {
        size = image.size
    }
    let rect = CGRect(origin: .zero, size: size)
    var res: UIImage?
    UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
    image.draw(in: rect)
    res = UIGraphicsGetImageFromCurrentImageContext()
    UIGraphicsEndImageContext()
    return (res ?? UIImage(), res?.jpegData(compressionQuality: 0.3) ?? Data())
}


func boundsForDraw(_ message: Message) -> CGRect? {
    if let str = message.pkDataURL {
        var components = str.components(separatedBy: "+")
        if components.count >= 4 {
            let height = Int(components.removeLast())!
            let width = Int(components.removeLast())!
            let y = Int(components.removeLast())!
            let x = Int(components.removeLast())!
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }
    return nil
}

func sizeForImageOrVideo(_ message: Message) -> CGSize? {
    if message.imageSize != .zero {
        return message.imageSize
    }
    var _str: String?
    if message.imageURL != nil {
        _str = message.imageURL
    } else if message.videoURL != nil {
        _str = message.videoURL
    }
    guard let str = _str else { return nil }
    return sizeFromStr(str)
}

func sizeFromStr(_ str: String, preferWidth: Bool? = true, length: CGFloat? = nil) -> CGSize? {
    let originalStr = str
    var str = str as NSString
    str = str.replacingOccurrences(of: ".jpeg", with: "") as NSString
    str = str.replacingOccurrences(of: ".gif", with: "") as NSString
    str = str.replacingOccurrences(of: ".mov", with: "") as NSString
    var components = str.components(separatedBy: "+")
    if components.count >= 2, let height = Int(components.removeLast()), let width = Int(components.removeLast()) {
        if preferWidth ?? false {
            if let length = length {
                return CGSize(width: length, height: length * CGFloat(height) / CGFloat(width))
            } else {
                return CGSize(width: width, height: height)
            }
        } else {
            if let length = length {
                return CGSize(width: length * CGFloat(width) / CGFloat(height), height: length)
            } else {
                return CGSize(width: width, height: height)
            }
        }
    }
    if let components = URLComponents(string: originalStr)?.queryItems {
        var width: CGFloat?
        var height: CGFloat?
        for component in components {
            if component.name == "width", let value = component.value {
                width = (value as NSString).doubleValue
            }
            if component.name == "height", let value = component.value {
                height = (value as NSString).doubleValue
            }
        }
        if let width = width, let height = height, width > 0, height > 0 {
            return CGSize(width: width, height: height)
        }
    }
    
    return nil
}

public func getTimestampFromStr(_ str: String) -> TimeInterval {
    let dfmatter = DateFormatter()
    dfmatter.dateFormat="yyyy-MM-dd HH:mm:ss"
    let date = dfmatter.date(from: str)
    
    let dateStamp = date?.timeIntervalSince1970
    return dateStamp ?? 0
}

public func dirNameForType(_ type: MessageType) -> String {
    switch type {
    case .sticker:
        return photoDir
    case .video:
        return videoDir
    case .livePhoto:
        return livePhotoDir
    case .draw:
        return drawDir
    case .voice:
        return audioDir
    default: return ""
    }
}
