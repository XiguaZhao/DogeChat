//
//  ImageLoader.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/12.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import UIKit
import DogeChatUniversal

class MediaLoader: NSObject, URLSessionDownloadDelegate {
    static let shared = MediaLoader()
    var cookie: String?
    struct ImageRequest {
        let type: MessageType
        let completionHandler: ((UIImage?, Data?, URL) -> Void)?
        let progressBlock: ((Double) -> Void)?
    }
    
    var downloadingInfos = [String: [ImageRequest]]()
    
    let lock = NSLock()
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dogechat.imageloader")
        config.httpMaximumConnectionsPerHost = 20
        config.timeoutIntervalForRequest = 600
        let sesssion = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        
        return sesssion
    }()
    
    func requestImage(urlStr: String, type: MessageType, cookie: String? = nil, syncIfCan: Bool = false, completion: ((UIImage?, Data?, URL) -> Void)? = nil, progress: ((Double) -> Void)? = nil) {
        if urlStr.isEmpty {
            return
        }
        let ip = "121.5.152.193"
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
        if let localURL = fileURLAt(dirName: dirName(for: type), fileName: fileName) {
            let block = {
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
                let requestUrl = URL(string: "https://121.5.152.193/star/fileDownload/\(url.lastPathComponent.replacingOccurrences(of: "+", with: "%2B"))")!
                var request = URLRequest(url: requestUrl)
                let _cookie = cookie ?? self.cookie
                if let cookie = _cookie, !cookie.isEmpty {
                    request.setValue("SESSION="+cookie, forHTTPHeaderField: "Cookie")
                    if downloadingInfos[fileName] != nil {
                        downloadingInfos[fileName]?.append(ImageRequest(type: type, completionHandler: completion, progressBlock: progress))
                        return
                    }
                    downloadingInfos[fileName] = [ImageRequest(type: type, completionHandler: completion, progressBlock: progress)]
                    session.downloadTask(with: request).resume()
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("下载失败")
            if let url = task.originalRequest?.url {
                let fileName = url.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
                let removed = downloadingInfos.remove(key: fileName)
                requestImage(urlStr: url.absoluteString, type: removed?.first?.type ?? .image, completion: nil, progress: nil)
                if let removed = removed {
                    downloadingInfos[fileName] = removed
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        let fileName = sourceURL.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
        guard (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0 == 200, let type = downloadingInfos[fileName]?.first?.type else  {
            downloadingInfos.removeValue(forKey: fileName)
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
        syncOnMainThread {
            self.downloadingInfos.remove(key: fileName)?.forEach( { request in
                request.completionHandler?(image, data, fileURLAt(dirName: dirName, fileName: fileName)!)
            })
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
