//
//  DogeChatStaticBlurView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatStaticBlurView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        
        let blurView: UIVisualEffectView
        if #available(iOS 13.0, *) {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
        } else {
            blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        }
        self.addSubview(blurView)
        self.sendSubviewToBack(blurView)
        blurView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}
