//
//  UIImageView+Doge.swift
//  DogeChat
//
//  Created by 赵锡光 on 2026/3/7.
//  Copyright © 2026 Luke Parham. All rights reserved.
//

import UIKit

extension UIImageView {
    static var dogeLoadingURLStrKey: UInt8?
    var doge_loadingURLStr: String? {
        get {
            objc_getAssociatedObject(self, &Self.dogeLoadingURLStrKey) as? String
        }
        set {
            objc_setAssociatedObject(self, &Self.dogeLoadingURLStrKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }
}
