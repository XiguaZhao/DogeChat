//
//  DogeChatBlurView.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/27.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatBlurView: DogeChatBaseView {
    
    var blurView: UIView!
    weak var vc: DogeChatViewController?
    var isAnimating = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.addObserver(self, forKeyPath: "frame", options: [.new, .old], context: nil)
        self.addObserver(self, forKeyPath: "center", options: [.new, .old], context: nil)
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "frame")
        self.removeObserver(self, forKeyPath: "center")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
    }
    
    func updateBlurView(frame: CGRect, needAnimation: Bool = true) {
        guard !isAnimating else { return }
        if !needAnimation {
            self.blurView?.removeFromSuperview()
            if let portion = (self.vc?.navigationController as? DogeChatNavigationController)?.blurView?.resizableSnapshotView(from: frame, afterScreenUpdates: false, withCapInsets: .zero) {
                portion.frame = CGRect(origin: .zero, size: self.frame.size)
                self.addSubview(portion)
                self.sendSubviewToBack(portion)
                self.blurView = portion
                isAnimating = false
                return
            }
        }
        if AppDelegate.shared.immersive {
            isAnimating = true
            UIView.animate(withDuration: 0.55) { [weak self] in
                guard let blurView = self?.blurView else { return }
                blurView.alpha = 0
            } completion: { [weak self] finished in
                guard let self = self else { return }
                self.isAnimating = false
                self.blurView?.removeFromSuperview()
                if let portion = (self.vc?.navigationController as? DogeChatNavigationController)?.blurView?.resizableSnapshotView(from: self.frame, afterScreenUpdates: false, withCapInsets: .zero) {
                    portion.frame = CGRect(origin: .zero, size: self.frame.size)
                    self.addSubview(portion)
                    self.sendSubviewToBack(portion)
                    self.blurView = portion
                    portion.alpha = 0
                    self.isAnimating = true
                    UIView.animate(withDuration: 0.5) {
                        portion.alpha = 1
                    } completion: { _ in
                        self.isAnimating = false
                    }
                }
            }
        } else {
            self.isAnimating = true
            UIView.animate(withDuration: 0.5) { [weak self] in
                self?.blurView?.alpha = 0
            } completion: { [weak self] _ in
                self?.blurView?.removeFromSuperview()
                self?.blurView = nil
                self?.isAnimating = false
            }

        }
    }
    
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        var same = false
        if keyPath == "frame" {
            same = change![.oldKey] as! CGRect == change![.newKey] as! CGRect
        } else if keyPath == "center" {
            same = change![.oldKey] as! CGPoint == change![.newKey] as! CGPoint
        }
        if !same {
            updateBlurView(frame: self.frame, needAnimation: false)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func forceDarkMode(noti: Notification) {
        super.forceDarkMode(noti: noti)
        DispatchQueue.main.async{
            self.updateBlurView(frame: self.frame)
        }
    }

}
