//
//  MusicManager.swift
//  DogeChat
//
//  Created by ByteDance on 2023/3/26.
//  Copyright © 2023 Luke Parham. All rights reserved.
//

import Foundation
import MusicKit
import DogeChatCommonDefines

@available(iOS 15, *)
class MusicManager {
    static let shared = MusicManager()
    private init() {}
        
    func requestAuthIfNeeded() async {
        let status = await MusicAuthorization.request()
        switch status {
        case .authorized:
            print("apple music已授权")
        case .denied:
            makeToast(message: "您已拒绝，无法使用相关功能")
        default:
            return
        }
    }
    
    func canPlayAppleMusicContents() async -> Bool {
        if let status = try? await MusicSubscription.current {
            return status.canPlayCatalogContent
        }
        return false
    }
    
    enum SearchType {
        case album
        case song
    }
    func search(_ term: String, type: SearchType = .song, page: Int) async {
        let requestType: [MusicCatalogSearchable.Type]
        switch type {
        case .song: requestType = [Song.self]
        case .album: requestType = [Album.self]
        }
        var request = MusicCatalogSearchRequest(term: term, types: requestType)
        request.limit = 20
        request.offset = 20 * page
        if let response = try? await request.response() {
        }
    }
    
}
