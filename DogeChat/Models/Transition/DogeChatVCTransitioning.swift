//
//  DogeChatVCTransitioning.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/16.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

protocol TransitionFromDataSource: AnyObject {
    var transitionSourceView: UIView! { get set }
    var transitionFromCornerRadiusView: UIView? { get set }
    var transitionPreferDuration: TimeInterval? { get }
    var transitionPreferDamping: CGFloat? { get }
}

protocol TransitionToDataSource: AnyObject {
    var transitionToView: UIView! { get set }
    var transitionToRadiusView: UIView? { get set }
}

class DogeChatVCTransitioning: NSObject, UIViewControllerAnimatedTransitioning {
    
    static let duration: TimeInterval = 0.55
    let damping: CGFloat = 0.7
    let initialV: CGFloat = 0.55
    let options: UIView.AnimationOptions = []
    
    weak var fromDataSource: TransitionFromDataSource?
    weak var toDataSource: TransitionToDataSource?
    
    enum TransitionType {
        case present
        case dismiss
    }
    
    var type: TransitionType = .present
    
    convenience init(type: TransitionType, fromDataSource: TransitionFromDataSource?, toDataSource: TransitionToDataSource?) {
        self.init()
        self.type = type
        self.fromDataSource = fromDataSource
        self.toDataSource = toDataSource
    }
    
    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if let toVC = transitionContext.viewController(forKey: .to) {
            toVC.view.frame = transitionContext.finalFrame(for: toVC)
        }
        if type == .present {
            present(transitionContext: transitionContext)
        } else {
            dismiss(transitionContext: transitionContext)
        }
    }
    
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return getDuration()
    }
    
    func getDamping() -> CGFloat {
        return self.fromDataSource?.transitionPreferDamping ?? self.damping
    }
    
    func getDuration() -> TimeInterval {
        return self.fromDataSource?.transitionPreferDuration ?? Self.duration
    }
    
    func present(transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to),
              var sourceView = fromDataSource?.transitionSourceView else {
                  if let toView = transitionContext.view(forKey: .to) {
                      transitionContext.containerView.addSubview(toView)
                  }
                  transitionContext.completeTransition(true)
                  return
              }
        let container = transitionContext.containerView
        var sourceViewWindowFrame = sourceView.frame
        sourceView.frame = sourceViewWindowFrame
        sourceView.layer.masksToBounds = true
        sourceView.layer.cornerRadius = fromDataSource?.transitionFromCornerRadiusView?.layer.cornerRadius ?? 0
        
        container.addSubview(sourceView)
        container.addSubview(toView)
        toView.alpha = 0
        let size = getSizeFromViewSize(toView.bounds.size, animateViewSize: sourceViewWindowFrame.size)
        let newFrame = CGRect(center: toView.center, size: size)
        UIView.animate(withDuration: getDuration(), delay: 0, usingSpringWithDamping: getDamping(), initialSpringVelocity: self.initialV, options: self.options) {
            sourceView.frame = newFrame
            sourceView.layer.cornerRadius = 0
            fromView.alpha = 0
        } completion: { finish in
            toView.alpha = 1
            fromView.alpha = 1
            sourceView.alpha = 1
            sourceView.removeFromSuperview()
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    func dismiss(transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from),
              let toView = transitionContext.view(forKey: .to),
              let dataSourceToView = toDataSource?.transitionToView,
              let sourceView = fromDataSource?.transitionSourceView else {
                  if let toView = transitionContext.view(forKey: .to) {
                      transitionContext.containerView.addSubview(toView)
                  }
                  transitionContext.completeTransition(true)
                  return
              }
        let container = transitionContext.containerView
        let snapshotFrame = sourceView.convert(sourceView.bounds, to: nil)
        container.addSubview(toView)


        dataSourceToView.isHidden = true
        fromView.isHidden = true
        toView.alpha = 0
        
        let imageView: UIView
        var isMatchRatio = false
        if let toRadiusViewSize = toDataSource?.transitionToRadiusView?.bounds.size {
            let sourceSize = sourceView.bounds.size
            let toRatio = toRadiusViewSize.width / toRadiusViewSize.height
            let fromRatio = sourceSize.width / sourceSize.height
            if toRatio / fromRatio >= 0.98 {
                isMatchRatio = true
            }
        }
        if isMatchRatio {
            imageView = sourceView.snapshotView(afterScreenUpdates: false) ?? UIView()
        } else {
            imageView = UIImageView(image: getImageFromView(sourceView))
        }
        imageView.frame = snapshotFrame
        container.addSubview(imageView)
        let imageFrame: CGRect
        if let radiusView = toDataSource?.transitionToRadiusView {
            imageFrame = radiusView.convert(radiusView.bounds, to: toView)
        } else {
            imageFrame = dataSourceToView.convert(dataSourceToView.bounds, to: container)
        }
        imageView.contentMode = .scaleAspectFill
        imageView.layer.masksToBounds = true
        UIView.animate(withDuration: getDuration(), delay: 0, usingSpringWithDamping: getDamping(), initialSpringVelocity: self.initialV, options: self.options) {
            imageView.frame = imageFrame
            let radius = self.toDataSource?.transitionToRadiusView?.layer.cornerRadius ?? 0
            imageView.layer.cornerRadius = radius
            toView.alpha = 1
        } completion: { finish in
            imageView.removeFromSuperview()
            if transitionContext.transitionWasCancelled {
                container.addSubview(fromView)
                fromView.isHidden = false
                toView.removeFromSuperview()
            } else {
                dataSourceToView.isHidden = false
                toView.alpha = 1
            }
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
    
    func getImageFromView(_ view: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, 0)
        guard let context = UIGraphicsGetCurrentContext() else { return UIImage() }
        view.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image ?? UIImage()
    }
        
}

//        if let requiredSize = fromDataSource?.transitionFromRequiredSize {
//            let frame = CGRect(x: 0, y: 100, width: 390, height: 390)
//            let newPath = UIBezierPath(rect: frame)
//            let oldPath = UIBezierPath(rect: sourceViewSnapshot.bounds)
//            let layer = CAShapeLayer()
//            layer.frame = sourceViewSnapshot.bounds
//            sourceViewSnapshot.layer.mask = layer
//            let animation = CABasicAnimation(keyPath: "path")
//            animation.duration = Self.duration * 0.3
//            animation.fromValue = oldPath.cgPath
//            animation.toValue = newPath.cgPath
//            layer.path = newPath.cgPath
//            CATransaction.begin()
//            layer.add(animation, forKey: "path")
//            CATransaction.setAnimationTimingFunction(.init(name: .linear))
//            CATransaction.setCompletionBlock {
//                UIView.animate(withDuration: Self.duration * 0.7, delay: Self.duration * 0.3, usingSpringWithDamping: self.damping, initialSpringVelocity: self.initialV, options: self.options) {
//                    sourceViewSnapshot.frame = newFrame
//                    sourceViewSnapshot.layer.cornerRadius = self.toDataSource?.transitionToRadiusView?.layer.cornerRadius ?? 0
//                    toView.alpha = 1
//                } completion: { finish in
//                    sourceViewSnapshot.removeFromSuperview()
//                    if transitionContext.transitionWasCancelled {
//                        container.addSubview(fromView)
//                        fromView.isHidden = false
//                        toView.removeFromSuperview()
//                    } else {
//                        dataSourceToView.isHidden = false
//                        toView.alpha = 1
//                    }
//                    transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
//                }
//            }
//            CATransaction.commit()
//        } else {
        
