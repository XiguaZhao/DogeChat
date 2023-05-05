//
//  AppDelegate+Common.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/3/4.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatNetwork
import DogeChatCommonDefines

extension AppDelegate {
    
    func startBackgroundTask(socket: WebSocketManager?) {
        guard self.backgroundTaskID == nil else { return }
        self.backgroundTaskID = UIApplication.shared.beginBackgroundTask {
            self .stopBackgroundTask(socket: socket)
        }
    }
    
    func moveToContainerIfNeeded() {
        defer {
            UserDefaults.standard.set(true, forKey: "moveToContainer")
        }
        var need = true
#if os(watchOS)
        need = false
#endif
        if UserDefaults.standard.bool(forKey: "moveToContainer") {
            need = false
        }
        if !need { return }
        let url = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent(photoDir)
        let fm = FileManager.default
        let containerURL = createDir(name: photoDir)
        do {
            for item in try fm.contentsOfDirectory(atPath: url.filePath) {
                let newURL = containerURL.appendingPathComponent(item)
                let oldURL = url.appendingPathComponent(item)
                try? FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        } catch let error {
            print(error)
        }
    }
    
    func stopBackgroundTask(socket: WebSocketManager?) {
        print("任务到期")
        if let id = self.backgroundTaskID {
            self.backgroundTaskID = nil
            if UIApplication.shared.applicationState == .background {
                print("后台，socket断开")
                socket?.disconnect()
            }
            UIApplication.shared.endBackgroundTask(id)
        }
    }
        
    func registerMacOSBridge() {
        let bundleFileName = "MacOSBridge.bundle"
        guard let bundleURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent(bundleFileName),
        let bundle = Bundle(url: bundleURL) else {
            return
        }
        let className = "MacOSBridge.MacOSBridge"
        guard let bridgeClass = bundle.classNamed(className) as? Bridge.Type else {
            return
        }
        self.macOSBridge = bridgeClass.init()
        self.macOSBridge?.makeGlobalShortcut(with: "D")
        NotificationCenter.default.addObserver(forName: .shortcutChanged, object: nil, queue: nil) { [weak self] note in
            self?.macOSBridge?.makeGlobalShortcut(with: note.object as! String)
        }
    }
    
    @available(iOS 13.0, *)
    override func buildMenu(with builder: UIMenuBuilder) {
        guard builder.system == .main else {
            super.buildMenu(with: builder)
            return
        }
        builder.remove(menu: .text)
        builder.remove(menu: .edit)
//        builder.remove(menu: .file)
        builder.replaceChildren(ofMenu: .font) { exiting in
            let bigger = UIKeyCommand(input: "+", modifierFlags: .command, action: #selector(biggerFont))
            bigger.title = "增大"
            let smaller = UIKeyCommand(input: "-", modifierFlags: .command, action: #selector(smallerFont))
            smaller.title = "缩小"
            let `default` = UIKeyCommand(input: "0", modifierFlags: .command, action: #selector(defaultFont))
            `default`.title = "默认大小"
            return [bigger, smaller, `default`]
        }
    }
    
    @objc func biggerFont() {
        let oldValue = (UserDefaults.standard.value(forKey: "sizeCategory") as? UIContentSizeCategory) ?? .medium
        let newValue = getBiggerSizeCategoryForSizeCategory(oldValue)
        NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: nil, userInfo: [UIContentSizeCategory.newValueUserInfoKey : newValue])
        UserDefaults.standard.set(newValue, forKey: "sizeCategory")
    }
    
    @objc func smallerFont() {
        let oldValue = (UserDefaults.standard.value(forKey: "sizeCategory") as? UIContentSizeCategory) ?? .medium
        let newValue = getSmallerCategoryForSizeCategory(oldValue)
        NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: nil, userInfo: [UIContentSizeCategory.newValueUserInfoKey : newValue])
        UserDefaults.standard.set(newValue, forKey: "sizeCategory")
    }
    
    @objc func defaultFont() {
        NotificationCenter.default.post(name: UIContentSizeCategory.didChangeNotification, object: nil, userInfo: [UIContentSizeCategory.newValueUserInfoKey : UIContentSizeCategory.medium])
        UserDefaults.standard.set(UIContentSizeCategory.medium, forKey: "sizeCategory")
    }
    
}
