//
//  MiniPlayerCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/30.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatUniversal

enum PlayMode {
    case normal
    case random
    case recycleOne
}

class MiniPlayerCell: DogeChatBaseCollectionViewCell {
    
    static let cellID = "MiniPlayerCell"
    
    let rotationAnimation: CABasicAnimation = {
        let animation = CABasicAnimation(keyPath: "transform.rotation.z")
        animation.byValue = 2 * Double.pi
        animation.repeatCount = MAXFLOAT
        animation.duration = 7
        animation.isRemovedOnCompletion = false
        return animation
    }()
    
    var track: Track!
    let albumImageView = UIImageView()
    let trackNameLabel = UILabel()
    let artistLabel = UILabel()
    var isRotating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        albumImageView.layer.masksToBounds = true
        albumImageView.layer.cornerRadius = 20
        trackNameLabel.font = .systemFont(ofSize: 15)
        artistLabel.font = .systemFont(ofSize: 12)
        let labelStack = UIStackView(arrangedSubviews: [trackNameLabel, artistLabel])
        labelStack.axis = .vertical
        labelStack.spacing = 2
        let stack = UIStackView(arrangedSubviews: [albumImageView, labelStack])
        stack.spacing = 20
        contentView.addSubview(stack)
        stack.mas_makeConstraints { [weak self] make in
            make?.centerY.equalTo()(self?.contentView)
            make?.leading.equalTo()(self?.contentView)?.offset()(20)
            make?.trailing.lessThanOrEqualTo()(self?.contentView)?.offset()(-80)
        }
        albumImageView.mas_makeConstraints { make in
            make?.width.mas_equalTo()(40)
            make?.height.mas_equalTo()(40)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        albumImageView.layer.removeAllAnimations()
        albumImageView.image = nil
    }
    
    func apply(track: Track) {
        self.track = track
        trackNameLabel.text = track.name
        artistLabel.text = track.artist
        if let imageData = trackThumbCache.object(forKey: track.albumImageUrl as NSString) {
            albumImageView.image = UIImage(data: imageData as Data)
        } else {
            SDWebImageManager.shared.loadImage(with: URL(string: track.albumImageUrl), options: .avoidDecodeImage, progress: nil) { image, _, _, _, _, _ in
                guard let image = image, self.track == track else { return }
                DispatchQueue.global().async {
                    let imageData = compressImage(image: image, needBig: false, askedSize: CGSize(width: 40, height: 40))
                    DispatchQueue.main.async {
                        self.albumImageView.image = UIImage(data: imageData)
                    }
                }
            }
        }
        updateRotation()
    }
    
    func updateRotation() {
        if track.isPlaying {
            albumImageView.layer.removeAllAnimations()
            addRotation()
            startRotation()
        }
    }
    
    func addRotation() {
        albumImageView.layer.add(rotationAnimation, forKey: "rotate")
    }
    
    func toggleRotation() {
        isRotating ? pauseRotation() : startRotation()
    }
    
    func pauseRotation() {
        let pauseTime = albumImageView.layer.convertTime(CACurrentMediaTime(), from: nil)
        albumImageView.layer.speed = 0
        albumImageView.layer.timeOffset = pauseTime
        isRotating = false
    }
    
    func startRotation() {
        let pauseTime = albumImageView.layer.timeOffset
        albumImageView.layer.speed = 1.0
        albumImageView.layer.timeOffset = 0.0
        albumImageView.layer.beginTime = 0.0
        let timeSincePause = albumImageView.layer.convertTime(CACurrentMediaTime(), from: nil) - pauseTime
        albumImageView.layer.beginTime = timeSincePause
        isRotating = true
    }

    
}
