//
//  MessageCollectionViewTrackCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/28.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork

let sharedTracksImageCache = NSCache<NSString, NSData>()

func compressImage(image: UIImage, needBig: Bool, askedSize: CGSize?) -> Data {
    return WebSocketManager.shared.messageManager.compressEmojis(image, needBig: needBig, askedSize: askedSize)
}

class MessageCollectionViewTrackCell: MessageCollectionViewBaseCell {
    
    static let cellID = "MessageCollectionViewTrackCell"
    let firstLineLabel = UILabel()
    let secondLineLabel = UILabel()
    let bgImageView = UIImageView()
    let playButton = UIButton()
    let dontShow = false
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        if dontShow {
            timeLabel.isHidden = true
            avatarImageView.isHidden = true
            return
        }
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .regular))
        bgImageView.addSubview(blurView)
        bgImageView.contentMode = .scaleAspectFill
        bgImageView.layer.masksToBounds = true
        bgImageView.layer.cornerRadius = 10
        blurView.mas_makeConstraints { [weak self] make in
            make?.edges.equalTo()(self?.bgImageView)
        }
        let tap = UITapGestureRecognizer(target: self, action: #selector(bgImageTapAction(_:)))
        bgImageView.addGestureRecognizer(tap)
        if #available(iOS 13.0, *) {
            playButton.setImage(UIImage(systemName: "play.circle.fill"), for: .normal)
        } else {
            playButton.setTitle("▶️", for: .normal)
        }
        let stackView = UIStackView(arrangedSubviews: [firstLineLabel, secondLineLabel])
        firstLineLabel.font = .systemFont(ofSize: 15)
        secondLineLabel.font = .systemFont(ofSize: 12)
        stackView.axis = .vertical
        stackView.spacing = 5
        bgImageView.addSubview(stackView)
        bgImageView.addSubview(playButton)
        bgImageView.isUserInteractionEnabled = true
        playButton.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        playButton.mas_makeConstraints { [weak self] make in
            make?.centerY.equalTo()(self?.bgImageView)
            make?.trailing.equalTo()(self?.bgImageView)?.offset()(-20)
        }
        stackView.mas_makeConstraints { [weak self] make in
            make?.centerY.equalTo()(self?.bgImageView)
            make?.leading.equalTo()(self?.bgImageView)?.offset()(20)
            make?.trailing.equalTo()(self?.playButton)?.offset()(-20)
        }
        contentView.addSubview(bgImageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        if dontShow { return }
        layoutSharedTracksView()
        indicationNeighborView = bgImageView
        layoutIndicatorViewAndMainView()
    }
    
    func layoutSharedTracksView() {
        bgImageView.bounds = CGRect(x: 0, y: 0, width: 260, height: 80)
    }
    
    @objc func playAction(_ sender: UIButton) {
        message.isPlaying = !message.isPlaying
        PlayerManager.shared.playingMessage = message
        setButtonImage()
    }
    
    @objc func bgImageTapAction(_ tap: UITapGestureRecognizer) {
        delegate?.sharedTracksTap(self, tracks: message.tracks)
    }
    
    func setButtonImage() {
        if #available(iOS 13.0, *) {
            playButton.setImage(UIImage(systemName: message.isPlaying ? "pause.circle.fill" : "play.circle.fill"), for: .normal)
        } else {
            playButton.setTitle(message.isPlaying ? "⏸" : "▶️", for: .normal)
        }
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        if dontShow { return }
        setButtonImage()
        let captured = message
        if !message.tracks.isEmpty {
            let tracks = message.tracks
            firstLineLabel.text = tracks[0].name
            if tracks.count == 1 {
                secondLineLabel.text = tracks[0].artist
            } else {
                secondLineLabel.text = "共\(tracks.count)首，点击查看"
            }
            if let imageData = sharedTracksImageCache.object(forKey: tracks[0].albumImageUrl as NSString) {
                bgImageView.image = UIImage(data: imageData as Data)
                return
            }
            SDWebImageManager.shared.loadImage(with: URL(string: tracks[0].albumImageUrl), options: .avoidDecodeImage, progress: nil) { [weak self] image, _, _, _, _, _ in
                guard let image = image else { return }
                DispatchQueue.global().async {
                    let compressed = compressImage(image: image, needBig: false, askedSize: CGSize(width: 100, height: 100))
                    DispatchQueue.main.async {
                        self?.bgImageView.image = UIImage(data: compressed)
                    }
                    sharedTracksImageCache.setObject(compressed as NSData, forKey: tracks[0].albumImageUrl as NSString)
                }
            }
        } else {
            if !message.isDownloading {
                message.isDownloading = true
                if let url = URL(string: url_pre + message.message) {
                    session.get(url.absoluteString, parameters: nil, headers: nil, progress: nil, success: { task, data in
                        guard let tracksData = data as? Data,
                              let tracks = try? JSONDecoder().decode([Track].self, from: tracksData) else { return }
                        captured.tracks = tracks
                        captured.isDownloading = false
                        DispatchQueue.main.async {
                            if captured == self.message {
                                self.apply(message: message)
                            }
                        }
                    }, failure: nil)
                }
            }
        }
    }
}
