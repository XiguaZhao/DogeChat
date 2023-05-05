//
//  AppDelegate+PushToTalk.swift
//  DogeChat
//
//  Created by ByteDance on 2022/8/5.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import AVKit
import DogeChatNetwork
import DogeChatCommonDefines

#if !targetEnvironment(macCatalyst)
import PushToTalk
@available(iOS 16.0, *)
class PTChannel: NSObject, AVAudioRecorderDelegate, PTChannelManagerDelegate, PTChannelRestorationDelegate {

    var url: URL?
    var toPlayURL: URL?
    static var shared = PTChannel()
    
    var isAudioSessionActive = false

    var mySpeaking = false
    var username: String {
        return socketManager?.myName ?? ""
    }

    var recorder: AVAudioRecorder?
    var player: AVPlayer?

    var socketManager: WebSocketManager? {
        didSet {
            joinServer()
        }
    }
    var channelManager: PTChannelManager!
    var uuid = UUID(uuidString: "D7D809BA-097B-40E6-92AD-4698A70F7DD0")!
    var descriptor = PTChannelDescriptor(name: "赵锡光", image: nil)
    var pushToken: String? {
        didSet {
            joinServer()
        }
    }

    private override init() {
        super.init()
        Recorder.sharedInstance().uuid = self.uuid.uuidString
        Recorder.sharedInstance().audioType = .PTT
        PTChannelManager.channelManager(delegate: self, restorationDelegate: self, completionHandler: { manager, error in
            guard error == nil else { return }
            self.channelManager = manager
        })
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: nil, queue: .main) { _ in
            self.channelManager?.setActiveRemoteParticipant(nil, channelUUID: self.uuid)
            AppDelegate.shared.stopBackgroundTask(socket: self.socketManager)
        }
    }

    func channelManager(_ channelManager: PTChannelManager, didActivate audioSession: AVAudioSession) {
        isAudioSessionActive = true
        tryToPlay()
        print("PTT did active session")
        if mySpeaking {
            let dirURL = createDir(name: "voice")
            let uuid = UUID().uuidString
            self.url = dirURL.appendingPathComponent(uuid).appendingPathExtension("m4a")
            guard let recorder = try? AVAudioRecorder(url: self.url!, settings: [AVFormatIDKey: NSNumber(value: Int32(kAudioFormatMPEG4AAC)),
                                                                               AVSampleRateKey: 22050,
                                                                         AVNumberOfChannelsKey: 1,
                                                                      AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
                                                                           AVEncoderBitRateKey: 19200]) else {
                return
            }
            try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.allowBluetooth, .allowBluetoothA2DP])
            self.recorder = recorder
            recorder.delegate = self
            recorder.prepareToRecord()
            let success = recorder.record()
            print(success)
        }
    }

    func channelManager(_ channelManager: PTChannelManager, didDeactivate audioSession: AVAudioSession) {
        print("PTT did deactivate session")
        isAudioSessionActive = false
    }

    func channelDescriptor(restoredChannelUUID channelUUID: UUID) -> PTChannelDescriptor {
        self.uuid = channelUUID
        self.descriptor = PTChannelDescriptor(name: "赵锡光", image: nil)
        return self.descriptor
    }

    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didBeginTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("PTT did begin transmitting")
        mySpeaking = true
        AppDelegate.shared.startBackgroundTask(socket: self.socketManager)
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        guard flag, let url = self.url else {
            return
        }
        self.socketManager?.httpsManager.uploadPhoto(imageUrl: url, type: .voice, size: .zero, voiceDuration: 5, uploadProgress: nil, success: { serverURL in
            deleteFile(dirName: "voice", fileName: url.absoluteString.fileName)
            guard serverURL.isEmpty == false else { return }
            self.socketManager?.httpsManager.notifyChannel(id: self.uuid.uuidString, url: serverURL, completion: { success in
                print("PTT did notify \(success)")
                AppDelegate.shared.stopBackgroundTask(socket: nil)
            })
        }, fail: nil)
        self.url = nil
    }

    func channelManager(_ channelManager: PTChannelManager, channelUUID: UUID, didEndTransmittingFrom source: PTChannelTransmitRequestSource) {
        print("PTT did end transmitting")
        mySpeaking = false
        recorder?.stop()
    }

    func channelManager(_ channelManager: PTChannelManager, failedToStopTransmittingInChannel channelUUID: UUID, error: Error) {
        print("PTT did fail to stop transmitting")
    }

    func channelManager(_ channelManager: PTChannelManager, failedToLeaveChannel channelUUID: UUID, error: Error) {
        print("PTT did fail to leave")
    }

    func channelManager(_ channelManager: PTChannelManager, failedToJoinChannel channelUUID: UUID, error: Error) {
        print("PTT did fail to join")
    }

    func channelManager(_ channelManager: PTChannelManager, failedToBeginTransmittingInChannel channelUUID: UUID, error: Error) {
        print("PTT did fail to begin transmitting")
    }

    func channelManager(_ channelManager: PTChannelManager, didJoinChannel channelUUID: UUID, reason: PTChannelJoinReason) {
        print("PTT did Join")
        joinServer()
    }

    func channelManager(_ channelManager: PTChannelManager, didLeaveChannel channelUUID: UUID, reason: PTChannelLeaveReason) {
        print("PTT did leave")
        socketManager?.httpsManager.leaveChannel(id: channelUUID.uuidString, completion: { success in
            print("ptt did leave \(success)")
        })
    }

    func channelManager(_ channelManager: PTChannelManager, receivedEphemeralPushToken pushToken: Data) {
        print("PUSHTOKEN")
        let tokenString = pushToken.map { String(format: "%02.2hhx", $0) }.joined()
        self.pushToken = tokenString
        print(tokenString)

    }

    func incomingPushResult(channelManager: PTChannelManager, channelUUID: UUID, pushPayload: [String : Any]) -> PTPushResult {
        AppDelegate.shared.startBackgroundTask(socket: self.socketManager)
        channelManager.setActiveRemoteParticipant(nil, channelUUID: channelUUID)
        let speaker = (pushPayload["activeSpeaker"] as? String) ?? ""
        if let avatar = pushPayload["avatarUrl"] as? String {
            MediaLoader.shared.requestImage(urlStr: avatar, type: .photo) { image, _, _ in
                if let image = image {
                    channelManager.setActiveRemoteParticipant(PTParticipant(name: speaker, image: image), channelUUID: channelUUID)
                }
            }
        }
        if let url = pushPayload["url"] as? String {
            MediaLoader.shared.requestImage(urlStr: url, type: .voice) { _, _, localURL in
                self.toPlayURL = localURL
                self.tryToPlay()
            }
        }
        let participant = PTParticipant(name: speaker, image: nil)
        return PTPushResult.activeRemoteParticipant(participant)
    }
    
    func tryToPlay() {
        guard let toPlayURL = toPlayURL, self.isAudioSessionActive else { return }
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker)
        let item = AVPlayerItem(url: toPlayURL)
        self.player = AVPlayer(playerItem: item)
        self.player?.play()
        self.toPlayURL = nil
    }

    func joinServer() {
        if let pushToken = pushToken {
            socketManager?.httpsManager.joinChannel(id: self.uuid.uuidString, token: pushToken) { success in
                print("ptt did join \(success)")
            }
        }
    }

    func joinToChannel(id: String?, username: String, avatarUrl: String?) {
        if let id = id, let uuid = UUID(uuidString: id) {
            self.uuid = uuid
        }
        channelManager.requestJoinChannel(channelUUID: self.uuid, descriptor: PTChannelDescriptor(name: username, image: nil))
    }

    func processPTTInviteNotification() {
        if let channelId = UserDefaults(suiteName: groupName)?.value(forKey: "channelId") as? String {
            joinToChannel(id: channelId, username: socketManager?.myInfo.username ?? "", avatarUrl: nil)
            UserDefaults(suiteName: groupName)?.set(nil, forKey: "channelId")
        }
    }
    
    func setActiveSpeaker(_ name: String?, avatar: String?) {
        var participant: PTParticipant?
        if let name = name {
            participant = PTParticipant(name: name, image: nil)
        }
        channelManager.setActiveRemoteParticipant(participant, channelUUID: self.uuid)
    }
}

#endif

extension AppDelegate {
    func registerChannelManager() {
        #if !targetEnvironment(macCatalyst)
        if #available(iOS 16.0, *) {
//            PTChannel.shared.url = nil
        }
        #endif
    }
}

