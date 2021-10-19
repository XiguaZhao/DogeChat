//
//  ImageLoader.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/12.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import UIKit

class ImageLoader: NSObject, URLSessionDownloadDelegate {
    static let shared = ImageLoader()
        
    struct ImageRequest {
        let completionHandler: ((UIImage?, Data) -> Void)?
        let progressBlock: ((Double) -> Void)?
    }
    
    var downloadingInfos = [String: [ImageRequest]]()
    
    lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpMaximumConnectionsPerHost = 20
        config.timeoutIntervalForRequest = 600
        let sesssion = URLSession(configuration: URLSessionConfiguration.default, delegate: self, delegateQueue: nil)
        
        return sesssion
    }()
    
    func requestImage(urlStr: String, syncIfCan: Bool = false, completion: ((UIImage?, Data) -> Void)? = nil, progress: ((Double) -> Void)? = nil) {
        let ip = "121.5.152.193"
        var newURLStr = urlStr
        newURLStr = newURLStr.replacingOccurrences(of: "procwq.top", with: ip)
        if !newURLStr.contains(ip) && !newURLStr.hasPrefix("https://") {
            newURLStr.insert(contentsOf: "https://\(ip)", at: newURLStr.startIndex)
        }
        guard let url = URL(string: newURLStr) else { return }
        let fileName = url.lastPathComponent
        if let localURL = fileURLAt(dirName: photoDir, fileName: fileName) {
            let block = {
                let data = try! Data(contentsOf: localURL)
                let image = UIImage(data: data)
                syncOnMainThread {
                    completion?(image, data)
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
                if downloadingInfos[newURLStr] != nil {
                    downloadingInfos[newURLStr]?.append(ImageRequest(completionHandler: completion, progressBlock: progress))
                    return
                }
                downloadingInfos[newURLStr] = [ImageRequest(completionHandler: completion, progressBlock: progress)]
                session.downloadTask(with: url).resume()
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if error != nil {
            print("下载失败")
            if let urlStr = task.originalRequest?.url?.absoluteString {
                let removed = downloadingInfos.remove(key: urlStr)
                requestImage(urlStr: urlStr, completion: nil, progress: nil)
                if let removed = removed {
                    downloadingInfos[urlStr] = removed
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        let urlStr = sourceURL.absoluteString
        guard let data = try? Data(contentsOf: location) else { return }
        let image = UIImage(data: data)
        syncOnMainThread {
            downloadingInfos.remove(key: urlStr)?.forEach( { request in
                request.completionHandler?(image, data)
            })
        }
        DispatchQueue.global().async {
            saveFileToDisk(dirName: photoDir, fileName: sourceURL.lastPathComponent, data: data)
        }
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        guard let sourceURL = downloadTask.originalRequest?.url else { return }
        downloadingInfos[sourceURL.absoluteString]?.forEach( {
            $0.progressBlock?(progress)
        })
    }
    
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        let credential = URLCredential(trust: challenge.protectionSpace.serverTrust!)
        completionHandler(.useCredential, credential)
    }
    
}
