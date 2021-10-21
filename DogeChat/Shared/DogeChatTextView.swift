//
//  DogeChatTextView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatTextView: UITextView, UITextPasteDelegate {

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        if AppDelegate.shared.immersive {
            self.backgroundColor = .clear
        }
        NotificationCenter.default.addObserver(self, selector: #selector(forceDarkMode(noti:)), name: .immersive, object: nil)
        self.pasteDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func becomeFirstResponder() -> Bool {
        if isMac() {
            (self.superview as? MessageInputView)?.frameDown()
        }
        return super.becomeFirstResponder()
    }
    
    @objc func forceDarkMode(noti: Notification) {
        let force = AppDelegate.shared.isForceDarkMode
        if #available(iOS 13.0, *) {
            if force {
                self.overrideUserInterfaceStyle = .dark
            } else {
                self.overrideUserInterfaceStyle = .unspecified
            }
        }
    }
    
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem) {
        if item.itemProvider.canLoadObject(ofClass: String.self) {
            _ = item.itemProvider.loadObject(ofClass: String.self) { str, error in
                if let str = str {
                    item.setResult(string: str)
                } else {
                    item.setNoResult()
                }
            }
        } else if item.itemProvider.canLoadObject(ofClass: UIImage.self) {
            item.setNoResult()
            NotificationCenter.default.post(name: .pasteImage, object: self, userInfo: ["itemProvider": item.itemProvider])
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(UITextView.paste(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
}
