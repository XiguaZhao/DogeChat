//
//  ViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/10/29.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork
import SwiftyJSON
import DogeChatCommonDefines

class FriendDetailViewController: DogeChatViewController, UITableViewDataSource, UITableViewDelegate, DogeChatVCTableDataSource {
    
    enum RowType {
        case username
        case nickName
        case nameInGroup
        case groupOwner
        case doNotDisturb
        case addMember
        case removeMember
        case groupMember
        case createGroup
        case deleteGroup
        case history
        case changeGroupAvatar
        case switchMute
        
        func localizedString() -> String {
            switch self {
            case .username:
                return NSLocalizedString("username", comment: "")
            case .nickName:
                return NSLocalizedString("nickname", comment: "")
            case .nameInGroup:
                return NSLocalizedString("myNickName", comment: "")
            case .groupOwner:
                return NSLocalizedString("groupOwner", comment: "")
            case .doNotDisturb:
                return NSLocalizedString("doNotDisturb", comment: "")
            case .addMember:
                return NSLocalizedString("addGroupMember", comment: "")
            case .removeMember:
                return NSLocalizedString("removeGroupMember", comment: "")
            case .groupMember:
                return NSLocalizedString("groupMembers", comment: "")
            case .createGroup:
                return NSLocalizedString("createGroup", comment: "")
            case .deleteGroup:
                return NSLocalizedString("deleteGroup", comment: "")
            case .history:
                return NSLocalizedString("browseHistory", comment: "")
            case .changeGroupAvatar:
                return NSLocalizedString("modifyGroupAvatar", comment: "")
            case .switchMute:
                return NSLocalizedString("notification", comment: "")
            }
        }
    }
    
    var manager: WebSocketManager? {
        socketForUsername(username)
    }
    
    var rows = [RowType]()

    var friend: Friend!
    
    var myNameInGroup: String?
    
    var members: [Friend] = []
    
    var sections = [[Any]]()
    
    var tableView = DogeChatTableView()
    
    var newlyCreatedGroup: Group?
    
    let group = DispatchGroup()
    
    convenience init(friend: Friend, username: String) {
        self.init()
        hidesBottomBarWhenPushed = true
        
        self.friend = friend
        self.username = username
        self.navigationItem.title = friend.nickName ?? friend.username
        if friend.isGroup, let group = friend as? Group {
            rows = [.nickName, .nameInGroup, .groupOwner, .switchMute, .changeGroupAvatar, .addMember, .removeMember]
            if group.ownerID == manager?.httpsManager.myId {
                rows.append(.deleteGroup)
            }
            getMembers()
        } else {
            rows = [.username, .nickName, .switchMute, .createGroup]
        }
        rows.insert(.history, at: 2)
        sections = [rows]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(tableView)
        
        tableView.showsVerticalScrollIndicator = false
        tableView.register(CommonTableCell.self, forCellReuseIdentifier: CommonTableCell.cellID)
        tableView.register(ContactTableViewCell.self, forCellReuseIdentifier: ContactTableViewCell.cellID)
        tableView.delegate = self
        tableView.dataSource = self
        
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        navigationController?.setToolbarHidden(true, animated: true)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        tableView.frame = view.bounds
    }
        
    func getMembers() {
        guard let manager = manager, let group = self.friend as? Group else { return }
        manager.httpsManager.getGroupMembers(group: group) { [self] members in
            self.members = members
            if let myNameInGroup = members.first(where: { $0.userID == manager.myInfo.userID })?.nameInGroup {
                self.myNameInGroup = myNameInGroup
            }
            tableView.reloadData()
            if !(self.sections.last is [Friend]) {
                self.sections.append(members)
                tableView.insertSections(IndexSet(integer: 1), with: .top)
            } else {
                self.sections[self.sections.count - 1] = members
                tableView.reloadData()
            }
        }
    }
    
