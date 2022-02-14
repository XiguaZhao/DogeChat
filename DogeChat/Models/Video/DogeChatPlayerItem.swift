//
//  DogeChatPlayerItem.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/16.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatPlayerItem: AVPlayerItem {
    
    weak var observer: NSObject?
    var keyPath: String!
    
    func registerNotification(keyPath: String, object: NSObject) {
        self.observer = object
        self.keyPath = keyPath
        self.addObserver(object, forKeyPath: keyPath, options: .new, context: nil)
    }
    
    deinit {
        if let observer = observer {
            self.removeObserver(observer, forKeyPath: self.keyPath)
        }
    }

}
