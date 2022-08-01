//
//  DogeChat+MacOSBridge.swift
//  DogeChat
//
//  Created by ByteDance on 2022/7/15.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import AppKit

class MacOSBridge: NSObject, Bridge {
    
    var statusBarItem: NSStatusItem?
    var shortcut: MASShortcut?
    
    required override init() {
        super.init()
        
//        self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
//        self.statusBarItem.button?.title = "DogeChat"
//        self.statusBarItem.button?.target = self
//        self.statusBarItem.button?.action = #selector(self.onTapStatusIcon(_:))
    }
    
    func makeGlobalShortcut(with letter: String) {
        guard let keyCode = keyCodeFrom(letter) else { return }
        if let shortcut = shortcut {
            MASShortcutMonitor.shared().unregisterShortcut(shortcut)
        }
        self.shortcut = MASShortcut(keyCode: keyCode, modifierFlags:[NSEvent.ModifierFlags.command, NSEvent.ModifierFlags.control])
        MASShortcutMonitor.shared().register(shortcut) {
            if NSApplication.shared.isActive {
                NSApplication.shared.hide(nil)
            } else {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
        }
    }
    
    func updateUnreadCount(_ num: Int) {
        if num > 0 {
            self.statusBarItem?.button?.title = "Doge" + "(\(num))"
        } else {
            self.statusBarItem?.button?.title = "DogeChat"
        }
    }
    
    @objc func onTapStatusIcon(_ sender: NSStatusBarButton) {
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
    
    func keyCodeFrom(_ str: String) -> Int? {
        switch str.lowercased().first {
        case "a": return kVK_ANSI_A
        case "b": return kVK_ANSI_B
        case "c": return kVK_ANSI_C
        case "d": return kVK_ANSI_D
        case "e": return kVK_ANSI_E
        case "f": return kVK_ANSI_F
        case "g": return kVK_ANSI_G
        case "h": return kVK_ANSI_H
        case "i": return kVK_ANSI_I
        case "j": return kVK_ANSI_J
        case "k": return kVK_ANSI_K
        case "l": return kVK_ANSI_L
        case "m": return kVK_ANSI_M
        case "n": return kVK_ANSI_N
        case "o": return kVK_ANSI_O
        case "p": return kVK_ANSI_P
        case "q": return kVK_ANSI_Q
        case "r": return kVK_ANSI_R
        case "s": return kVK_ANSI_S
        case "t": return kVK_ANSI_T
        case "u": return kVK_ANSI_U
        case "v": return kVK_ANSI_V
        case "w": return kVK_ANSI_W
        case "x": return kVK_ANSI_X
        case "y": return kVK_ANSI_Y
        case "z": return kVK_ANSI_Z

        default: return nil
        }
    }
}