    func getNavHeight() -> CGFloat {
        if let navBar = navigationController?.navigationBar {
            if #available(iOS 13.0, *) {
                return navBar.bounds.height + (self.view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0)
            } else {
                return navBar.bounds.height + UIApplication.shared.statusBarFrame.height
            }
        }
        return 0
    }
        
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].count
    }
        
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell!
        let section = sections[indexPath.section]
        if let commonRows = section as? [RowType] {
            cell = tableView.dequeueReusableCell(withIdentifier: CommonTableCell.cellID, for: indexPath)
            let commonCell = cell as! CommonTableCell
            let row = commonRows[indexPath.row]
            var title = row.localizedString()
            var type: CommonTableCell.TrailingViewType?
            var trailingText: String?
            var switchOn: Bool?
            switch row {
            case .nickName:
                type = .textField
                trailingText = friend.isGroup ? friend.username : friend.nickName
                title = friend.isGroup ? NSLocalizedString("groupName", comment: "") : NSLocalizedString("nickname", comment: "")
            case .groupOwner:
                type = .label
                trailingText = (friend as? Group)?.ownerUsername
            case .doNotDisturb:
                type = .switcher
            case .username:
                type = .label
                trailingText = friend.username
            case .nameInGroup:
                type = .textField
                trailingText = myNameInGroup ?? manager?.myInfo.username
            case .switchMute:
                type = .switcher
                switchOn = !self.friend.isMuted
            default:
                break
            }
            commonCell.delegate = self
            commonCell.apply(title: title,
                             subTitle: nil,
                             imageURL: nil,
                             trailingViewType: type,
                             trailingText: trailingText,
                             switchOn: switchOn)
        } else if let members = section as? [Friend] {
            let contactCell = tableView.dequeueReusableCell(withIdentifier: ContactTableViewCell.cellID, for: indexPath) as? ContactTableViewCell
            cell = contactCell
            cell.selectionStyle = .default
            contactCell?.latestMessageLabel.isHidden = true
            let member = members[indexPath.row]
            var titleMore: String?
            if let nameInGroup = member.nameInGroup {
                titleMore = "（\(nameInGroup)）"
            }
            contactCell?.apply(member, titleMore: titleMore)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if sections[section] is [Friend] {
            return NSLocalizedString("groupMembers", comment: "") + "(\(self.members.count))"
        } else if sections[section] is [RowType] {
            return NSLocalizedString("commonInfo", comment: "")
        }
        return nil
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if tableView.isEditing {
            let type = sections[indexPath.section][indexPath.row]
            if type is RowType || (type as? Friend)?.userID == manager?.messageManager.myId {
                tableView.deselectRow(at: indexPath, animated: true)
            }
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        if let rows = self.sections[indexPath.section] as? [RowType] {
            switch rows[indexPath.row] {
            case .addMember:
                self.addMember()
            case .history:
                let vc = HistoryVC(purpose: .history)
                vc.friend = self.friend
                self.navigationController?.pushViewController(vc, animated: true)
            case .createGroup:
                let alert = UIAlertController(title: "群聊名称", message: nil, preferredStyle: .alert)
                alert.addTextField(configurationHandler: nil)
                alert.addAction(UIAlertAction(title: "确认", style: .default, handler: { [weak alert] _ in
                    if let text = alert?.textFields?.first?.text, !text.isEmpty {
                        self.createGroup(named: text)
                    }
                }))
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            case .deleteGroup:
                let alert = UIAlertController(title: "确定删除？", message: friend.username, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "确认", style: .default, handler: {  _ in
                    self.deleteGroup()
                }))
                alert.addAction(UIAlertAction(title: "取消", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            case .removeMember:
                removeMember()
            case .changeGroupAvatar:
                changeGroupAvatar()
            default: break
            }
        } else if let friends = self.sections[indexPath.section] as? [Friend] {
            let friend = friends[indexPath.row]
            if friend.isMyFriend {
                (self.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.jumpToFriend(friend)
            }
        }
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        if let friends = sections[indexPath.section] as? [Friend] {
            if friends[indexPath.row].userID != manager?.messageManager.myId {
                return true
            }
        }
        return false
    }
    
    func changeGroupAvatar() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }
    
    func createGroup(named name: String) {
        manager?.httpsManager.createGroup(named: name) { [weak self] group in
            self?.makeAutoAlert(message: group != nil ? "创建成功" : "创建失败", detail: name, showTime: 1, completion: {
                if group != nil {
                    self?.newlyCreatedGroup = group
                    self?.group.enter()
                    self?.manager?.httpsManager.getContacts(completion: { (friends, _) in
                        self?.group.leave()
                    })
                    self?.group.enter()
                    self?.addMember()
                    self?.group.notify(queue: .main, execute: { [weak self] in
                        if let newlyCreatedGroup = self?.newlyCreatedGroup {
                            (self?.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.jumpToFriend(newlyCreatedGroup)
                        }
                    })
                }
            })
        }
    }
    
    func deleteGroup() {
        guard let group = self.friend as? Group else { return }
        manager?.httpsManager.deleteGroup(group) { [weak self] success in
            self?.makeAutoAlert(message: success ? "删除成功" : "删除失败", detail: self?.friend.username, showTime: 1, completion: {
                if success {
                    self?.backToContactVC()
                    (self?.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.deleteFriend(group)
                }
            })
        }
    }
    
    func removeMember() {
        tableView.allowsMultipleSelection = true
        tableView.allowsMultipleSelectionDuringEditing = true
        tableView.setEditing(true, animated: true)
        let confirm = UIBarButtonItem(title: "确定", style: .plain, target: self, action: #selector(confirmDelete))
        let cancel = UIBarButtonItem(title: "取消", style: .plain, target: self, action: #selector(cancelDelete))
        navigationItem.setRightBarButtonItems([confirm, cancel], animated: true)
    }
    
    @objc func confirmDelete() {
        navigationItem.setRightBarButtonItems(nil, animated: true)
        if let indexPaths = tableView.indexPathsForSelectedRows {
            let ids = indexPaths.map { self.members[$0.row].userID }
            manager?.httpsManager.removeGroupMembers(in: self.friend as! Group, memberIDs: ids) { success in
                self.tableView.setEditing(false, animated: true)
                self.makeAutoAlert(message: success ? "成功删除" : "遇到错误，请重试", detail: nil, showTime: 1, completion: {
                })
                if success {
                    self.getMembers()
                }
            }
        }
    }
    
    @objc func cancelDelete() {
        tableView.setEditing(false, animated: true)
        navigationItem.setRightBarButtonItems(nil, animated: true)
    }
    
    func backToContactVC() {
        if self.navigationController?.viewControllers.first is ContactsTableViewController {
            self.navigationController?.popToRootViewController(animated: true)
        } else {
            self.navigationController?.setViewControllers([], animated: true)
        }
    }
    
    func addMember() {
        guard let manager = manager else {
            return
        }
        let excluded = manager.friends.filter( { $0.isGroup })
        let selectVC = SelectContactsViewController(username: username, selectedFriends: self.friend.isGroup ? members : [self.friend], excluded: excluded)
        selectVC.delegate = self
        self.present(selectVC, animated: true, completion: nil)
    }
        
}

extension FriendDetailViewController: SelectContactsDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate, TrailingViewProtocol {
    
    func didSelectContacts(_ contacts: [Friend], vc: SelectContactsViewController) {
        let filtered = contacts.filter( { !members.contains($0) })
        let ids = filtered.map { $0.userID }
        let groupID = newlyCreatedGroup?.userID ?? self.friend.userID
        manager?.httpsManager.addMembers(to: groupID, memberIDs: ids) { success in
            self.makeAutoAlert(message: success ? "已发送请求" : "遇到错误，请重试", detail: nil, showTime: 1, completion: {
                if self.newlyCreatedGroup != nil {
                    self.group.leave()
                }
            })
            if success {
                self.getMembers()
            }
        }
    }
    
    func didCancelSelectContacts(_ vc: SelectContactsViewController) {
        vc.dismiss(animated: true, completion: nil)
        if newlyCreatedGroup != nil {
            group.leave()
        }
    }
    
    func didFetchContacts(_ contacts: [Friend], vc: SelectContactsViewController) {
        
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let image = info[.editedImage] as? UIImage else { return }
        if let compressedImageData = compressImage(image, needSave: false).image.jpegData(compressionQuality: 0.3) {
            manager?.uploadData(compressedImageData, path: "user/changeAvatar?groupId=\(self.friend.userID)", name: "avatar", fileName: UUID().uuidString + ".jpeg", needCookie: true, contentType: "multipart/form-data", params: nil) { [self] task, data in
                guard let data = data else { return }
                let json = JSON(data)
                if json["status"].stringValue == "success" {
                    let avatarURL = json["avatarUrl"].stringValue
                    if let friend = manager?.httpsManager.friends.first(where: { $0.userID == self.friend.userID } ) {
                        friend.avatarURL = avatarURL
                        NotificationCenter.default.post(name: .friendChangeAvatar, object: username, userInfo: ["friend": friend])
                    }
                }
            }
        }
    }

    func didSwitch(cell: CommonTableCell, isOn: Bool) {
        if let indexPath = self.tableView.indexPath(for: cell) {
            let type = self.sections[indexPath.section][indexPath.row]
            if let type = type as? RowType, type == RowType.switchMute {
                manager?.httpsManager.switchMute(friend: self.friend, isMute: !self.friend.isMuted, completion: { [weak self] success in
                    if success {
                        self?.tableView.reloadRows(at: [indexPath], with: .none)
                    }
                    NotificationCenter.default.post(name: .reloadContacts, object: nil)
                })
            }
        }
    }
    
    func textFieldDidEndInputing(cell: CommonTableCell, text: String) {
        guard !text.isEmpty else { return }
        if let indexPath = tableView.indexPath(for: cell) {
            let row = rows[indexPath.row]
            var personal: Bool? = friend.isGroup ? false : nil
            if row == .nameInGroup {
                personal = true
            }
            let targetID = friend.userID
            manager?.httpsManager.changeNickName(targetID: targetID, nickName: text, personal: personal, isGroup: friend.isGroup) { success in
                if success {
                    if personal ?? false {
                        self.updateMyNameInGroup(text: text)
                    }
                    self.makeAutoAlert(message: "更换成功", detail: text, showTime: 1, completion: nil)
                    self.manager?.httpsManager.getContacts(completion: nil)
                    if !self.friend.isGroup {
                        self.navigationItem.title = text
                        (self.splitViewController as? DogeChatSplitViewController)?.findChatRoomVC()?.navigationItem.title = text
                    }
                }
            }
        }
    }
    
    func textFieldDidBeginEditing(cell: CommonTableCell) {
        
    }
    
    func updateMyNameInGroup(text: String) {
        manager?.myInfo.nameInGroupsDict?[friend.userID] = text
        self.myNameInGroup = text
        if let myself = self.members.first(where: { $0.userID == manager?.myInfo.userID} ) {
            myself.nameInGroup = text
            self.tableView.reloadData()
        }
    }

}
