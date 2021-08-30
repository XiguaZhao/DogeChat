//
//  VideoView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class VideoView: UIView {

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
}
