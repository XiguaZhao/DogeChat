//
//  MessageColletionViewBaseCell+Emitter.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/6.
//  Copyright © 2021 赵锡光. All rights reserved.
//

extension MessageCollectionViewBaseCell {
    
    func addDoubleTapForAvatar() {
        avatarDoubleTapGes.numberOfTapsRequired = 2
        avatarDoubleTapGes.addTarget(self, action: #selector(doubleTapAction(_:)))
        avatarImageView.addGestureRecognizer(avatarDoubleTapGes)
        avatapSingleTapGes.require(toFail: avatarDoubleTapGes)
    }
    
    @objc func doubleTapAction(_ ges: UITapGestureRecognizer) {
        delegate?.avatarDoubleTap(self)
    }
    
}
