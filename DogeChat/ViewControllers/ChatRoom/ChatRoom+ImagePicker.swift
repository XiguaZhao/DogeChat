//
//  ChatRoom+ImagePicker.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/15.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation

extension ChatRoomViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate, PHPickerViewControllerDelegate {

    @available(iOS 14, *)
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true) { [self] in
            if results.isEmpty { return }
            switch pickerPurpose {
            case .send:
                processingMedia(finished: false)
                let isLivePhotoOnly = picker.configuration.filter == .livePhotos
                self.messageSender.pickedLivePhotos.removeAll()
                if isLivePhotoOnly {
                    for result in results {
                        if result.itemProvider.canLoadObject(ofClass: PHLivePhoto.self) {
                            result.itemProvider.loadObject(ofClass: PHLivePhoto.self) {[self] livePhoto, error in
                                if let live = livePhoto as? PHLivePhoto {
                                    LivePhotoGenerator().generate(for: live, windowWidth: self.tableView.frame.width) { livePhoto, _, _ in
                                        let imageURL = livePhoto.value(forKey: "imageURL") as! URL
                                        let videoURL = livePhoto.value(forKey: "videoURL") as! URL
                                        self.messageSender.pickedLivePhotos = [(imageURL, videoURL, livePhoto.size, livePhoto)]
                                        self.sendLivePhotos()
                                    }
                                }
                            }
                            continue
                        }
                    }
                } else {
                    processItemProviders(results.map { $0.itemProvider })
                }
            case .addEmoji:
                messageSender.processItemProviders(results.map{ $0.itemProvider }, friends: [], emojiType: self.addEmojiType, completion: nil)
            }
        }
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        if let type = info[.mediaType] as? String, type == "public.movie" {
            if let videoURL = info[.mediaURL] as? URL {
                self.messageSender.compressAndSendVideo(videoURL, friends: [friend], completion: { [weak self] message in
                    self?.insertNewMessageCell(message)
                })
            }
            picker.dismiss(animated: true, completion: nil)
            return
        }
        guard let image = info[.originalImage] as? UIImage else {
            picker.dismiss(animated: true, completion: nil)
            return
        }
        var isGif = false
        var originalUrl: URL?
        processingMedia(finished: false)
        if imagePickerType.isImage {
            if let originalUrl_ = info[.imageURL] as? URL {
                isGif = originalUrl_.absoluteString.hasSuffix(".gif")
                originalUrl = originalUrl_
            }
            self.messageSender.latestPickedImageInfos = [(isGif ? (nil, originalUrl!, image.size) : compressImage(image))]
            picker.dismiss(animated: true) {
                guard !isGif && picker.sourceType != .camera else {
                    self.confirmSendPhoto()
                    return
                }
                let vc = ImageConfirmViewController()
                if let image = self.messageSender.latestPickedImageInfos.first?.image {
                    vc.image = image
                } else {
                    vc.image = image
                }
                self.navigationController?.pushViewController(vc, animated: true)
            }
        } else if imagePickerType == .livePhoto {
            picker.dismiss(animated: true, completion: nil)
            if let live = info[.livePhoto] as? PHLivePhoto {
                LivePhotoGenerator().generate(for: live, windowWidth: self.tableView.frame.width) { livePhoto, imageURL, videoURL in
                    self.messageSender.pickedLivePhotos = [(imageURL, videoURL, livePhoto.size, livePhoto)]
                    self.sendLivePhotos()
                }
            }
        }
    }
    
    

}
