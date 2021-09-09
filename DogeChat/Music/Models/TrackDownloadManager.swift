//
//  TrackDownloadManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork

protocol DownloadDelegate: AnyObject {
    func downloadUpdateProgress(_ track: Track, progress: Progress)
    func downloadComplete(_ tracK: Track, localPath: URL)
}

class TrackDownloadManager: NSObject {

    static let shared = TrackDownloadManager()
    
    var downloadingTracks: [Track] = []
    let session = AFHTTPSessionManager()
    weak var delegate: DownloadDelegate?
    
    private override init() {
        session.requestSerializer = AFJSONRequestSerializer()
        session.responseSerializer = AFCompoundResponseSerializer()
    }
    
    func startDownload(track: Track, newesetURL: URL? = nil) {
        guard !track.isDownloaded else { return }
        if newesetURL == nil {
            MusicHttpManager.shared.getTrackWithID(track.id, source: .appleMusic) { tracks in
                if let track = tracks.first {
                    self.startDownload(track: track, newesetURL: URL(string: track.musicLinkUrl))
                }
            }
            return
        }
        track.state = .downloading
        downloadingTracks.append(track)
        var url: URL?
        if let newestURL = newesetURL {
            url = newestURL
        } else {
            url = URL(string: track.musicLinkUrl)
        }
        guard let url = url else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                PlayerManager.shared.playFail(track: track)
            })
            return
        }
        let request = URLRequest(url: url)
        let task = session.downloadTask(with: request) { progress in
            DispatchQueue.main.async {
                self.delegate?.downloadUpdateProgress(track, progress: progress)
            }
        } destination: { url, response in
            print(url)
            let des = createDir(name: "tracks")
            let localPath = des.appendingPathComponent(track.id).appendingPathExtension("mp3")
            DispatchQueue.main.async {
                self.delegate?.downloadComplete(track, localPath: localPath)
            }
            print(localPath.absoluteString)
            if let url = response.url?.absoluteString {
                if url.hasSuffix("404") {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
                        PlayerManager.shared.playFail(track: track)
                    })
                }
            }
            return localPath
        } completionHandler: { response, url, error in
            guard error == nil else { return }
            track.state = .downloaded
            if let index = self.downloadingTracks.firstIndex(of: track) {
                self.downloadingTracks.remove(at: index)
            }
        }
        task.resume()
        NotificationCenter.default.post(name: .downloadTrack, object: track)
    }
    
    
}

func createDir(name: String) -> URL {
    let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
        .appendingPathComponent(name)
    try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    return url
}
