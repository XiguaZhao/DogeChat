//
//  ImageLoader.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/12.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import UIKit
import DogeChatCommonDefines

class MediaLoader: NSObject, URLSessionDownloadDelegate {
    
    enum URLSessionType {
        case defaultSession
        case background
    }
    static let shared = MediaLoader()
    var cookie: String?
    var type: URLSessionType = .background
    struct ImageRequest {
        let type: MessageType
        let imageWidth: ImageWidth
        let needStaticGif: Bool
        let onlyDataWhenImage: Bool
        let completionHandler: ((UIImage?, Data?, URL) -> Void)?
        let progressBlock: ((Double) -> Void)?
    }
    
    var downloadingInfos = [String: [ImageRequest]]()
    
    var cache = [String : Data]()
    var cacheSize = [String : Int]()
    let lock = NSLock()
    lazy var session: URLSession = {
        let config: URLSessionConfiguration
        if self.type == .background {
            config = URLSessionConfiguration.background(withIdentifier: "com.dogechat.imageloader")
        } else {
            config = .default
        }
        config.httpMaximumConnectionsPerHost = 20
        config.timeoutIntervalForRequest = 600
        let sesssion = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        return sesssion
    }()
    
    func checkIfShouldRemoveCache() {
        DispatchQueue.main.async {
            let size = self.cacheSize.values.reduce(0, +)
            if size / 1024 / 1024 > 50 {
                let average = size / self.cache.count
                for (cacheKey, size) in self.cacheSize {
                    if size > average {
                        self.cache.removeValue(forKey: cacheKey)
                        self.cacheSize.removeValue(forKey: cacheKey)
                    }
                }
            }
        }
    }
    

