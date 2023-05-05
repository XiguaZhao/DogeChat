//
//  HelperMethods.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import Foundation
import DogeChatNetwork
import DogeChatUniversal
import UIKit
import DogeChatCommonDefines

var titleFont: UIFont {
    if !isMac() {
        return UIFont.preferredFont(forTextStyle: .body)
    } else {
        return .systemFont(ofSize: 16 * fontSizeScale)
    }
}

var subtitleFont: UIFont {
    if !isMac() {
        return .preferredFont(forTextStyle: .footnote)
    } else {
        return .systemFont(ofSize: 12 * fontSizeScale)
    }
}

var fontSizeScale: CGFloat = getScaleForSizeCategory((UserDefaults.standard.value(forKey: "sizeCategory") as? UIContentSizeCategory) ?? .medium)

func playHaptic(_ intensity: CGFloat = 1) {
    if #available(iOS 13.0, *) {
        HapticManager.shared.playHapticTransient(time: 0, intensity: Float(intensity), sharpness: 1)
    } 
}

var url_pre: String {
    WebSocketManager.url_pre
}

func socketForUsername(_ username: String) -> WebSocketManager? {
    if #available(iOS 13, *) {
        return WebSocketManager.usersToSocketManager[username]
    } else {
        return WebSocketManager.shared
    }
}

func removeSocketForUsername(_ username: String, removeScene: Bool = true) {
    if let index = WebSocketManager.usersToSocketManager.firstIndex(where: { $0.key == username }) {
        let socket = WebSocketManager.usersToSocketManager.remove(at: index)
        socket.value.disconnect()
    }
    if let index = WebSocketManagerAdapter.usernameToAdapter.firstIndex(where: { $0.key == username }) {
        WebSocketManagerAdapter.usernameToAdapter.remove(at: index)
    }
    if removeScene {
        if #available(iOS 13.0, *) {
            _ = SceneDelegate.usernameToDelegate.remove(key: username)
        } 
    }
}

var safeArea: UIEdgeInsets = .zero

func isLandscape() -> Bool {
    return UIDevice.current.orientation == .landscapeLeft || UIDevice.current.orientation == .landscapeRight
}

func isPad() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .pad
}

func isPhone() -> Bool {
    return UIDevice.current.userInterfaceIdiom == .phone
}

func isMac() -> Bool {
    if #available(iOS 14, *), ProcessInfo.processInfo.isiOSAppOnMac {
        return true
    }
    if #available(iOS 13.0, *) {
        return ProcessInfo.processInfo.isMacCatalystApp
    } else {
        return false
    }
}

func isCatalyst() -> Bool {
    if #available(iOS 13.0, *) {
        return ProcessInfo.processInfo.isMacCatalystApp
    } else {
        return false
    }
}

func makeToast(message: String, detail: String? = nil, showTime: TimeInterval = 0.5, completion: (() -> Void)? = nil) {
    var window: UIWindow?
    if #available(iOS 13, *) {
        window = UIApplication.shared.windows.first
    } else {
        window = UIApplication.shared.keyWindow
    }
    guard let window = window else { return }
    window.rootViewController?.makeAutoAlert(message: message, detail: detail, showTime: showTime, completion: completion)
}

public extension UIView {
    
    var left: CGFloat {
        get {
            return self.frame.origin.x
        }
        set {
            var frame = self.frame
            frame.origin.x = newValue
            self.frame = frame
        }
    }
        
    var right: CGFloat {
        get {
            return self.frame.maxX
        }
        set {
            var frame = self.frame
            frame.origin.x += (newValue - frame.maxX)
            self.frame = frame
        }
    }
        
    var top: CGFloat {
        get {
            return self.frame.origin.y
        }
        set {
            var frame = self.frame
            frame.origin.y = newValue
            self.frame = frame
        }
    }
    
    
    var bottom: CGFloat {
        get {
            return self.frame.maxY
        }
        set {
            frame.origin.y += (newValue - frame.maxY)
        }
    }
    
    var width: CGFloat {
        get {
            return self.frame.width
        }
        set {
            frame.size.width = newValue
        }
    }
    
    var height: CGFloat {
        get {
            return self.frame.height
        }
        set {
            frame.size.height = newValue
        }
    }
}

public extension UIViewController {
    func makeAutoAlert(message: String, detail: String?, showTime: TimeInterval, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: message, message: detail, preferredStyle: .alert)
            self.present(alert, animated: true) { 
                Timer.scheduledTimer(withTimeInterval: showTime, repeats: false) { (_) in
                    alert.dismiss(animated: true, completion: completion)
                }
            }
        }
    }
    
    func makeAlert(message: String, detail: String? = nil) -> UIAlertController {
        let alert = UIAlertController(title: message, message: detail, preferredStyle: .alert)
        return alert
    }
    
    func makeBrowser(paths: [String], targetIndex: Int = 0, purpose: MediaVCPurpose) {
        if !isMac() {
            let browser = MediaBrowserViewController()
            browser.imagePaths = paths
            browser.targetIndex = targetIndex
            browser.purpose = purpose
            browser.modalPresentationStyle = .fullScreen
            self.present(browser, animated: true, completion: nil)
        } else {
            if #available(iOS 13.0, *) {
                let option = UIScene.ActivationRequestOptions()
                option.requestingScene = self.view.window?.windowScene
                UIApplication.shared.requestSceneSessionActivation(nil, userActivity: ChatRoomViewController.wrapMediaBrowserUserActivity(paths: paths, targetIndex: targetIndex, purpose: purpose), options: option, errorHandler: nil)
            }
        }
    }
}

