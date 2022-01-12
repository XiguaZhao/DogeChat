//
//  ProfileVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/19.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatCommonDefines
import DogeChatNetwork
import SwiftyJSON

class ProfileVC: DogeChatViewController, DogeChatVCTableDataSource, UITableViewDataSource, UITableViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    
    
    enum ProfileCellType: String {
        case avatar = "头像"
        case username = "用户名"
        case email = "注册邮箱"
        case createTime = "创建时间"
        case userID = "用户ID"
        case blurImage = "自定义毛玻璃"
        case trailer = "Trailers"
        case customizedColors = "自定义颜色"
    }
    
    var manager: WebSocketManager? {
        (self.splitViewController as? DogeChatSplitViewController)?.findContactVC()?.manager
    }
    
    var tableView: DogeChatTableView = DogeChatTableView()
    let sections: [[ProfileCellType]] = [
        [.avatar],
        [.username, .userID, .email, .createTime, .blurImage, .trailer,. customizedColors]
    ]
    var info: AccountInfo?

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        
        tableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }
        
        tableView.register(ProfileAvatarCell.self, forCellReuseIdentifier: ProfileAvatarCell.cellID)
        tableView.register(CommonTableCell.self, forCellReuseIdentifier: CommonTableCell.cellID)
        tableView.dataSource = self
        tableView.delegate = self
        
        makeRequest()
    }
    
    func makeRequest() {
        self.manager?.httpsManager.getProfile({ info in
            self.info = info
            self.tableView.reloadData()
        })
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = sections[indexPath.section]
        let row = section[indexPath.row]
        var cellID = CommonTableCell.cellID
        let title = row.rawValue
        var trailingType: CommonTableCell.TrailingViewType?
        var trailingText: String?
        var imageURL: String?
        switch row {
        case .avatar:
            cellID = ProfileAvatarCell.cellID
        case .username:
            trailingType = .textField
            trailingText = info?.username
        case .createTime:
            trailingType = .label
            trailingText = info?.createTime
        case .email:
            trailingType = .label
            trailingText = info?.email
        case .userID:
            trailingType = .label
            trailingText = info?.userID
        case .blurImage:
            imageURL = info?.backgroudImage
        case .trailer:
            if let firstTrack = allTracks.first {
                trailingType = .label
                trailingText = firstTrack.name + "等\(allTracks.count)首"
            }
        case .customizedColors:
            break
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        if let avatarCell = cell as? ProfileAvatarCell {
            avatarCell.apply(url: info?.avatarURL)
        } else if let userInfoCell = cell as? CommonTableCell? {
            userInfoCell?.apply(title: title, subTitle: nil, imageURL: imageURL, trailingViewType: trailingType, trailingText: trailingText, switchOn: nil, imageIsLeft: false)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.sections[section].count
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let type = sections[indexPath.section][indexPath.row]
        if type == .avatar {
            changeAvatar()
        } else if type == .customizedColors {
            
        }
        if let cell = tableView.cellForRow(at: indexPath) as? CommonTableCell {
            var text: String?
            switch cell.trailingType {
            case .label:
                text = cell.trailingLabel.text
            case .textField:
                text = cell.textField.text
            default:
                break
            }
            if let text = text {
                self.makeAutoAlert(message: "已复制", detail: text, showTime: 0.3, completion: nil)
                UIPasteboard.general.string = text
            }
        }
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        self.setEditing(false, animated: true)
    }
    
    func changeAvatar() {
        let picker = UIImagePickerController()
        picker.allowsEditing = true
        picker.delegate = self
        self.present(picker, animated: true, completion: nil)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true, completion: nil)
        guard let manager = manager, let image = info[.editedImage] as? UIImage else { return }
        if let compressedImageData = compressImage(image, needSave: false).image.jpegData(compressionQuality: 0.3) {
            manager.uploadData(compressedImageData, path: "user/changeAvatar", name: "avatar", fileName: UUID().uuidString + ".jpeg", needCookie: true, contentType: "multipart/form-data", params: nil) { task, data in
                guard let data = data else { return }
                let json = JSON(data)
                if json["status"].stringValue == "success" {
                    self.makeAutoAlert(message: "修改成功", detail: nil, showTime: 0.3, completion: nil)
                    let url = json["avatarUrl"].stringValue
                    manager.httpsManager.accountInfo.avatarURL = url
                    self.makeRequest()
                }
            }
        }
    }

}
