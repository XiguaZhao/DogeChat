//
//  UIBarButtonItem+Badge.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/3.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import Foundation
import UIKit

extension UIBarButtonItem {
    
    func makeDot() {
        if let dot = findDot() {
            dot.isHidden = false
            return 
        }
        let view = self.customView ?? (self.value(forKey: "view") as? UIView)
        if let view = view {
            var button: UIView?
            for subview in view.subviews {
                if subview is UIButton {
                    button = subview
                    break
                }
            }
            if let button = button {
                let width: CGFloat = 5
                let dot = UILabel()
                button.addSubview(dot)
                dot.backgroundColor = .red
                dot.layer.cornerRadius = width / 2
                dot.layer.masksToBounds = true
                dot.translatesAutoresizingMaskIntoConstraints = false
                NSLayoutConstraint.activate([
                    dot.widthAnchor.constraint(equalToConstant: width),
                    dot.heightAnchor.constraint(equalToConstant: width),
                    dot.trailingAnchor.constraint(equalTo: button.trailingAnchor, constant: 0),
                    dot.topAnchor.constraint(equalTo: button.topAnchor, constant: 0)
                ])
            }
        }
    }
    
    func hideDot() {
        findDot()?.isHidden = true
    }
    
    private func findDot() -> UIView? {
        let view = self.customView ?? (self.value(forKey: "view") as? UIView)
        if let view = view {
            var button: UIView?
            for subview in view.subviews {
                if subview is UIButton {
                    button = subview
                    break
                }
            }
            if let button = button {
                for subview in button.subviews {
                    if subview is UILabel {
                        return subview
                    }
                }
            }
        }
        return nil
    }

}
