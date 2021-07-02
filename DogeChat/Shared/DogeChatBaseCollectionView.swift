//
//  DogeChatBaseCollectionView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatBaseCollectionView: UICollectionView {
    
    override init(frame: CGRect, collectionViewLayout layout: UICollectionViewLayout) {
        super.init(frame: frame, collectionViewLayout: layout)
        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
        if AppDelegate.shared.immersive {
            self.backgroundColor = .clear
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
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
