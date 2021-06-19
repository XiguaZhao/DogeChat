//
//  HelperMethods.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/7.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import Foundation

public extension UIViewController {
    public func makeAlert(message: String, detail: String?, showTime: TimeInterval, completion: (() -> Void)?) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: message, message: detail, preferredStyle: .alert)
            self.present(alert, animated: true)
            Timer.scheduledTimer(withTimeInterval: showTime, repeats: false) { (_) in
                alert.dismiss(animated: true, completion: completion)
            }
        }
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
