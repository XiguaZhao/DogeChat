//
//  ContactCell.swift
//  DogeChatMac
//
//  Created by 赵锡光 on 2021/6/15.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import AppKit
import DogeChatUniversal
import DogeChatNetwork

class ContactCell: NSTableCellView {
    
    @IBOutlet weak var avatatImageView: NSImageView!
    @IBOutlet weak var latestMessageLabel: NSTextField!
    @IBOutlet weak var nameLabel: NSTextField!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        NSLayoutConstraint(item: avatatImageView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30).isActive = true
        NSLayoutConstraint(item: avatatImageView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 30).isActive = true
    }
    
    func apply(info: UserInfo) {
        nameLabel.stringValue = info.name
        if let content = info.latestMessage?.message {
            latestMessageLabel.stringValue = content
        } else {
            latestMessageLabel.removeFromSuperview()
        }
        let urlStr = WebSocketManager.shared.url_pre + info.avatarUrl
        if let url = URL(string: urlStr) {
            URLSession.shared.dataTask(with: url) { data, _, _ in
                if let data = data {
                    avatarCache[urlStr] = data
                    DispatchQueue.main.async { [self] in
                        guard let layer = avatatImageView.layer else { return }
                        avatatImageView.animates = true
                        avatatImageView.image = NSImage(data: data)
                        layer.cornerRadius = 30 / 2
                        layer.masksToBounds = true
                    }
                }
            }.resume()
        }
    }
}
