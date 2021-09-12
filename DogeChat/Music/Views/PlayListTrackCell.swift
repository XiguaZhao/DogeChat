//
//  FavoriteTrackCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/24.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import DogeChatNetwork

class PlayListTrackCell: UITableViewCell {

    static let cellID = "FavoriteTrackCell"
    var track: Track!
    let albumImageView = UIImageView()
    let trackNameLabel = UILabel()
    let artistLabel = UILabel()
    let downloadProgress = UIProgressView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .clear
        albumImageView.contentMode = .scaleAspectFill
        albumImageView.layer.masksToBounds = true
        albumImageView.layer.cornerRadius = 6
        albumImageView.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(40)
        }
        trackNameLabel.font = .systemFont(ofSize: 17)
        artistLabel.font = .systemFont(ofSize: trackNameLabel.font.pointSize - 3)
        downloadProgress.isHidden = true
        downloadProgress.mas_makeConstraints { make in
            make?.height.mas_equalTo()(5)
            make?.width.mas_equalTo()(300)
        }
        let rightStack = UIStackView(arrangedSubviews: [trackNameLabel, artistLabel, downloadProgress])
        rightStack.axis = .vertical
        rightStack.spacing = 3
        let wholeStack = UIStackView(arrangedSubviews: [albumImageView, rightStack])
        wholeStack.spacing = 10
        wholeStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(wholeStack)
        wholeStack.mas_makeConstraints { [weak self] make in
            make?.centerY.equalTo()(self?.contentView)
            make?.leading.equalTo()(self?.contentView)?.offset()(20)
            make?.trailing.equalTo()(self?.contentView)?.offset()(-60)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        downloadProgress.isHidden = false
        self.accessoryView = nil
    }
    
    func apply(track: Track) {
        self.track = track
        trackNameLabel.text = track.name
        artistLabel.text = track.artist
        if let cachedData = trackThumbCache.object(forKey: track.albumImageUrl as NSString) {
            DispatchQueue.main.async {
                self.albumImageView.image = UIImage(data: cachedData as Data)
            }
        } else {
            SDWebImageManager.shared.loadImage(with: URL(string: track.albumImageUrl), options: .avoidDecodeImage, progress: nil) { image, data, _, _, _, _ in
                guard let image = image else { return }
                let imageData = compressEmojis(image, askedSize: CGSize(width: 40, height: 40))
                self.albumImageView.image = UIImage(data: imageData)
                trackThumbCache.setObject(imageData as NSData, forKey: track.albumImageUrl as NSString)
            }
        }
        downloadProgress.isHidden = !(track.state == .downloading)
        artistLabel.isHidden = track.state == .downloading
        if #available(iOS 13.0, *) {
            var image: UIImage?
            if track.isPlaying {
                image = UIImage(systemName: "speaker.zzz.fill")
            } else if track.isPaused {
                image = UIImage(systemName: "pause.circle.fill")
            }
            if let image = image {
                self.accessoryView = UIImageView(image: image)
            }
        }
    }
    
}
