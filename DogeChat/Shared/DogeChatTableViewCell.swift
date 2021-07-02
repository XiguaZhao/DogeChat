//
//  DogeChatTableViewCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatTableViewCell: UITableViewCell {
    
    static func cellID() -> String {
        return "DogeChatTableViewCell"
    }

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        if AppDelegate.shared.immersive {
            self.backgroundColor = .clear
        }
        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @objc func forceDarkMode(noti: Notification) {
    }

}
