//
//  PTTViewController.swift
//  DogeChat
//
//  Created by ByteDance on 2022/8/10.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
#if !targetEnvironment(macCatalyst)
import PushToTalk
#endif
import DogeChatNetwork

@available(iOS 16.0, *)
class PTTViewController: DogeChatViewController, DogeChatVCTableDataSource {
    var tableView = DogeChatTableView()
#if !targetEnvironment(macCatalyst)

    let talkButton = UIButton()
    let inviteButton = UIButton()
    @objc let leaveButton = UIButton()
    var friends = [String]()
    let createNewChannelButton = UIButton()

    var manager: WebSocketManager? {
        return socketForUsername(username)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(tableView)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(CommonTableCell.self, forCellReuseIdentifier: CommonTableCell.cellID)

        tableView.mas_makeConstraints { make in
            make?.edges.equalTo()(self.view)
        }

        talkButton.setTitle("Talk", for: .normal)
        inviteButton.setTitle("Invite", for: .normal)
        inviteButton.addTarget(self, action: #selector(invite), for: .touchUpInside)
        leaveButton.setTitle("Stop", for: .normal)
        createNewChannelButton.setTitle("join", for: .normal)
        createNewChannelButton.addTarget(self, action: #selector(createNewChannel), for: .touchUpInside)
        talkButton.addTarget(self, action: #selector(talk), for: .touchUpInside)
        leaveButton.addTarget(self, action: #selector(leave), for: .touchUpInside)

        let stack = UIStackView(arrangedSubviews: [leaveButton, talkButton, createNewChannelButton]);
        stack.spacing = 30
        view.addSubview(stack)

        stack.mas_makeConstraints { make in
            make?.centerX.equalTo()(view)
            make?.bottom.equalTo()(view.mas_bottom)?.offset()(-100)
        }
        
    }

    @objc func invite() {
        let selectVC = SelectContactsViewController(username: self.username)
        selectVC.didSelectContacts = { [weak self] selectedFriends in
            self?.manager?.httpsManager.inviteFriendsToChannel(id: PTChannel.shared.uuid.uuidString, friendsIds: selectedFriends.map{ $0.userID }, completion: { success in
                print("ptt did invite \(success)")
            })
        }
        self.present(selectVC, animated: true)
    }

    @objc func createNewChannel() {
        PTChannel.shared.joinToChannel(id: nil, username: username, avatarUrl: nil)
    }

    @objc func talk() {
        PTChannel.shared.channelManager.requestBeginTransmitting(channelUUID: PTChannel.shared.uuid)
    }

    @objc func leave() {
        PTChannel.shared.channelManager.stopTransmitting(channelUUID: PTChannel.shared.uuid)
    }

#endif
}

#if !targetEnvironment(macCatalyst)
@available(iOS 16.0, *)
extension PTTViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return friends.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: CommonTableCell.cellID, for: indexPath) as! CommonTableCell
        cell.apply(title: friends[indexPath.row], subTitle: nil, imageURL: nil, trailingViewType: nil, trailingText: nil)
        return cell
    }

}
#endif
