//
//  DogeChatTextView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import Foundation

class DogeChatTextView: UITextView, UITextPasteDelegate {
    
    var isActive = false
    var ignoreActions = false
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        if AppDelegate.shared.immersive {
            self.backgroundColor = .clear
        }
        self.pasteDelegate = self
        self.showsVerticalScrollIndicator = false
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    @discardableResult override func becomeFirstResponder() -> Bool {
        if isMac() {
            (self.superview as? MessageInputView)?.frameDown()
        }
        isActive = true
        return super.becomeFirstResponder()
    }
    
    @discardableResult override func resignFirstResponder() -> Bool {
        isActive = false
        return super.resignFirstResponder()
    }
    
    func textPasteConfigurationSupporting(_ textPasteConfigurationSupporting: UITextPasteConfigurationSupporting, transform item: UITextPasteItem) {
        if item.itemProvider.hasItemConformingToTypeIdentifier("public.file-url") {
            item.setNoResult()
            if isPhone() {
                NotificationCenter.default.post(name: .pasteImage, object: self, userInfo: ["itemProvider": item.itemProvider])
            }
            return
        }
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
            if isPhone() {
                NotificationCenter.default.post(name: .pasteImage, object: self, userInfo: ["itemProvider": item.itemProvider])
            }
        }
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if ignoreActions {
            return false
        }
        if action == #selector(UITextView.paste(_:)) {
            return true
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
}
