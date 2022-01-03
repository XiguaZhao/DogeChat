//
//  ShareViewController.swift
//  DogeChatShare
//
//  Created by 赵锡光 on 2021/12/31.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import Social
import DogeChatUniversal
import RSAiOSWatchOS

class ShareViewController: SLComposeServiceViewController, KeyProvider {
            
    let httpMessage = HttpMessage()
    lazy var messageSender: MessageSender = {
        let sender = MessageSender()
        sender.manager = httpMessage.httpManager
        sender.clientKeyProvider = self
        sender.type = .shareExtension
        return sender
    }()
    
    
    var selectedFriends = [Friend]()
    
    var total = 0
    var completeCount = 0 {
        didSet {
            DispatchQueue.main.async { [self] in
                cell?.value = "\(completeCount)/\(total)"
                if completeCount == total {
                    self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            }
        }
    }
    
    weak var cell: SLComposeSheetConfigurationItem?
    
    func getClientPublicKey() -> String? {
        httpMessage.messageManager.encrypt.getPublicKey()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(self, selector: #selector(uploadSuccessNoti(_:)), name: .uploadSuccess, object: nil)
    }
    
    override func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        return true
    }

    override func didSelectPost() {
        // This is called after the user selects Post. Do the upload of contentText and/or NSExtensionContext attachments.
    
        // Inform the host that we're done, so it un-blocks its UI. Note: Alternatively you could call super's -didSelectPost, which will similarly complete the extension context.
        if total == 0 {
            send()
        }
    }
    
    @objc func uploadSuccessNoti(_ notification: Notification) {
        guard let message = notification.userInfo?["message"] as? Message else { return }
        message.text = message.text.replacingOccurrences(of: "+", with: "%2B")
        httpMessage.sendMessage(message) { success in
            self.completeCount += 1
        }
        
    }
    
    func send() {
        guard !selectedFriends.isEmpty else {
            self.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            return
        }
        var providers = [NSItemProvider]()
        for item in self.extensionContext!.inputItems {
            if let item = item as? NSExtensionItem, let _providers = item.attachments {
                providers += _providers
            }
        }
        var count = providers.count*selectedFriends.count
        if let text = self.contentText, !text.isEmpty {
            for friend in selectedFriends {
                count += 1
                if let message = messageSender.processMessageString(for: text, type: .text, friend: friend, imageURL: nil, videoURL: nil) {
                    httpMessage.sendMessage(message) { [weak self] success in
                        self?.completeCount += 1
                    }
                }
            }
        }
        self.total = count
        cell?.title = "正在发送"
        cell?.value = "0/\(count)"
        messageSender.processItemProviders(providers, friends: selectedFriends, completion: nil)
    }

    override func configurationItems() -> [Any]! {
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        let item = SLComposeSheetConfigurationItem()
        self.cell = item
        item?.title = "已选联系人"
        item?.value = "请选择"
        item?.tapHandler = { [weak self, weak item] in
            item?.value = "正在加载"
            self?.httpMessage.login { success in
                guard success else { return }
                self?.httpMessage.getContacts { friends in
                    if let friends = friends {
                        let vc = SelectContactsTVC()
                        vc.preferredContentSize = CGSize(width: UIScreen.main.bounds.width, height: 600)
                        vc.friends = friends
                        vc.didSelectContact = { selectedFriends in
                            self?.selectedFriends = selectedFriends
                            let text = selectedFriends.map({ $0.username }).joined(separator: "、")
                            item?.value = text
                        }
                        vc.didTapSend = { [weak self] in
                            self?.send()
                            self?.popConfigurationViewController()
                        }
                        self?.pushConfigurationViewController(vc)
                    }
                }
            }
        }
        return [item as Any]
    }
    

}

extension EncryptMessage: RSAEncryptProtocol {}
