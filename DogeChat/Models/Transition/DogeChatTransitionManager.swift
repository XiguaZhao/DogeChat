//
//  DogeChatTransitionManager.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/16.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

class DogeChatTransitionManager: NSObject, UIViewControllerTransitioningDelegate {
    
    static let shared = DogeChatTransitionManager()
    
    weak var interactiveVC: UIViewController?
    
    weak var fromDataSource: TransitionFromDataSource?
    weak var toDataSource: TransitionToDataSource?
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let interactiver = DogeChatInteractiveTransitioning()
        presented.dogechat_interactive = interactiver
        interactiver.addSwipeGesToVC(presented)
        self.interactiveVC = presented
        return DogeChatVCTransitioning(type: .present, fromDataSource: fromDataSource, toDataSource: toDataSource)
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard toDataSource?.transitionToView != nil else { return nil }
        self.fromDataSource = dismissed as? TransitionFromDataSource
        return DogeChatVCTransitioning(type: .dismiss, fromDataSource: fromDataSource, toDataSource: toDataSource)
    }
    
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        if let transitioning = animator as? DogeChatVCTransitioning {
            if transitioning.type == .dismiss {
                if let interactiveTransition = interactiveVC?.dogechat_interactive as? DogeChatInteractiveTransitioning {
                    return interactiveTransition.began ? interactiveTransition : nil
                }
            }
        }
        return nil
    }
    
}
