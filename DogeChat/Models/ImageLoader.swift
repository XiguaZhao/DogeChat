//
//  ImageLoader.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/12.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import UIKit

class ImageLoader: NSObject, URLSessionDownloadDelegate {
    static let shared = ImageLoader()
    var cookie: String?
    struct ImageRequest {
        let completionHandler: ((UIImage?, Data, URL) -> Void)?
        let progressBlock: ((Double) -> Void)?
    }
    
    var downloadingInfos = [String: [ImageRequest]]()
    
    let lock = NSLock()
    
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.dogechat.imageloader")
        config.httpMaximumConnectionsPerHost = 20
        config.timeoutIntervalForRequest = 600
        let sesssion = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        
        return sesssion
    }()
    
    func requestImage(urlStr: String, syncIfCan: Bool = false, completion: ((UIImage?, Data, URL) -> Void)? = nil, progress: ((Double) -> Void)? = nil) {
        let ip = "121.5.152.193"
        var newURLStr = urlStr
        newURLStr = newURLStr.replacingOccurrences(of: "procwq.top", with: ip)
        if !newURLStr.contains(ip) && !newURLStr.hasPrefix("https://") {
            newURLStr.insert(contentsOf: "https://\(ip)", at: newURLStr.startIndex)
        }
        guard let url = URL(string: newURLStr) else { return }
        var fileName = url.lastPathComponent
        fileName = fileName.replacingOccurrences(of: "%2B", with: "+")
        if let localURL = fileURLAt(dirName: photoDir, fileName: fileName) {
            let block = {
                let data = try! Data(contentsOf: localURL)
                self.lock.lock()
                let image = UIImage(data: data)
                self.lock.unlock()
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
                if let cookie = cookie, !cookie.isEmpty {
                    request.setValue("SESSION="+cookie, forHTTPHeaderField: "Cookie")
                    if downloadingInfos[fileName] != nil {
                        downloadingInfos[fileName]?.append(ImageRequest(completionHandler: completion, progressBlock: progress))
                        return
                    }
                    downloadingInfos[fileName] = [ImageRequest(completionHandler: completion, progressBlock: progress)]
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
                requestImage(urlStr: url.absoluteString, completion: nil, progress: nil)
                if let removed = removed {
                    downloadingInfos[fileName] = removed
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        guard let data = try? Data(contentsOf: location) else { return }
        let image = UIImage(data: data)
        let fileName = sourceURL.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
        DispatchQueue.global().async {
            saveFileToDisk(dirName: photoDir, fileName: fileName, data: data)
            syncOnMainThread {
                self.downloadingInfos.remove(key: fileName)?.forEach( { request in
                    request.completionHandler?(image, data, fileURLAt(dirName: photoDir, fileName: fileName)!)
                })
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        let fileName = sourceURL.lastPathComponent.replacingOccurrences(of: "%2B", with: "+")
        downloadingInfos[fileName]?.forEach( {
            $0.progressBlock?(progress)
        })
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
    
    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        NotificationCenter.default.post(name: .backgroundSessionFinish, object: session)
    }
}
