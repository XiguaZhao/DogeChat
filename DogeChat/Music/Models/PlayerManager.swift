//
//  PlayerManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/25.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import DogeChatUniversal
import MediaPlayer
import DogeChatNetwork

enum BlurImageSource {
    case customBlur
    case albumImage
}

class PlayerManager: NSObject {
    
    static let shared = PlayerManager()
    var isMute = false
    var player = AVPlayer()
    var playMode: PlayMode = .normal
    var interruptTime = Date().timeIntervalSince1970
    var playingMessage: Message? {
        willSet {
            guard newValue != playingMessage else { return }
            playingMessage?.isPlaying = false
            if let chatVC = AppDelegate.shared.navigationController.visibleViewController as? ChatRoomViewController {
                DispatchQueue.main.async {
                    chatVC.tableView.reloadData()
                }
            }
        }
        didSet {
            guard oldValue != playingMessage else {
                toggle()
                return
            }
            if let firstTrack = playingMessage?.tracks.first {
                playingList = playingMessage!.tracks
                playTrack(firstTrack)
            }
        }
    }
    var nowPlayingTrack: Track! {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .nowPlayingTrackChanged, object: self.nowPlayingTrack)
            }
        }
    }
    var blurSource: BlurImageSource = .customBlur
    weak var blurView: UIImageView?
    var hasActiveSession = false
    var playingList = [Track]() {
        didSet {
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .nowPlayingListChanged, object: self.playingList)
            }
        }
    }
    var currentPlayerItem: AVPlayerItem? {
        willSet {
            if let item = currentPlayerItem {
                item.removeObserver(self, forKeyPath: #keyPath(AVPlayerItem.status))
            }
        }
        didSet {
            currentPlayerItem?.addObserver(self, forKeyPath: #keyPath(AVPlayerItem.status), options: [.old, .new], context: nil)
        }
    }
    var isPlaying = false {
        didSet {
            DispatchQueue.main.async {
                miniPlayerView.toggle(begin: self.isPlaying)
                miniPlayerView.changePlayPauseButton()
            }
        }
    }
    var customImage: UIImage! {
        didSet {
            if customImage != nil {
                self.makeBluBg()
            } else {
                NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
            }
        }
    }
    
    var nowAlbumImage: UIImage! {
        didSet {
            if nowAlbumImage != nil {
                DispatchQueue.main.async {
                    self.updateNowPlayingCenter()
                    if UserDefaults.standard.bool(forKey: "immersive") {
                        self.makeBluBg()
                    }
                }
            } else {
                NotificationCenter.default.post(name: .immersive, object: false)
            }
        }
    }
    
    override init() {
        super.init()
//        NotificationCenter.default.addObserver(self, selector: #selector(trackPlayToEndNoti(_:)), name: .AVPlayerItemDidPlayToEndTime, object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(handleInterruption(notification:)), name: AVAudioSession.interruptionNotification, object: nil)
        makeSliderForRemoteControl()
    }
    
    func playTrack(_ track: Track, newestURL: URL? = nil) {
        track.playTime += 1
        DispatchQueue.global().async {
            saveTracksInfoToDisk()
        }
        nowPlayingTrack = track
        var url: URL?
        if track.isDownloaded {
            url = fileURLAt(dirName: tracksDirName, fileName: track.id + ".mp3")
            track.state = .downloaded
        } else {
            if let newestURL = newestURL {
                url = newestURL
            } else {
                MusicHttpManager.shared.getTrackWithID(track.id, source: track.source) { tracks in
                    if let track = tracks.first {
                        self.playTrack(track, newestURL: URL(string: track.musicLinkUrl))
                    }
                }
            }
        }
        if let url = url {
            let item = AVPlayerItem(url: url)
            player = AVPlayer(playerItem: item)
            player.play()
            isPlaying = true
            currentPlayerItem = item
            if !hasActiveSession {
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .allowAirPlay])
                hasActiveSession = true
                try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
            }
            UIApplication.shared.beginReceivingRemoteControlEvents()
            //设置图片
            SDWebImageManager.shared.loadImage(with: URL(string: track.albumImageUrl), options: .avoidDecodeImage, progress: nil) { image, data, _, _, _, _ in
                guard let image = image else { return }
                if image.size.width <= 400 {
                    self.nowAlbumImage = image
                } else {
                    let compressed = WebSocketManager.shared.messageManager.compressEmojis(image, needBig: false, askedSize: CGSize(width: 400, height: 400))
                    self.blurSource = .albumImage
                    self.nowAlbumImage = UIImage(data: compressed)
                }
            }
        }
    }
    
    func pause() {
        player.pause()
        isPlaying = false
        deactivateSession()
        DispatchQueue.global().async {
            if let url = fileURLAt(dirName: "customBlur", fileName: userID),
               let data = try? Data(contentsOf: url) {
                DispatchQueue.main.async {
                    PlayerManager.shared.customImage = UIImage(data: data)
                }
            }
        }
        NotificationCenter.default.post(name: .immersive, object: AppDelegate.shared.immersive)
    }
    
    func deactivateSession() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
            if !self.isPlaying {
                do {
                    try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                    self.hasActiveSession = false
                } catch _ {
                    self.deactivateSession()
                }
            }
        }
    }
    
    @objc func handleInterruption(notification: Notification) {
        guard let userInfo = notification.userInfo,
        let interruptionTypeRawValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
            let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeRawValue)
        else {
            return
        }
        switch interruptionType {
        case .began:
            interruptTime = Date().timeIntervalSince1970
            toggle()
        case .ended:
            if UIApplication.shared.applicationState == .background {
                toggle()
            }
        default: break
        }
    }
    
    func continuePlay() {
        player.play()
        isPlaying = true
        NotificationCenter.default.post(name: .immersive, object: true)
    }
    
    func playNextTrack(completion: ((Bool)->Void)? = nil) {
        if let nowTrack = nowPlayingTrack, let nowIndex = playingList.firstIndex(where: {nowTrack.id == $0.id}), nowIndex + 1 < playingList.count {
            playTrack(playingList[nowIndex + 1])
            completion?(true)
        } else {
            completion?(false)
        }
    }
    
    func playPreviousTrack() {
        if let nowTrack = nowPlayingTrack, let nowIndex = playingList.firstIndex(where: {nowTrack.id == $0.id}), nowIndex - 1 >= 0 {
            playTrack(playingList[nowIndex - 1])
        }
    }
    
    func toggle() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .toggleTrack, object: self.nowPlayingTrack)
        }
        if isPlaying {
            pause()
        } else {
            continuePlay()
        }
    }
    
    func trackDidDownload(track: Track) -> URL? {
        if let url = fileURLAt(dirName: tracksDirName, fileName: track.id + ".mp3") {
            return url
        } else {
            return nil
        }
    }
    
    func makeBluBg() {
        NotificationCenter.default.post(name: .immersive, object: true)
    }
    
    func updateNowPlayingCenter() {
        if nowAlbumImage == nil { return }
        guard nowPlayingTrack != nil else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: nowPlayingTrack.name,
            MPMediaItemPropertyArtist: nowPlayingTrack.artist,
            MPMediaItemPropertyArtwork: MPMediaItemArtwork(boundsSize: nowAlbumImage.size, requestHandler: { [self] (size) -> UIImage in
                let imageData = WebSocketManager.shared.messageManager.compressEmojis(nowAlbumImage, needBig: false, askedSize: size)
                return UIImage(data: imageData)!
            }),
            MPMediaItemPropertyPlaybackDuration: CMTimeGetSeconds(player.currentItem?.duration ?? CMTime(seconds: 99, preferredTimescale: 1)),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: player.currentItem?.currentTime().seconds ?? 0,
        ]
    }
    
    func makeSliderForRemoteControl() {
        let center = MPRemoteCommandCenter.shared()
        center.changePlaybackPositionCommand.isEnabled = true
        center.nextTrackCommand.isEnabled = true
        center.previousTrackCommand.isEnabled = true
        center.playCommand.isEnabled = true
        center.pauseCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget(self, action: #selector(remoteControlSliderAction(_:)))
        center.nextTrackCommand.addTarget(self, action: #selector(remoteControlNextAction(_:)))
        center.previousTrackCommand.addTarget(self, action: #selector(remoteControlPreviousAction(_:)))
        center.playCommand.addTarget(self, action: #selector(remoteControlToggleAction(_:)))
        center.pauseCommand.addTarget(self, action: #selector(remoteControlToggleAction(_:)))
    }
    
    @objc func remoteControlPreviousAction(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        playPreviousTrack()
        return .success
    }

    @objc func remoteControlNextAction(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        playNextTrack()
        return .success
    }

    @objc func remoteControlToggleAction(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        toggle()
        return .success
    }
    
    @objc func remoteControlSliderAction(_ event: MPChangePlaybackPositionCommandEvent) -> MPRemoteCommandHandlerStatus {
        let time = event.positionTime
        player.seek(to: CMTime(seconds: time, preferredTimescale: 1))
        return .success
    }
    
    @objc func playerItemStateChange(_ noti: Notification) {
        
    }
    
    @objc func trackPlayToEndNoti(_ noti: Notification) {
        playNextTrack() { [weak self] success in
            if !success {
                self?.deactivateSession()
                self?.isPlaying = false
                self?.nowPlayingTrack = nil
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        guard let item = object as? AVPlayerItem, item == currentPlayerItem else { return }
        if keyPath == #keyPath(AVPlayerItem.status) {
            let status: AVPlayerItem.Status
                if let statusNumber = change?[.newKey] as? NSNumber {
                    status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
                } else {
                    status = .unknown
                }

                switch status {
                case .readyToPlay:
                    DispatchQueue.main.async {
                        self.updateNowPlayingCenter()
                    }
                default:
                    playFail(track: nowPlayingTrack)
                }
            }
    }
    
    func playFail(track: Track) {
        let alert = UIAlertController(title: "播放失败", message: "可能没有音乐源，是否删除", preferredStyle: .alert)
        let confirm = UIAlertAction(title: "确定删除", style: .default) {  _ in
            NotificationCenter.default.post(name: .deleteTrack, object: track)
        }
        let cancel = UIAlertAction(title: "取消", style: .cancel, handler: nil)
        alert.addAction(confirm)
        alert.addAction(cancel)
        AppDelegate.shared.splitViewController.present(alert, animated: true, completion: nil)
    }
    
}

extension Track {
    var isPlaying: Bool {
        return PlayerManager.shared.nowPlayingTrack == self && PlayerManager.shared.isPlaying
    }
    
    var isPaused: Bool {
        return PlayerManager.shared.nowPlayingTrack == self && !PlayerManager.shared.isPlaying
    }
    
    var isDownloaded: Bool {
        return fileURLAt(dirName: tracksDirName, fileName: self.id + ".mp3") != nil
    }
}

func makeBlurViewForViewController(_ vc: UIViewController, blurView: inout UIImageView!, needAnimation: Bool = true, addToThisView: UIView? = nil) {
    var targetImage: UIImage?
    if UserDefaults.standard.bool(forKey: "immersive") && PlayerManager.shared.nowAlbumImage != nil && PlayerManager.shared.isPlaying {
        targetImage = PlayerManager.shared.nowAlbumImage
    } else if fileURLAt(dirName: "customBlur", fileName: userID) != nil && PlayerManager.shared.customImage != nil {
        targetImage = PlayerManager.shared.customImage
    }
    guard let targetImage = targetImage else { return }
    if #available(iOS 13.0, *) {
        let interfaceStyle: UIUserInterfaceStyle
        if UserDefaults.standard.bool(forKey: "forceDarkMode") {
            interfaceStyle = .dark
        } else {
            interfaceStyle = .unspecified
        }
        AppDelegate.shared.window?.overrideUserInterfaceStyle = interfaceStyle
        vc.navigationController?.overrideUserInterfaceStyle = interfaceStyle
        vc.splitViewController?.overrideUserInterfaceStyle = interfaceStyle
        vc.tabBarController?.overrideUserInterfaceStyle = interfaceStyle
        vc.overrideUserInterfaceStyle = interfaceStyle

        vc.view.backgroundColor = .clear
    }
    vc.view.backgroundColor = .clear
    var style: UIBlurEffect.Style
    if UserDefaults.standard.bool(forKey: "forceDarkMode") {
        style = .dark
    } else {
        style = .regular
    }
    if style == .regular && UIScreen.main.traitCollection.userInterfaceStyle == .light {
        if #available(iOS 13.0, *) {
            style = .extraLight
        }
    }
    if blurView == nil {
        blurView = UIImageView(image: targetImage)
        PlayerManager.shared.blurView = blurView
        blurView.alpha = 0
        blurView.isHidden = false
        blurView.contentMode = .scaleAspectFill
        let blurEffect = UIBlurEffect(style: style)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        blurView.addSubview(blurEffectView)
        blurEffectView.mas_updateConstraints { make in
            make?.edges.equalTo()(blurView)
        }
        blurView.layer.masksToBounds = true
        let view = vc.view
        if let askedView = addToThisView as? UITableView {
            askedView.backgroundView = blurView
            blurView.frame = askedView.frame
        } else {
            if let view = view {
                view.addSubview(blurView)
                view.sendSubviewToBack(blurView)
                blurView.mas_updateConstraints { [weak view] make in
                    make?.edges.equalTo()(view)
                }
            }
        }
        if needAnimation {
            UIView.animate(withDuration: 0.5) { [weak blurView] in
                blurView?.alpha = 1
            }
        } else {
            blurView.alpha = 1
        }
    } else {
        blurView.isHidden = false
        for view in blurView.subviews {
            if let blurEffectView = view as? UIVisualEffectView {
                blurEffectView.effect = UIBlurEffect(style: style)
                break
            }
        }
        UIView.animate(withDuration: 0.5) { [weak blurView] in
            blurView?.alpha = 0.5
        } completion: { [weak blurView] _ in
            blurView?.image = targetImage
            UIView.animate(withDuration: 0.5) { [weak blurView] in
                blurView?.alpha = 1
            }
        }
    }
}

func recoverVC(_ vc: UIViewController, blurView: inout UIImageView!) {
    if #available(iOS 13.0, *) {
        vc.view.backgroundColor = .systemBackground
        AppDelegate.shared.window?.overrideUserInterfaceStyle = .unspecified
        vc.navigationController?.overrideUserInterfaceStyle = .unspecified
        vc.splitViewController?.overrideUserInterfaceStyle = .unspecified
        vc.tabBarController?.overrideUserInterfaceStyle = .unspecified
        vc.overrideUserInterfaceStyle = .unspecified
        vc.view.backgroundColor = .systemBackground
    }
    UIView.animate(withDuration: 0.5) { [weak blurView] in
        blurView?.alpha = 0
    } completion: { [weak blurView] _ in
        blurView?.isHidden = true
    }
}

extension AVPlayer {
}
