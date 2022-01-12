//
//  TrackStore.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import DogeChatCommonDefines

class TrackStore: NSObject, Codable {
    
    var tracks: [Track]
    var playLists: [String]
    
    init(tracks: [Track], playLists: [String]) {
        self.tracks = tracks
        self.playLists = playLists
    }
    
}
