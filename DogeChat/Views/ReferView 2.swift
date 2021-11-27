//
//  ReferView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/17.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

protocol ReferViewDelegate: AnyObject {
    func referViewTapAction(_ referView: ReferView, message: Message?)
    func cancleAction(_ referView: ReferView)
}

enum ReferViewType {
    case inputView
    case chatRoomCell
}

class ReferView: UIView {
    
    static let height: CGFloat = 30
    static let margin: CGFloat = 5
    
    var needShow = false
    
    weak var delegate: ReferViewDelegate?
    var stackView: UIStackView!
    let nameLabel = UILabel()
    let imageView = UIImageView()
    let messageLabel = UILabel()
    let cancleButton = UIButton()
    var message: Message?
    let type: ReferViewType

    required init(type: ReferViewType) {
        self.type = type
        super.init(frame: .zero)
        self.layer.masksToBounds = true
        buildSubviews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func prepareForReuse() {
        imageView.image = nil
        nameLabel.text = nil
        messageLabel.text = nil
    }
    
    func buildSubviews() {
        let fontSize: CGFloat = 10
        stackView = UIStackView(arrangedSubviews: [cancleButton, nameLabel, messageLabel, imageView])
        stackView.spacing = 5
        stackView.alignment = .center
        nameLabel.font = .systemFont(ofSize: fontSize)
        messageLabel.font = .systemFont(ofSize: fontSize)
        messageLabel.lineBreakMode = .byTruncatingTail
        
        cancleButton.contentMode = .scaleAspectFit
        cancleButton.setImage(UIImage(named: "delete"), for: .normal)
        cancleButton.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)
        
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.layer.masksToBounds = true
        addSubview(stackView)
                
        nameLabel.setContentHuggingPriority(.required, for: .horizontal)
        nameLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        imageView.widthAnchor.constraint(lessThanOrEqualToConstant: Self.height - 2).isActive = true
        
        stackView.mas_makeConstraints { make in
            make?.leading.top().bottom().equalTo()(self)
            make?.trailing.lessThanOrEqualTo()(self)
        }
        
        cancleButton.mas_makeConstraints { make in
            make?.width.height().mas_lessThanOrEqualTo()(ReferView.height / 2)
        }
        
        stackView.isUserInteractionEnabled = true
        stackView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(stackViewTapAction)))
    }
    
    @objc func stackViewTapAction() {
        delegate?.referViewTapAction(self, message: message)
    }
    
    @objc func buttonAction() {
        delegate?.cancleAction(self)
    }
    
    func apply(message: Message) {
        needShow = true
        self.message = message
        var text: String?
        switch message.messageType {
        case .text:
            text = message.text
        case .image:
            makeImage()
        case .video:
            text = "[视频]"
        case .livePhoto:
            makeImage()
        case .draw:
            if #available(iOS 13, *) {
                makeDrawing()
            } else {
                text = "[Drawing]"
            }
        case .track:
            text = "[Tracks]"
        case .voice:
            text = message.text
        default:
            text = nil
        }
        nameLabel.text = message.senderUsername + "："
        messageLabel.isHidden = text == nil
        imageView.isHidden = text != nil
        if let text = text {
            messageLabel.text = text
        }
    }
    
    func makeImage() {
        let captured = self.message
        guard let imageURL = message?.imageURL else { return }
        MediaLoader.shared.requestImage(urlStr:imageURL,
                                        type: .image,
                                        syncIfCan: false,
                                        imageWidth: .width100,
                                        needStaticGif: true,
                                        needCache: true,
                                        completion: { image, data, _ in
            if captured == self.message {
                if let image = image {
                    self.imageView.image = image
                } else if let data = data {
                    self.imageView.image = UIImage(data: data)
                }
            }
        }, progress: nil)
    }
    
    @available(iOS 13, *)
    func makeDrawing() {
        let captured = self.message
        guard let url = message?.pkDataURL else { return }
        MediaLoader.shared.requestImage(urlStr: url,
                                        type: .draw,
                                        syncIfCan: true,
                                        completion: { _, _, localURL in
            if captured == self.message,
               let data = try? Data(contentsOf: localURL),
               let draw = try? PKDrawing(data: data) {
                let image = draw.image(from: draw.bounds, scale: 1)
                self.imageView.image = image
            }
        }, progress: nil)
    }

}
