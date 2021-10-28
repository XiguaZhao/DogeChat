//
//  VoiceViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/20.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

protocol VoiceRecordDelegate: AnyObject {
    func voiceConfirmSend(_ url: URL, duration: Int)
}

class VoiceViewController: DogeChatViewController, AVAudioRecorderDelegate {
    
    var recorder: AVAudioRecorder!
    weak var delegate: VoiceRecordDelegate?
    let stopButton = UIButton()
    let playButton = UIButton()
    let sendButton = UIButton()
    var timer: CADisplayLink!
    let timeLabel = UILabel()
    var stack: UIStackView!
    let player = AVPlayer()
    var url: URL!
    var sendBlock: ((Bool) -> Void)?
    var playBlock: ((Bool) -> Void)?
    var saved = false
    var time: TimeInterval?
    let loudIndicator = UIProgressView()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        let buttonStack = UIStackView(arrangedSubviews: [stopButton, playButton, sendButton])
        buttonStack.spacing = 30
        stack = UIStackView(arrangedSubviews: [timeLabel, loudIndicator, buttonStack])
        stack.axis = .vertical
        stack.spacing = 30
        stack.alignment = .center
        view.addSubview(stack)
        
        if #available(iOS 13.0, *) {
            let largeConfig = UIImage.SymbolConfiguration(pointSize: 150, weight: .bold, scale: .large)
            stopButton.setImage(UIImage(systemName: "stop.circle.fill", withConfiguration: largeConfig), for: .normal)
            playButton.setImage(UIImage(systemName: "play.circle.fill", withConfiguration: largeConfig), for: .normal)
            sendButton.setImage(UIImage(systemName: "paperplane.circle.fill", withConfiguration: largeConfig), for: .normal)
        }

        stopButton.addTarget(self, action: #selector(stopAction(_:)), for: .touchUpInside)
        playButton.addTarget(self, action: #selector(playAction(_:)), for: .touchUpInside)
        sendButton.addTarget(self, action: #selector(sendAction(_:)), for: .touchUpInside)
        
        let width: CGFloat = 50
        
        stack.mas_makeConstraints { [weak self] make in
            make?.center.equalTo()(self?.view)
        }
        
        stopButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }
        
        playButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }

        sendButton.mas_makeConstraints { make in
            make?.width.height().mas_equalTo()(width)
        }
        
        loudIndicator.mas_makeConstraints { make in
            make?.width.mas_equalTo()(200)
        }
        
        let dirURL = createDir(name: "voice")
        let uuid = UUID().uuidString
        url = dirURL.appendingPathComponent(uuid).appendingPathExtension("m4a")
        guard let recorder = try? AVAudioRecorder(url: url, settings: [AVFormatIDKey: NSNumber(value: Int32(kAudioFormatMPEG4AAC)),
                                                                       AVSampleRateKey: 22050,
                                                        AVNumberOfChannelsKey: 1,
                                                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                                                        AVEncoderBitRateKey: 19200]) else {
            self.dismiss(animated: true, completion: nil)
            return
        }
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
        try? AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        self.recorder = recorder
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        recorder.prepareToRecord()
        recorder.record()
        
        timeLabel.text = "0 s"
        timeLabel.font = .boldSystemFont(ofSize: 30)
        timer = CADisplayLink(target: self, selector: #selector(updateUI))
        timer.add(to: RunLoop.main, forMode: .common)
        
    }
    
    deinit {
        timer?.invalidate()
        timer = nil
    }
    
    @objc func updateUI() {
        if time == nil {
            time = Date().timeIntervalSince1970
        }
        timeLabel.text = String(format: "%.2fs", recorder.currentTime)
        let nowPower = recorder.averagePower(forChannel: 0)
        let percent = (nowPower + 160) / 160
        loudIndicator.progress = percent
        recorder.updateMeters()
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        recorder.stop()
    }
    
    @objc func stopAction(_ sender: UIButton) {
        stopTimer()
    }

    @objc func playAction(_ sender: UIButton) {
        stopTimer()
        playBlock = { [weak self] success in
            guard let self = self, success else { return }
            self.player.replaceCurrentItem(with: AVPlayerItem(url: self.url))
            self.player.play()
        }
        if saved {
            playBlock?(true)
        }
    }

    @objc func sendAction(_ sender: UIButton) {
        stopTimer()
        sendBlock = { [weak self] success in
            guard let self = self, success else { return }
            self.delegate?.voiceConfirmSend(self.url, duration: Int(self.time ?? 0))
            self.dismiss(animated: true) {
                
            }
        }
        if saved {
            sendBlock?(true)
        }
    }
    
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        time = Date().timeIntervalSince1970 - time!
        saved = flag
        playBlock?(flag)
        sendBlock?(flag)
        playBlock = nil
        sendBlock = nil
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        
    }

}
