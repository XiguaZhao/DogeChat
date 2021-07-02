//
//  DogeChatTextView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatTextView: UITextView {

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        if AppDelegate.shared.immersive {
            self.backgroundColor = .clear
        }
        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func forceDarkMode(noti: Notification) {
        let force = noti.object as! Bool
        if #available(iOS 13.0, *) {
            if force {
                self.overrideUserInterfaceStyle = .dark
            } else {
                self.overrideUserInterfaceStyle = .unspecified
            }
        }
    }

}
