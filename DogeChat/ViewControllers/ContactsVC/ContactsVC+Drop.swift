//
//  ContactsVC+Drop.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/26.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatUniversal

extension ContactsTableViewController: UITableViewDropDelegate {
    
    func tableView(_ tableView: UITableView, performDropWith coordinator: UITableViewDropCoordinator) {
        let point = coordinator.session.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        let friend = friends[indexPath.row]
        let selectVC = SelectContactsViewController(username: self.username, selectedFriends: [friend], excluded: [])
        var messages = [Message]()
        let isLocal = coordinator.items.first?.dragItem.localObject != nil
        if isLocal {
            for item in coordinator.items {
                if let info = item.dragItem.localObject as? [String : Any], let userID = info["userID"] as? String {
                    if userID != friend.userID, let message = info["message"] as? Message {
                        messages.append(message)
                    }
                }
            }
            selectVC.didSelectContacts = { [weak self] friends in
                ChatRoomViewController.transferMessages(messages, to: friends, manager: self?.manager)
            }
            self.present(selectVC, animated: true, completion: nil)
        } else if !isMac() {
            let items = coordinator.items.map { $0.dragItem.itemProvider }
            let chatRooms = findChatRoomVCs()
            if let selectedContacts = tableView.indexPathsForSelectedRows?.map({ self.friends[$0.row] }) {
                self.messageSender.processItemProviders(items, friends: selectedContacts) { messages in
                    for message in messages {
                        if let friend = message.friend {
                            friend.messages.append(message)
                            friend.messageUUIDs.insert(message.uuid)
                        }
                    }
                    self.updateLatestMessages(messages)
                    for chatRoom in chatRooms {
                        chatRoom.insertNewMessageCell(messages, forceScrollBottom: true)
                    }
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canHandle session: UIDropSession) -> Bool {
        var res = session.canLoadObjects(ofClass: UIImage.self) || session.canLoadObjects(ofClass: String.self)
        res = res || session.hasItemsConforming(toTypeIdentifiers: [videoIdentifier])
        res = res || session.hasItemsConforming(toTypeIdentifiers: [audioIdentifier])
        return res
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidEnd session: UIDropSession) {
        newesetDropIndexPath = nil
        guard !isMac() else { return }
        tableView.setEditing(false, animated: true)
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidUpdate session: UIDropSession, withDestinationIndexPath destinationIndexPath: IndexPath?) -> UITableViewDropProposal {
        guard let indexPath = destinationIndexPath else { return .init(operation: .cancel) }
        self.newesetDropIndexPath = indexPath
        if isMac() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                if self?.newesetDropIndexPath == indexPath && self?.selectedFriend != self?.friends[indexPath.row] {
                    self?.tableView(tableView, didSelectRowAt: indexPath)
                }
            }
        }
        return .init(operation: .copy)
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidExit session: UIDropSession) {
        newesetDropIndexPath = nil
        guard !isMac() else { return }
        tableView.setEditing(false, animated: true)
    }
    
    func tableView(_ tableView: UITableView, dropSessionDidEnter session: UIDropSession) {
        guard !isMac() && session.localDragSession == nil else { return }
        tableView.allowsSelectionDuringEditing = true
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.setEditing(true, animated: true)
    }
    
}
