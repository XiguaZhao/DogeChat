//
//  PostModel.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/3.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal

protocol PostMeta {
    
}

struct PostModel {
    
    struct PostLocation: PostMeta {
        let latitude: Double
        let longitude: Double
    }

    struct PostImage: PostMeta {
        let imageURL: String?
        let videoURL: String?
    }

    struct PostVideo: PostMeta {
        let videoURL: String?
    }

    struct PostDrawing: PostMeta {
        let drawURL: String?
    }
    
    struct PostTrack: PostMeta {
        let postURL: String?
    }
    
    struct PostText: PostMeta {
        let text: String
    }
    
    var metas: [PostMeta]
    
    
}

