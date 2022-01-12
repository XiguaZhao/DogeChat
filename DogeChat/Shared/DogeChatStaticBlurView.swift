//
//  DogeChatStaticBlurView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatStaticBlurView: UIView {
    
    weak var topConstraint: NSLayoutConstraint!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let blurView: UIVisualEffectView
        if #available(iOS 13.0, *) {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        } else {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .light))
        }
        self.addSubview(blurView)
        self.sendSubviewToBack(blurView)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        blurView.mas_makeConstraints { [weak self] make in
            make?.leading.trailing().bottom().equalTo()(self)
        }
        self.topConstraint = blurView.topAnchor.constraint(equalTo: self.topAnchor, constant: 0)
        self.topConstraint.isActive = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
