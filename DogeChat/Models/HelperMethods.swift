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

func playHaptic(_ intensity: CGFloat = 1) {
    HapticManager.shared.playHapticTransient(time: 0, intensity: Float(intensity), sharpness: 1)
}

var url_pre: String {
    WebSocketManager.url_pre
}

func socketForUsername(_ username: String) -> WebSocketManager? {
    return WebSocketManager.usersToSocketManager[username]
}

func removeSocketForUsername(_ username: String) {
    if let index = WebSocketManager.usersToSocketManager.firstIndex(where: { $0.key == username }) {
        WebSocketManager.usersToSocketManager.remove(at: index)
    }
    if let index = WebSocketManagerAdapter.usernameToAdapter.firstIndex(where: { $0.key == username }) {
        WebSocketManagerAdapter.usernameToAdapter.remove(at: index)
    }
    _ = SceneDelegate.usernameToDelegate.remove(key: username)
}

var safeArea: UIEdgeInsets {
    if ProcessInfo.processInfo.isMacCatalystApp {
        return .zero
    } else if #available(iOS 14, *), ProcessInfo.processInfo.isiOSAppOnMac {
        return .zero
    }
    return UIApplication.shared.keyWindow?.safeAreaInsets ?? .zero
}

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
    return ProcessInfo.processInfo.isMacCatalystApp
}

func isCatalyst() -> Bool {
    return ProcessInfo.processInfo.isMacCatalystApp
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

func windowForView(_ view: UIView) -> UIWindow? {
    return (view.window?.windowScene?.delegate as? SceneDelegate)?.window
}

func sceneDelegate() -> Any? {
    return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.delegate
}

func userIDFor(username: String) -> String? {
    return (UserDefaults.standard.value(forKey: usernameToIdKey) as? [String : String])?[username]
}

func adapterFor(username: String) -> WebSocketManagerAdapter {
    return WebSocketManagerAdapter.usernameToAdapter[username]!
}

func updateUsernames(_ username: String) {
    if let sceneDelegate = SceneDelegate.usernameToDelegate[username], let splitVC = sceneDelegate.splitVC {
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
