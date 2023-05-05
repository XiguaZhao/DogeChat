//
//  ChatRoom+JumpButton.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/29.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatCommonDefines

extension ChatRoomViewController {
    
    func makeJumpButtons() {
        atLabel.text = localizedString("jumpTo")
        atLabel.font = .systemFont(ofSize: 13)
        atLabel.textColor = #colorLiteral(red: 0, green: 0.5130392909, blue: 1, alpha: 1)
        jumpToUnreadStack = UIStackView(arrangedSubviews: [atLabel, jumpToUnreadButton])
        jumpToUnreadStack.spacing = 8
        jumpToUnreadStack.isHidden = true
        view.addSubview(jumpToUnreadStack)

        jumpToUnreadButton.contentMode = .scaleAspectFit
        jumpToUnreadButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(30)
        }
        jumpToUnreadStack.isUserInteractionEnabled = true
        jumpToUnreadStack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(jumpToFirstUnread)))
        if #available(iOS 13, *) {
            jumpToUnreadButton.image = UIImage(systemName: "arrow.up.circle.fill", withConfiguration: MessageInputView.largeConfig as? UIImage.Configuration)
        }
        
        let jumpToBottomButton = UIImageView()
        jumpToBottomButton.contentMode = .scaleAspectFit
        if #available(iOS 13.0, *) {
            jumpToBottomButton.image = UIImage(systemName: "arrow.down.circle.fill", withConfiguration: MessageInputView.largeConfig as? UIImage.Configuration)
        }
        jumpToBottomButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(30)
        }
        let jumpToBottomLable = UILabel()
        jumpToBottomLable.text = localizedString("backToBottom")
        jumpToBottomStack = UIStackView(arrangedSubviews: [jumpToBottomButton])
        jumpToBottomStack.isHidden = true
        view.addSubview(jumpToBottomStack)
        jumpToBottomLable.font = .systemFont(ofSize: 13)
        jumpToBottomLable.textColor = #colorLiteral(red: 0, green: 0.5130392909, blue: 1, alpha: 1)

        jumpToBottomStack.isUserInteractionEnabled = true
        jumpToBottomStack.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(jumpToBottom)))

        jumpToUnreadStack.translatesAutoresizingMaskIntoConstraints = false
        jumpToBottomStack.translatesAutoresizingMaskIntoConstraints = false
        
        let safeArea = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            jumpToUnreadStack.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -10),
            jumpToUnreadStack.bottomAnchor.constraint(equalTo: self.jumpToBottomStack.topAnchor, constant: -15),
            jumpToBottomStack.trailingAnchor.constraint(equalTo: jumpToUnreadStack.trailingAnchor),
            jumpToBottomStack.bottomAnchor.constraint(equalTo: self.messageInputBar.topAnchor, constant: -30)
        ])
    }
    
    @objc func jumpToBottom() {
        scrollBottom(animated: true)
        jumpToBottomStack.isHidden = true
    }
    
    func processJumpToBottomButton() {
        guard let visibleIndexPaths = tableView.indexPathsForVisibleRows else { return }
        jumpToBottomStack.isHidden = visibleIndexPaths.contains(IndexPath(row: 0, section: self.messages.count - 1))
    }
    
    func processJumpToUnreadButton() {
        guard self.purpose == .chat else { return }
        var show = false
        var unreads = [Message]()
        unreads = self.messages.filter({ !$0.isRead })
        if let _ = explictJumpMessageUUID {
            show = true
        } else {
            if !unreads.isEmpty {
                show = true
            }
        }
        let oldHidden = jumpToUnreadButton.isHidden
        if show, let firstIndexAt = unreads.firstIndex(where: { $0.someoneAtMe }) {
            explictJumpMessageUUID = unreads[firstIndexAt].uuid
            atLabel.isHidden = false
        } else {
            atLabel.isHidden = true
        }
        jumpToUnreadStack.isHidden = !show
        if !show {
            explictJumpMessageUUID = nil
        }
        if oldHidden && show {
            animateJumpButton(true)
        }
    }
    
    func animateJumpButton(_ show: Bool) {
        jumpToUnreadButton.alpha = show ? 0 : 1
        let duration = 0.8
        UIView.animate(withDuration: duration) {
            self.jumpToUnreadButton.alpha = show ? 1 : 0
        } completion: { _ in
        }
    }
    
    @objc func jumpToFirstUnread() {
        var index: Int?
        if let uuid = explictJumpMessageUUID, let _index = messages.firstIndex(where: { $0.uuid == uuid }) {
            index = _index
        } else if let firstUnread = self.messages.filter({ !$0.isRead }).first, let _index = self.messages.firstIndex(of: firstUnread) {
            index = _index
        }
        if let index = index {
            tableView.scrollToRow(at: IndexPath(row: 0, section: index), at: .middle, animated: false)
        }
        explictJumpMessageUUID = nil
        self.messages.forEach({ $0.isRead = true })
        jumpToUnreadStack.isHidden = true
    }
    

}
