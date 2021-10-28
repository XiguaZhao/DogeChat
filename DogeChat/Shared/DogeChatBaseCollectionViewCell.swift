//
//  DogeChatBaseCollectionViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatBaseCollectionViewCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
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
                self.backgroundColor = .clear
            } else {
                self.backgroundColor = .systemBackground
            }
        }
    }

}
