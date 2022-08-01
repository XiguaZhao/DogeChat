//
//  MacOSBridge.swift
//  DogeChat
//
//  Created by ByteDance on 2022/7/15.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation

@objc(Bridge)
protocol Bridge: NSObjectProtocol {
    init()
    func updateUnreadCount(_ num: Int)
    func makeGlobalShortcut(with letter: String)
}
