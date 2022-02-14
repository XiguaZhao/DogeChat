//
//  DogeChatInteractiveTransitioning.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/17.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

@objc class DogeChatInteractiveTransitioning: UIPercentDrivenInteractiveTransition {
    
    let backPercentage: CGFloat = 0.3
    let backVelocity: CGFloat = 400
    var pan: UIPanGestureRecognizer!
    var began = false
    
    private var percent: CGFloat = 0
    private var v: CGFloat = 0
    private var beginV: CGFloat = 0
    private weak var vc: UIViewController?
    private var displayLink: CADisplayLink!
    
    func addSwipeGesToVC(_ vc: UIViewController) {
        pan = UIPanGestureRecognizer(target: self, action: #selector(onPan(_:)))
        vc.view.addGestureRecognizer(pan)
        self.vc = vc
    }
    
    @objc func onPan(_ ges: UIPanGestureRecognizer) {
        let translation = ges.translation(in: pan.view).y
        if ges.state == .changed {
            percent = translation / (ges.view?.bounds.width ?? UIScreen.main.bounds.width)
        }
        switch ges.state {
        case .began:
            began = true
            self.vc?.dismiss(animated: true, completion: nil)
            beginV = pan.velocity(in: pan.view).y
        case .changed:
            if percent * beginV >= 0 {
                percent = abs(percent)
                update(percent)
            } else {
                percent = 0
                update(percent)
            }
        case .ended, .cancelled:
            began = false
            percent = abs(percent)
            v = pan.velocity(in: pan.view).y
            continueAction()
        default:
            break
        }
    }
        
    func continueAction() {
        if displayLink == nil {
            displayLink = CADisplayLink(target: self, selector: #selector(UIChange(displayLink:)))
            displayLink.add(to: .current, forMode: .common)
        }
    }
    
    @objc func UIChange(displayLink: CADisplayLink) {
        let timeDistance = 1/(CGFloat(UIScreen.main.maximumFramesPerSecond) * DogeChatVCTransitioning.duration)
        if (beginV * v > 0) {
            v = abs(v)
            beginV = abs(beginV)
            if (percent > backPercentage || v > backVelocity) {
                percent += timeDistance
            } else {
                percent -= timeDistance
            }
        } else {
            percent -= timeDistance
        }
        update(percent)
        if percent >= 1 {
            self.finish()
            displayLink.invalidate()
            self.displayLink = nil
        }
        if percent <= 0 {
            self.cancel()
            displayLink.invalidate()
            self.displayLink = nil
        }
    }
}
