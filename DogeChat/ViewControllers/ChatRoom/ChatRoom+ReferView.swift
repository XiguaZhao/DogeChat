//
//  ChatRoom+ReferView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/19.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal

extension ChatRoomViewController: ReferViewDelegate {
    
    @objc func referAction(sender: UIMenuController!) {
        menuItemDone()
        guard let cell = activeMenuCell,
              let index = tableView.indexPath(for: cell)?.row else { return }
        messageInputBar.referView.apply(message: messages[index])
        messageInputBar.layoutIfNeeded()
        let keyboardVisible = messageInputBar.isActive
        messageInputBar.textView.becomeFirstResponder()
        guard messageInputBar.referView.alpha == 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + (keyboardVisible ? 0 : 0.25)) { [self] in
            var offset = tableView.contentOffset
            offset.y += ReferView.height
            var inset = tableView.contentInset
            inset.bottom += ReferView.height
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2) { [self] in
                messageInputBar.referView.alpha = 1
                messageInputBar.referViewBottomContraint.constant = 0
                messageInputBar.topConstraint.constant = -ReferView.height
                messageInputBar.layoutIfNeeded()
                tableView.contentOffset = offset
                tableView.contentInset = inset
            } completion: { _ in
            }
        }

    }
    
    func referViewTapAction(_ referView: ReferView, message: Message?) {
        guard let message = message else {
            return
        }
        if message.messageType == .image || message.messageType == .livePhoto || message.messageType == .video {
            let browser = MediaBrowserViewController()
            browser.imagePaths = [message.text]
            present(browser, animated: true, completion: nil)
        } else if let index = self.messages.firstIndex(of: message) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.selectRow(at: indexPath, animated: true, scrollPosition: .middle)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                tableView.deselectRow(at: indexPath, animated: true)
            }
        } else {
            let vc = HistoryVC(type: .referView, username: username)
            let message = message.copied()
            vc.messages = [message]
            vc.friend = friend
            navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    func cancleAction(_ referView: ReferView) {
        guard referView.type == .inputView else { return }
        messageInputBar.layoutIfNeeded()
        var inset = tableView.contentInset
        inset.bottom -= ReferView.height
        var offset = tableView.contentOffset
        offset.y -= ReferView.height
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 2) { [self] in
            messageInputBar.referView.alpha = 0
            messageInputBar.referViewBottomContraint.constant = ReferView.height
            messageInputBar.topConstraint.constant = 0
            messageInputBar.layoutIfNeeded()
            tableView.contentInset = inset
            tableView.contentOffset = offset
        } completion: { _ in
            
        }
    }
    

    
}
