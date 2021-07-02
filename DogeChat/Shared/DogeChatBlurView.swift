//
//  DogeChatBlurView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/27.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatBlurView: DogeChatBaseView {
    
    var blurView: UIView!
    weak var vc: DogeChatViewController?
    var dontUpdate = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addObserver(self, forKeyPath: "frame", options: [.new], context: nil)
        self.addObserver(self, forKeyPath: "center", options: [.new], context: nil)
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
    }
    
    func updateBlurView(frame: CGRect, needAnimation: Bool = true) {
        guard !dontUpdate else { return }
        if AppDelegate.shared.immersive {
            UIView.animate(withDuration: 0.55) { [weak self] in
                guard let blurView = self?.blurView else { return }
                blurView.alpha = 0
            } completion: { [weak self] _ in
                guard let self = self else { return }
                self.blurView?.removeFromSuperview()
                if let portion = self.vc?.blurView?.resizableSnapshotView(from: self.frame, afterScreenUpdates: false, withCapInsets: .zero) {
                    portion.frame = CGRect(origin: .zero, size: self.frame.size)
                    self.addSubview(portion)
                    self.sendSubviewToBack(portion)
                    self.blurView = portion
                    portion.alpha = 0
                    UIView.animate(withDuration: 0.5) {
                        portion.alpha = 1
                    } completion: { _ in
                        
                    }
                }
            }
        } else {
            UIView.animate(withDuration: 0.5) { [weak self] in
                self?.blurView?.alpha = 0
            } completion: { [weak self] _ in
                self?.blurView?.removeFromSuperview()
                self?.blurView = nil
            }

        }
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        updateBlurView(frame: self.frame, needAnimation: false)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func forceDarkMode(noti: Notification) {
        super.forceDarkMode(noti: noti)
        if self is MiniPlayerView {
            return
        }
        DispatchQueue.main.async{
            self.updateBlurView(frame: self.frame)
        }
    }

}
