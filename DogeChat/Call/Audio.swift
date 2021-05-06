//
//  Audio.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/22.
//  Copyright © 2021 Xiguang Zhao. All rights reserved.
//

import AVFoundation

func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    do {
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [])
    } catch (let error) {
        print("设置audio出错: \(error)")
    }
}

func startAudio() {
    print("start audio")
}

func stopAudio() {
    print("stop audio")
}
