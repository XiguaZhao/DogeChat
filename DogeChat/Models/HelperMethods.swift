//
//  HelperMethods.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation
import DogeChatNetwork

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
    func image() -> UIImage {
        let size = CGSize(width: 15, height: 15)
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        (self as NSString).draw(in: CGRect(origin: .zero, size: size), withAttributes: nil)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
}

func socketForUsername(_ username: String) -> WebSocketManager {
    return WebSocketManager.shared.usersToSocketManager[username]!
}

func adapterForUsername(_ username: String) -> WebSocketManagerAdapter {
    return WebSocketManagerAdapter.shared.usernameToAdapter[username]!
}

func windowForView(_ view: UIView) -> UIWindow? {
    if #available(iOS 13.0, *) {
        return (view.window?.windowScene?.delegate as? SceneDelegate)?.window
    } else {
        return AppDelegate.shared.window
    }
}
