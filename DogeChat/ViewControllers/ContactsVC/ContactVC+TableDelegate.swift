//
//  ContactVC+TableDelegate.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/12.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import UIKit

extension ContactsTableViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return self.friends.count
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: ContactTableViewCell!
        syncOnMainThread {
            let friend = self.friends[indexPath.row]
            cell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as? ContactTableViewCell
            cell.apply(friend, hasAt: self.unreadMessage[friend.userID]?.hasAt ?? false)
            cell.delegate = self
            if let number = unreadMessage[self.friends[indexPath.row].userID]?.unreadCount {
                cell.unreadCount = number
            }
        }
        return cell
    }
    
    //MARK: -Table view delegate
        
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing { return }
        unreadMessage[self.friends[indexPath.row].userID] = (0, false)
        let chatRoomVC = chatroomVC(for: indexPath)
        tableView.reloadRows(at: [indexPath], with: .none)
        reselectFriend(friends[indexPath.row])
        self.navigationController?.setViewControllersForSplitVC(vcs: [self, chatRoomVC], firstAnimated: false, secondAnimated: true, animatedIfCollapsed: true)
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let friend = self.friends[indexPath.row]
        let path = friend.avatarURL
        let config =  UIContextMenuConfiguration(identifier: (self.friends[indexPath.row].username as NSString)) {
            [weak self] in
            guard let self = self else { return nil }
            let vc = self.chatroomVC(for: indexPath)
            vc.purpose = .peek
            return vc
        } actionProvider: { (menuElement) -> UIMenu? in
            let avatarElement = UIAction(title: "查看头像") { [weak self] _ in
                guard let self = self else { return }
                self.avatarTapped(nil, path: path)
            }
            let switchMuteAction = UIAction(title: friend.isMuted ? "打开通知" : "不推送") { [weak self] _ in
                self?.switchMuteAction(index: indexPath.row)
            }
            var actions = [avatarElement, switchMuteAction]
            if UIApplication.shared.supportsMultipleScenes {
                actions.append(UIAction(title: "在单独窗口打开") { [weak self] _ in
                    guard let friend = self?.friends[indexPath.row] else { return }
                    let option = UIScene.ActivationRequestOptions()
                    option.requestingScene = self?.view.window?.windowScene
                    UIApplication.shared.requestSceneSessionActivation(nil, userActivity: self?.wrapUserActivity(for: friend), options: option, errorHandler: nil)
                })
            }
            return UIMenu(title: "", image: nil, children: actions)
        }
        return config
    }
    
    @available(iOS 13.0, *)
    func tableView(_ tableView: UITableView, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionCommitAnimating) {
        let username = configuration.identifier as! String
        if let index = self.usernames.firstIndex(of: username) {
            self.tableView(tableView, didSelectRowAt: IndexPath(row: index, section: 0))
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let isMuted = self.friends[indexPath.row].isMuted
        let muteAction = UIContextualAction(style: .normal, title: isMuted ? "打开通知" : "不推送") { [weak self] action, view, completion in
            self?.switchMuteAction(index: indexPath.row)
            completion(true)
        }
        muteAction.backgroundColor = #colorLiteral(red: 0.2392156869, green: 0.6745098233, blue: 0.9686274529, alpha: 1)
        return .init(actions: [muteAction])
    }
    
    func switchMuteAction(index: Int) {
        let friend = self.friends[index]
        manager?.httpsManager.switchMute(friend: friend, isMute: !friend.isMuted, completion: { [weak self] success in
            if success {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    self?.tableView.reloadRows(at: [IndexPath(row: index, section: 0)], with: .none)
                }
                self?.makeAutoAlert(message: "成功", detail: friend.isMuted ? "已静音" : "已开启提醒", showTime: 0.3, completion: nil)
            } else {
                self?.makeAutoAlert(message: "失败", detail: nil, showTime: 0.3, completion: nil)
            }
        })
    }

}
