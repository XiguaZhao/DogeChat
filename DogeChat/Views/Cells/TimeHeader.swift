//
//  File.swift
//  DogeChat
//
//  Created by ByteDance on 2023/4/15.
//  Copyright © 2023 Luke Parham. All rights reserved.
//

import UIKit
import Masonry

class TimeHeader: UITableViewHeaderFooterView {
    
    static let countThreshold = 10
    static let secondThreshold: TimeInterval = 20 * 60
    
    static let id = "TimerHeader"
    
    let label = UILabel()
    
    override init(reuseIdentifier: String?) {
        super .init(reuseIdentifier: reuseIdentifier)
        
        label.numberOfLines = 1
        label.textColor = .lightGray
        label.font = UIFont(name: "Helvetica", size: 10)
        contentView.addSubview(label)
        
        label.mas_makeConstraints { make in
            make?.center.mas_equalTo()(0)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
