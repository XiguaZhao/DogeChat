//
//  PostModel.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/3.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatCommonDefines

struct PostModel {
    
    struct Location {
        let latitude: Double
        let longitude: Double
    }

    struct PostImage {
        let imageURL: String?
        let videoURL: String?
    }
    
    struct PostComment {
        let text: String
        let image: String
    }
    
    let images: [PostImage]?
    let drawURL: NSString?
    let tracks: [Track]?
    let location: Location?
    let comments: [PostComment]
}

