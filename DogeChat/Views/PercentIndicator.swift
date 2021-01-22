//
//  PercentIndicator.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/1/20.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class PercentIndicator: UIView {
    
    var percent: CGFloat = 0 {
        didSet {
            DispatchQueue.main.async {
                self.setNeedsLayout()
                self.setNeedsDisplay()
            }
        }
    }
    
    lazy var colorImage: UIImageView = {
            let imageView = UIImageView(image: UIImage.init(named: "circle-BG"))
            imageView.frame = self.bounds
            return imageView
        }()
    
    override func draw(_ rect: CGRect) {
        let path = UIBezierPath.init(arcCenter:CGPoint(x: self.bounds.size.width * 0.5, y: self.bounds.size.height * 0.5), radius: self.bounds.size.width * 0.5 - 5, startAngle: CGFloat.pi * 0.5, endAngle: CGFloat.pi * 2.5, clockwise: true)
  
        let shapeLayer = CAShapeLayer()
        shapeLayer.bounds = self.bounds
        shapeLayer.lineCap = CAShapeLayerLineCap.round
        shapeLayer.position = CGPoint(x: self.bounds.size.width * 0.5, y: self.bounds.size.height * 0.5)
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = UIColor.black.cgColor
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.lineWidth = 6.0
        self.layer.mask = shapeLayer//关键步骤
        
        /**
        设置进度条动画
        */
        let ani = CABasicAnimation(keyPath: "strokeEnd")
        ani.duration = 2
        ani.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeOut)
        ani.fromValue = 0
        ani.toValue = self.percent
        ani.fillMode = CAMediaTimingFillMode.forwards
        ani.isRemovedOnCompletion = false
        shapeLayer.add(ani, forKey: nil)
    }

}
