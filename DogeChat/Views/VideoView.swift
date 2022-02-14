//
//  VideoView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/8/26.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

protocol VideoViewDelegate: AnyObject {
    func videoView(_ videoView: VideoView, onPlay: UIButton)
    func videoView(_ videoView: VideoView, onPause: UIButton)
    func videoView(_ videoView: VideoView, onSlider: UISlider, value: Float)
}

class VideoView: UIView {
    
    var isPlaying = false {
        didSet {
            if self.type == .mediaBrowser {
                if isPlaying {
                    PlayerManager.shared.playerTypes.insert(self.type)
                }
            }
            DispatchQueue.main.async {
                self.processHiddenVideoButton()
            }
        }
    }
    var videoEnd = false

    var item: DogeChatPlayerItem! {
        didSet {
            item?.registerNotification(keyPath: "status", object: self)
        }
    }
    
    let slider = UISlider()
    let pauseButton = UIButton()
    let playButton = UIButton()
    var stack: UIStackView!
    let durationLabel = UILabel()
    
    var doubleTap: UITapGestureRecognizer!
    
    var type = PlayerType.chatroomVideoCell {
        didSet {
            if type == .mediaBrowser {
                stack.isHidden = false
            }
        }
    }
            
    private var timer: Timer?
    
    weak var delegate: VideoViewDelegate?

    override class var layerClass: AnyClass {
        return AVPlayerLayer.self
    }

    var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        set {
            playerLayer.player = newValue
        }
    }
    
    var playerLayer: AVPlayerLayer {
        return layer as! AVPlayerLayer
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.stack = UIStackView(arrangedSubviews: [playButton, pauseButton, slider, durationLabel])
        stack.alignment = .center
        stack.spacing = 15
        stack.isHidden = true
        self.addSubview(stack)
        
        playButton.setImage(UIImage(named: "play"), for: .normal)
        pauseButton.setImage(UIImage(named: "pause"), for: .normal)
        
        doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapAction(_:)))
        doubleTap.numberOfTapsRequired = 2
        self.addGestureRecognizer(doubleTap)
        
        durationLabel.font = .preferredFont(forTextStyle: .footnote)
        durationLabel.textColor = .systemBlue
        
        slider.addTarget(self, action: #selector(onSliderChange(_:)), for: .valueChanged)
        slider.addTarget(self, action: #selector(onSliderUp(_:)), for: .touchUpInside)
        
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor, constant: 10),
            stack.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor, constant: -10),
            stack.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -10),
            stack.heightAnchor.constraint(equalToConstant: 50)
        ])
        
        [playButton, pauseButton].forEach { button in
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
            button.setContentCompressionResistancePriority(.required, for: .vertical)
            button.mas_makeConstraints { make in
                make?.width.height().mas_equalTo()(30)
            }
            button.addTarget(self, action: #selector(onTap(button:)), for: .touchUpInside)
        }
        
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { [weak self] noti in
            if noti.object as? AVPlayerItem != self?.item {
                return
            }
            self?.isPlaying = false
            self?.videoEnd = true
            if self?.type == .mediaBrowser {
                self?.doubleTapAction(nil)
            }
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    deinit {
        cancleTimer()
        if let item = self.item {
            item.removeObserver(self, forKeyPath: "status")
        }
    }
    
    @objc func onTap(button: UIButton) {
        playHaptic()
        timeChange()
        if button == playButton {
            delegate?.videoView(self, onPlay: button)
            switchVideo(play: true)
        } else {
            delegate?.videoView(self, onPause: button)
            switchVideo(play: false)
        }
    }
    
    func timeChange() {
        if let item = self.player?.currentItem {
            let now = CMTimeGetSeconds(item.currentTime())
            if !now.isNaN {
                slider.value = Float(now)
            }
        }
    }
    
    func setDuration(_ duration: Float) {
        slider.minimumValue = 0
        slider.maximumValue = duration
        durationLabel.text = duration.toTimeFormat()
        createTimer()
    }
    
    func createTimer() {
        slider.value = 0
        cancleTimer()
        DispatchQueue.main.async {
            self.timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { [weak self] _ in
                self?.timeChange()
            })
            self.timer?.tolerance = 1
        }
    }
    
    func cancleTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    func processHiddenVideoButton() {
        self.playButton.isHidden = isPlaying
        self.pauseButton.isHidden = !isPlaying
    }
    
    @objc func doubleTapAction(_ ges: UITapGestureRecognizer!) {
        if isPlaying {
            switchVideo(play: false)
        } else {
            if videoEnd {
                player?.seek(to: .zero)
                switchVideo(play: true)
                videoEnd = false
            } else {
                switchVideo(play: true)
            }
        }
        timeChange()
    }
    
    func switchVideo(play: Bool, needAnimation: Bool = true) {
        if play {
            player?.play()
            isPlaying = true
            videoEnd = false
        } else {
            player?.pause()
            isPlaying = false
        }
        self.processHiddenVideoButton()
    }
    
    func showSliderAnimated(_ animated: Bool, show: Bool, delay: Double) {
        let autoHidden = { [weak self] in
            if show {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    UIView.animate(withDuration: 0.3) {
                        self?.stack.alpha = 0
                    }
                }
            }
        }
        if !animated {
            stack.alpha = show ? 1 : 0
            autoHidden()
            return
        }
        stack.alpha = show ? 0 : 1
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            UIView.animate(withDuration: 0.3, animations: {
                self?.stack.alpha = show ? 1 : 0
            }, completion: { _ in
                autoHidden()
            })
        }
    }


    @objc func onSliderChange(_ sender: UISlider) {
        player?.seek(to: CMTime(seconds: Double(sender.value), preferredTimescale: 1))
        switchVideo(play: false, needAnimation: false)
        stack.alpha = 1
        self.delegate?.videoView(self, onSlider: sender, value: sender.value)
    }
    
    @objc func onSliderUp(_ sender: UISlider) {
        playHaptic()
        switchVideo(play: true)
        showSliderAnimated(false, show: true, delay: 0)
    }
    
    func playerPlay() {
        
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let item = object as? AVPlayerItem, item == self.item {
            if keyPath == "status" {
                let status: AVPlayerItem.Status
                if let statusNumber = change?[.newKey] as? NSNumber {
                    status = AVPlayerItem.Status(rawValue: statusNumber.intValue)!
                } else {
                    status = .unknown
                }
                if status == .readyToPlay {
                    DispatchQueue.main.async {
                        self.setDuration(Float(CMTimeGetSeconds(item.duration)))
                    }
                }
            }
        }
    }


}
