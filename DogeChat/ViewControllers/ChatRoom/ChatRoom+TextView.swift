//
//  ChatRoom+TextView.swift
//  DogeChat
//
//  Created by ByteDance on 2023/3/11.
//  Copyright © 2023 Luke Parham. All rights reserved.
//

import Foundation

extension ChatRoomViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        showEmojiButton(textView.text.isEmpty)
        if let markRange = textView.markedTextRange,
           textView.position(from: markRange.start, offset: 0) != nil {
            return
        }
        let text = textView.text ?? ""
        let oldFrame = messageInputBar.frame
        let newTextViewSize = textView.contentSize
        var heightChanged = newTextViewSize.height - lastTextViewHeight
        var tableViewInset = tableView.contentInset
        if text.isEmpty {
            heightChanged = messageBarHeight - oldFrame.height
            textView.font = .systemFont(ofSize: MessageInputView.textViewDefaultFontSize * fontSizeScale)
        }
        let inputBarHeight = oldFrame.height+heightChanged
        if inputBarHeight > MessageInputView.maxHeight {
            heightChanged = MessageInputView.maxHeight - oldFrame.height
        }
        if inputBarHeight < messageBarHeight {
            heightChanged = messageBarHeight - oldFrame.height
        }
        let finalFrame = CGRect(x: oldFrame.origin.x, y: oldFrame.origin.y-heightChanged, width: oldFrame.width, height: oldFrame.height+heightChanged)
        tableViewInset.bottom += heightChanged
        lastTextViewHeight = newTextViewSize.height
        if abs(heightChanged) > 15 || scrollByTextViewChange() {
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.25, animations: { [weak self] in
                    guard let self = self else { return }
                    self.messageInputBar.frame = finalFrame
                    self.view.layoutIfNeeded()
                    self.tableView.contentInset = tableViewInset
                    if self.needScrollBottom() {
                        self.scrollBottom(animated: false)
                    }
                }) { _ in
                    self.updateTextViewOffset()
                    self.lastTextViewHeight = textView.frame.height
                }
            }
        } else {
            updateTextViewOffset()
        }
    }
    
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        if text.isEmpty { return true }
        if text == "\n" {
            messageInputBar.sendTapped()
            messageInputBar.textView.font = .systemFont(ofSize: MessageInputView.textViewDefaultFontSize * fontSizeScale)
            return false
        } else {
            /*
             guard let text = textView.text else { return true }
             let components = text.components(separatedBy: "@")
             var location = 0
             for (index, component) in components.enumerated() {
                 if let strRange = self.messageSender.at.keys.compactMap( { component.range(of: $0) } ).first {
                     var atRange = component.toNSRange(strRange)
                     atRange = NSRange(location: location+1, length: atRange.length)
                     if atRange.intersection(range) != nil {
                         return false
                     }
                 }
                 location += (index == 0 ? 0 : 1)
                 if let strRange = component.range(of: component) {
                     location += component.toNSRange(strRange).length
                 }
             }
             */

        }
        return true
    }
    
    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        UIMenuController.shared.menuItems?.removeAll(where: { NSStringFromSelector($0.action).hasPrefix("dogechat")} )
        if !lastRowVisible() {
            scrollBottom(animated: false)
        }
        showEmojiButton(textView.text.isEmpty)
        messageInputBar.recoverEmojiButton()
        emojiSelectView.pageIndicator.isHidden = true
        return true
    }
    
    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        showEmojiButton(true)
        return true
    }
        

            
}
