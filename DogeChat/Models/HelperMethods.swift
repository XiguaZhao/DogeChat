//
//  HelperMethods.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatNetwork
import DogeChatUniversal

func playHaptic(_ intensity: CGFloat = 1) {
    if #available(iOS 13.0, *) {
        HapticManager.shared.playHapticTransient(time: 0, intensity: Float(intensity), sharpness: 1)
    }
}

var url_pre: String {
    WebSocketManager.url_pre
}

func socketForUsername(_ username: String) -> WebSocketManager {
    return WebSocketManager.usersToSocketManager[username]!
}

func removeSocketForUsername(_ username: String) {
    if let index = WebSocketManager.usersToSocketManager.firstIndex(where: { $0.key == username }) {
        WebSocketManager.usersToSocketManager.remove(at: index)
    }
    if let index = WebSocketManagerAdapter.usernameToAdapter.firstIndex(where: { $0.key == username }) {
        WebSocketManagerAdapter.usernameToAdapter.remove(at: index)
    }

}

var safeArea: UIEdgeInsets {
    UIApplication.shared.keyWindow!.safeAreaInsets
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
    return !AppDelegate.shared.isIOS
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
    if #available(iOS 13.0, *) {
        return (view.window?.windowScene?.delegate as? SceneDelegate)?.window
    } else {
        return AppDelegate.shared.window
    }
}

func sceneDelegate() -> Any? {
    if #available(iOS 13.0, *) {
        return UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.windowScene?.delegate
    } else {
        return nil
    }
}

func userIDFor(username: String) -> String? {
    return (UserDefaults.standard.value(forKey: usernameToIdKey) as? [String : String])?[username]
}

func adapterFor(username: String) -> WebSocketManagerAdapter {
    return WebSocketManagerAdapter.usernameToAdapter[username]!
}
