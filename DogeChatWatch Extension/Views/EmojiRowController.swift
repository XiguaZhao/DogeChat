//
//  EmojiRowController.swift
//  DogeChatWatch Extension
//
//  Created by 赵锡光 on 2021/10/17.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import WatchKit

class EmojiRowController: NSObject {
    
    var leftPath = ""
    var rightPath = ""
    
    @IBOutlet weak var leftImageView: WKInterfaceImage!
    
    @IBOutlet weak var rightImageView: WKInterfaceImage!
    
    @IBAction func rightAction(_ sender: Any) {
        NotificationCenter.default.post(name: .selectEmoji, object: leftPath)
    }
    @IBAction func leftAction(_ sender: Any) {
        NotificationCenter.default.post(name: .selectEmoji, object: rightPath)
    }
}
