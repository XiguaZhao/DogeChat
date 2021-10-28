//
//  DogeChatTableView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatTableView: UITableView {

    override init(frame: CGRect, style: UITableView.Style) {
        super.init(frame: frame, style: style)
        self.separatorStyle = .none
//        updateBgColor()
//        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func adjustedContentInsetDidChange() {
        super.adjustedContentInsetDidChange()
    }
    
    func updateBgColor() {
        if AppDelegate.shared.immersive && UserDefaults.standard.bool(forKey: "immersive") {
            self.backgroundColor = .clear
        } else {
            if #available(iOS 13.0, *) {
                self.backgroundColor = nil
            } else {
                // Fallback on earlier versions
            }
        }
    }
    
    @objc func forceDarkMode(noti: Notification) {
        updateBgColor()
    }
    
}