    func requestImage(urlStr: String, type: MessageType, cookie: String? = nil, syncIfCan: Bool = false, imageWidth: ImageWidth = .width100, needStaticGif: Bool = false, needCache: Bool = true, onlyDataWhenImage: Bool = false, completion: ((UIImage?, Data?, URL) -> Void)? = nil, progress: ((Double) -> Void)? = nil) {
        syncOnMainThread {
            if urlStr.isEmpty {
                return
            }
            let imageWidth: ImageWidth = needStaticGif ? imageWidth : (urlStr.isGif ? .original : imageWidth)
            let ip = dogeChatIP
            var newURLStr = urlStr
            newURLStr = newURLStr.replacingOccurrences(of: "procwq.top", with: ip)
            if !newURLStr.contains(ip) && !newURLStr.hasPrefix("https://") {
                newURLStr.insert(contentsOf: "https://\(ip)", at: newURLStr.startIndex)
            }
            guard let url = URL(string: newURLStr) else { return }
            var fileName = url.lastPathComponent
            if fileName.isEmpty {
                return
            }
            fileName = fileName.replacingOccurrences(of: "%2B", with: "+")
            let cacheKey = fileName.fileNameWithWidth(imageWidth)
            if let data = cache[cacheKey] {
                syncOnMainThread {
                    completion?(nil, data, fileURLAt(dirName: photoDir, fileName: fileName) ?? url)
                }
                return
            }
            if let localURL = fileURLAt(dirName: dirName(for: type), fileName: fileName) {
                let block: () -> Void = {
                    var data: Data?
                    var image: UIImage?
                    if type == .image {
                        data = try? Data(contentsOf: localURL)
                        if let data = data {
                            self.lock.lock()
                            image = UIImage(data: data)
                            self.lock.unlock()
                        }
                        if image == nil, let localURL = fileURLAt(dirName: photoDir, fileName: fileName) {
                            try? FileManager.default.removeItem(at: localURL)
                            self.requestImage(urlStr: urlStr, type: type, cookie: cookie, syncIfCan: syncIfCan, completion: completion, progress: progress)
                            return
                        }
                        if let image = image {
                            if imageWidth != .original {
                                data = compressEmojis(image, imageWidth: imageWidth)
                            }
                            if needCache {
                                DispatchQueue.main.async {
                                    if let data = data {
                                        self.cache[cacheKey] = data
                                        self.cacheSize[cacheKey] = data.count
                                    }
                                }
                            }
                        }
                    }
                    syncOnMainThread {
                        completion?(image, data, localURL)
                    }
                }
                if syncIfCan {
                    block()
                } else {
                    DispatchQueue.global(qos: .userInteractive).async {
                        block()
                    }
                }
                return
            } else {
                syncOnMainThread {
                    let requestUrl = URL(string: "https://\(dogeChatIP)/star/fileDownload/\(url.lastPathComponent.replacingOccurrences(of: "+", with: "%2B"))")!
                    var request = URLRequest(url: requestUrl)
                    let _cookie = cookie ?? self.cookie
                    if let cookie = _cookie, !cookie.isEmpty {
                        request.setValue("SESSION="+cookie, forHTTPHeaderField: "Cookie")
                        if downloadingInfos[fileName] != nil {
                            downloadingInfos[fileName]?.append(ImageRequest(type: type, imageWidth: imageWidth, needStaticGif: needStaticGif, onlyDataWhenImage: onlyDataWhenImage, completionHandler: completion, progressBlock: progress))
                            return
                        }
                        downloadingInfos[fileName] = [ImageRequest(type: type, imageWidth: imageWidth, needStaticGif: needStaticGif, onlyDataWhenImage: onlyDataWhenImage, completionHandler: completion, progressBlock: progress)]
                        DispatchQueue.global().async {
                            self.session.downloadTask(with: request).resume()
                        }
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("下载失败")
            if let url = task.originalRequest?.url {
                let fileName = url.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
                DispatchQueue.main.async {
                    self.downloadingInfos.remove(key: fileName)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        let fileName = sourceURL.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
        var type: MessageType?
        syncOnMainThread {
            type = downloadingInfos[fileName]?.first?.type
        }
        guard (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0 == 200, let type = type else  {
            DispatchQueue.main.async {
                self.downloadingInfos.removeValue(forKey: fileName)
            }
            return
        }
        var data: Data!
        var image: UIImage?
        if type == .image {
            if let _data = try? Data(contentsOf: location) {
                data = _data
                image = UIImage(data: data)
            }
        }
        let dirName = self.dirName(for: type)
        let destination = createDir(name: dirName).appendingPathComponent(fileName)
        try? FileManager.default.moveItem(at: location, to: destination)
        let localURL = fileURLAt(dirName: dirName, fileName: fileName)
        DispatchQueue.main.async { [self] in
            if let requests = self.downloadingInfos.remove(key: fileName) {
                for request in requests {
                    if request.type != .image {
                        request.completionHandler?(image, data, localURL!)
                    } else {
                        var data = data
                        let cacheKey = fileName.fileNameWithWidth(request.imageWidth)
                        if let cached = cache[cacheKey] {
                            data = cached
                            request.completionHandler?(image, data, localURL!)
                        } else {
                            DispatchQueue.global().async {
                                if let image = image, !request.onlyDataWhenImage {
                                    if (fileName.isGif && request.needStaticGif) || !fileName.isGif {
                                        data = compressEmojis(image, imageWidth: request.imageWidth, isGIF: fileName.isGif)
                                    }
                                }
                                DispatchQueue.main.async {
                                    if let data = data {
                                        cache[cacheKey] = data
                                        cacheSize[cacheKey] = data.count
                                    }
                                    request.completionHandler?(image, data, localURL!)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        let fileName = sourceURL.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
        syncOnMainThread {
            downloadingInfos[fileName]?.forEach( {
                $0.progressBlock?(progress)
            })
        }
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        NotificationCenter.default.post(name: .backgroundSessionFinish, object: session)
    }
    
    func dirName(for type: MessageType) -> String {
        let dirName: String
        if type == .voice {
            dirName = voiceDir
        } else if type == .video {
            dirName = videoDir
        } else if type == .livePhoto {
            dirName = livePhotoDir
        } else if type == .draw {
            dirName = drawDir
        } else {
            dirName = photoDir
        }
        return dirName
    }
}
