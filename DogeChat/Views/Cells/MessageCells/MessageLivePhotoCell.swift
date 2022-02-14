//
//  MessageLivePhotoCell.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/19.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal
import PhotosUI
import DogeChatCommonDefines

class MessageLivePhotoCell: MessageImageKindCell, PHLivePhotoViewDelegate {

    static let cellID = "MessageLivePhotoCell"
    
    var livePhotoView = PHLivePhotoView()
    let livePhotoBadgeView = UIImageView()

    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        addMainView(livePhotoView)
                
        livePhotoView.layer.masksToBounds = true
        livePhotoView.addSubview(livePhotoBadgeView)
        livePhotoBadgeView.image = PHLivePhotoView.livePhotoBadgeImage(options: .overContent)
        livePhotoBadgeView.mas_makeConstraints { [weak self] make in
            make?.leading.top().equalTo()(self?.livePhotoView)?.offset()(5)
        }
        livePhotoView.delegate = self
        addGestureForLivePhotoView()

        endDisplayBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.livePhotoView.stopPlayback()
        }
        resignCenterBlock = { [weak self] _, _ in
            guard let self = self else { return }
            self.livePhotoView.stopPlayback()
        }
        centerDisplayBlock = { [weak self] _ , _ in
            guard let self = self else { return }
            self.livePhotoView.startPlayback(with: .full)
        }

    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        livePhotoView.livePhoto = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard message != nil else { return }
        layoutImageKindView()
        layoutIndicatorViewAndMainView()
    }
    
    override func apply(message: Message) {
        super.apply(message: message)
        makeLivePhoto()
    }
    
    func playLivePhoto() {
        self.livePhotoView.isMuted = true
        self.livePhotoView.startPlayback(with: .full)
    }

    func makeLivePhoto() {
        let capturedMessage = message
        let block: (PHLivePhoto, Bool) -> Void = { [weak self] livePhoto, playNow in
            guard let self = self else { return }
            guard capturedMessage == self.message else { return }
            syncOnMainThread {
                self.livePhotoView.livePhoto = livePhoto
                if playNow {
                    self.playLivePhoto()
                }
            }
        }
        let size = sizeForImageOrVideo(message) ?? CGSize(width: 100, height: 100)
        let livePhotoLoadBlock: (URL, URL, Bool) -> Void = { [weak self] localImageURL, localVideoURL, playNow in
            guard let self = self else { return }
            let width = self.tableView!.frame.width
            PHLivePhoto.request(withResourceFileURLs: [
                localImageURL, localVideoURL]
                                , placeholderImage: nil, targetSize: CGSize(width: width, height: width / size.width * size.height), contentMode: .aspectFit) { live, info in
                if let livePhoto = live, info[PHLivePhotoInfoErrorKey] == nil {
                    if let degrade = info[PHLivePhotoInfoIsDegradedKey] as? Int, degrade == 1 {
                        return
                    } else if let cancel = info[PHLivePhotoInfoCancelledKey] as? Int, cancel == 1 {
                        return
                    } else {
                        block(livePhoto, playNow)
                    }
                }
            }
        }
        guard let imagePath = message.imageURL,
              let videoPath = message.videoURL, !imagePath.isEmpty, !videoPath.isEmpty else { return }
        if let live = message.livePhoto as? PHLivePhoto, message.sendStatus == .fail {
            block(live, false)
        } else if let localImageURL = fileURLAt(dirName: livePhotoDir, fileName: imagePath.fileName), let localVideoURL = fileURLAt(dirName: livePhotoDir, fileName: videoPath.fileName) {
            livePhotoLoadBlock(localImageURL, localVideoURL, false)
        } else {
            MediaLoader.shared.requestImage(urlStr: imagePath, type: .livePhoto, cookie: cookie, syncIfCan: true) { _, _, localPathImage in
                print("liveImageDone")
                MediaLoader.shared.requestImage(urlStr: videoPath, type: .livePhoto, cookie: self.cookie, syncIfCan: true) { [weak self] _, _, localPathVideo in
                    self?.delegate?.downloadSuccess(self, message: capturedMessage!)
                    NotificationCenter.default.post(name: .mediaDownloadFinished, object: capturedMessage?.text, userInfo: nil)
                } progress: { [weak self] progress in
                    self?.delegate?.downloadProgressUpdate(progress: progress, messages: [capturedMessage!])
                }
                
            } progress: { _ in
                
            }
        }
    }
    
    func addGestureForLivePhotoView() {
        livePhotoView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(livePhotoTapped))
        livePhotoView.addGestureRecognizer(tap)
    }

    @objc func livePhotoTapped() {
        delegate?.mediaViewTapped(self, path: message.text, isAvatar: false)
    }

    func livePhotoView(_ livePhotoView: PHLivePhotoView, willBeginPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
    }
    
    func livePhotoView(_ livePhotoView: PHLivePhotoView, didEndPlaybackWith playbackStyle: PHLivePhotoViewPlaybackStyle) {
    }

    
}
