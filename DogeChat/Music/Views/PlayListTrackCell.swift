//
//  FavoriteTrackCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/24.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatCommonDefines
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
        trackNameLabel.font = .preferredFont(forTextStyle: .body)
        artistLabel.font = .preferredFont(forTextStyle: .footnote)
        downloadProgress.isHidden = true
        downloadProgress.mas_makeConstraints { make in
            make?.height.mas_equalTo()(5)
        }
        let rightStack = UIStackView(arrangedSubviews: [trackNameLabel, artistLabel, downloadProgress])
        rightStack.axis = .vertical
        rightStack.spacing = 3
        let wholeStack = UIStackView(arrangedSubviews: [albumImageView, rightStack])
        wholeStack.alignment = .center
        wholeStack.spacing = 10
        contentView.addSubview(wholeStack)
        wholeStack.mas_makeConstraints { [weak self] make in
            make?.leading.equalTo()(self?.contentView)?.offset()(20)
            make?.trailing.equalTo()(self?.contentView)?.offset()(-60)
            make?.top.equalTo()(self?.contentView)?.offset()(tableViewCellTopBottomPadding)
            make?.bottom.equalTo()(self?.contentView)?.offset()(-tableViewCellTopBottomPadding)
            make?.height.mas_greaterThanOrEqualTo()(45)
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
        albumImageView.image = nil
    }
    
    func apply(track: Track) {
        self.track = track
        trackNameLabel.text = track.name
        artistLabel.text = track.artist
        if let cachedData = trackThumbCache.object(forKey: track.albumImageUrl as NSString) {
            syncOnMainThread {
                self.albumImageView.image = UIImage(data: cachedData as Data)
            }
        } else {
            SDWebImageManager.shared.loadImage(with: URL(string: track.albumImageUrl), options: .avoidDecodeImage, progress: nil) { image, data, _, _, _, _ in
                guard self.track == track, let image = image else { return }
                let imageData = compressEmojis(image, imageWidth: .width40).1
                self.albumImageView.image = UIImage(data: imageData)
                trackThumbCache.setObject(imageData as NSData, forKey: track.albumImageUrl as NSString)
            }
        }
        downloadProgress.isHidden = !(track.state == .downloading)
        artistLabel.isHidden = track.state == .downloading
        var image: UIImage?
        if track.isPlaying {
            if #available(iOS 13.0, *) {
                image = UIImage(systemName: "speaker.zzz.fill")
            } else {
                image = UIImage(named: "laba")
            }
        } else if track.isPaused {
            if #available(iOS 13.0, *) {
                image = UIImage(systemName: "pause.circle.fill")
            } else {
                image = UIImage(named: "zanting")
            }
        }
        if let image = image {
            let imageView = UIImageView(image: image)
            imageView.bounds = CGRect(x: 0, y: 0, width: 20, height: 20)
            self.accessoryView = imageView
        }
    }
    
}