func getSizeFromViewSize(_ viewSize: CGSize, animateViewSize: CGSize) -> CGSize {
    let width: CGFloat
    let height: CGFloat
    if viewSize.width / viewSize.height > animateViewSize.width / animateViewSize.height {
        height = viewSize.height
        width = height * animateViewSize.width / animateViewSize.height
    } else {
        width = viewSize.width
        height = width * animateViewSize.height / animateViewSize.width
    }
    return CGSize(width: width, height: height)
}


public extension String {
    func image(size: CGSize = CGSize(width: 15, height: 15)) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        (self as NSString).draw(in: CGRect(origin: .zero, size: size), withAttributes: nil)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
}

public extension CGSize {
    func croppedRectangle() -> CGRect {
        let length = min(self.width, self.height)
        let bounds = CGRect(x: 0, y: 0, width: length, height: length)
        return CGRect(center: bounds.center, size: CGSize(width: length, height: length))
    }
}

func adapterFor(username: String) -> WebSocketManagerAdapter {
    return WebSocketManagerAdapter.usernameToAdapter[username]!
}

func updateUsernames(_ username: String) {
    var splitVC: UISplitViewController?
    if #available(iOS 13.0, *) {
        if let sceneDelegate = SceneDelegate.usernameToDelegate[username], let _splitVC = sceneDelegate.splitVC {
            splitVC = _splitVC
        }
    } else {
        if let _splitVC = UIApplication.shared.keyWindow?.rootViewController as? UISplitViewController {
            splitVC = _splitVC
        }
    }
    if let splitVC = splitVC {
        for vc in splitVC.viewControllers {
            updateUsernameForVC(vc, username: username)
        }
    }
}

func updateUsernameForVC(_ vc: UIViewController, username: String) {
    if let dogeChatVC = vc as? DogeChatViewController {
        dogeChatVC.username = username
    } else if let nav = vc as? UINavigationController {
        for vc in nav.viewControllers {
            updateUsernameForVC(vc, username: username)
        }
    } else if let tab = vc as? UITabBarController {
        for vc in tab.viewControllers ?? [] {
            updateUsernameForVC(vc, username: username)
        }
    }
}

func getUsernameForId(_ userID: String) -> String? {
    if let info = accountInfo(userID: userID) {
        return info.username
    }
    return nil
}

func getScaleForSizeCategory(_ sizeCategory: UIContentSizeCategory) -> CGFloat {
    let fontSizeScale: CGFloat
    switch sizeCategory {
    case .accessibilityExtraExtraExtraLarge:
        fontSizeScale = 3.1
    case .accessibilityExtraExtraLarge:
        fontSizeScale = 2.75
    case .accessibilityExtraLarge:
        fontSizeScale = 2.35
    case .accessibilityLarge:
        fontSizeScale = 1.9
    case .accessibilityMedium:
        fontSizeScale = 1.6
    case .extraExtraExtraLarge:
        fontSizeScale = 1.35
    case .extraExtraLarge:
        fontSizeScale = 1.2
    case .extraLarge:
        fontSizeScale = 1.1
    case .large:
        fontSizeScale = 1
    case .medium:
        fontSizeScale = 0.9
    case .small:
        fontSizeScale = 0.85
    case .extraSmall:
        fontSizeScale = 0.8
    default:
        fontSizeScale = 1
    }
    return fontSizeScale
}

func getBiggerSizeCategoryForSizeCategory(_ sizeCategory: UIContentSizeCategory) -> UIContentSizeCategory {
    switch sizeCategory {
    case .accessibilityExtraExtraExtraLarge:
        return .accessibilityExtraExtraExtraLarge
    case .accessibilityExtraExtraLarge:
        return .accessibilityExtraExtraExtraLarge
    case .accessibilityExtraLarge:
        return .accessibilityExtraExtraLarge
    case .accessibilityLarge:
        return .accessibilityExtraLarge
    case .accessibilityMedium:
        return .accessibilityLarge
    case .extraExtraExtraLarge:
        return .accessibilityMedium
    case .extraExtraLarge:
        return .extraExtraExtraLarge
    case .extraLarge:
        return .extraExtraLarge
    case .large:
        return .extraLarge
    case .medium:
        return .large
    case .small:
        return .medium
    case .extraSmall:
        return .small
    default:
        return .medium
    }
}

func getSmallerCategoryForSizeCategory(_ sizeCategory: UIContentSizeCategory) -> UIContentSizeCategory {
    switch sizeCategory {
    case .accessibilityExtraExtraExtraLarge:
        return .accessibilityExtraExtraLarge
    case .accessibilityExtraExtraLarge:
        return .accessibilityExtraLarge
    case .accessibilityExtraLarge:
        return .accessibilityLarge
    case .accessibilityLarge:
        return .accessibilityMedium
    case .accessibilityMedium:
        return .extraExtraExtraLarge
    case .extraExtraExtraLarge:
        return .extraExtraLarge
    case .extraExtraLarge:
        return .extraLarge
    case .extraLarge:
        return .large
    case .large:
        return .medium
    case .medium:
        return .small
    case .small:
        return .extraSmall
    case .extraSmall:
        return .extraSmall
    default:
        return .medium
    }
}
