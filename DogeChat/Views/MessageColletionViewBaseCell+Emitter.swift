//
//  MessageColletionViewBaseCell+Emitter.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/6.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

extension MessageCollectionViewBaseCell {
    
    func addDoubleTapForAvatar() {
        doubleTapGes.numberOfTapsRequired = 2
        doubleTapGes.addTarget(self, action: #selector(doubleTapAction(_:)))
//        avatarImageView.addGestureRecognizer(doubleTapGes)
    }
    
    @objc func doubleTapAction(_ ges: UITapGestureRecognizer) {
        delegate?.avatarDoubleTap(self)
    }
    
    override func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == tapAvatar && otherGestureRecognizer == doubleTapGes {
            return true
        }
        return false
    }
}
