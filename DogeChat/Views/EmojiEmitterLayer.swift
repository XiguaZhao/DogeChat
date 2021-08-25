//
//  EmojiEmitterLayer.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/6.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatNetwork

class EmojiEmitterLayer: CAEmitterLayer {
    
    let emitDuration: TimeInterval = 3
    let strs: [String]
    let count: Double
    var rate: Float = 1
    weak var fromView: UIView?
    weak var toView: UIView?
    weak var timer: Timer?
    
    init(strs: [String], count: Double = 10, fromView: UIView, toView: UIView) {
        self.strs = strs
        self.count = count
        self.fromView = fromView
        self.toView = toView
        super.init()
        prepare()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func prepare() {
        guard let fromView = fromView, let toView = toView else { return }
        let fromCenter = fromView.center
        var toCenter = toView.center
        toCenter = toView.superview?.convert(toCenter, to: fromView.superview) ?? .zero
        let fromLeftToRight = fromCenter.x < toCenter.x
        
        let dx = toCenter.x - fromCenter.x
        let dy = toCenter.y - fromCenter.y
        
        var rad = atan(dy / dx)
        
        if !fromLeftToRight {
            rad -= .pi
        }
        
        var cells = [CAEmitterCell]()
        for str in strs {
            let cell = CAEmitterCell()
            cell.velocity = 500
            cell.velocityRange = 100
            cell.scale = 0.7
            cell.scaleRange = 0.2
            cell.spin = .pi * 2
            let image = str.image()
            cell.contents = image.cgImage!
            cell.emissionLongitude = rad
            cell.lifetime = 3
            cell.birthRate = Float(count / emitDuration)
            self.rate = cell.birthRate
            cells.append(cell)
        }
        self.emitterPosition = fromCenter
        self.emitterCells = cells
        if #available(iOS 13.0, *) {
            let manager = HapticManager.shared
            self.timer = Timer.scheduledTimer(withTimeInterval: 1/Double(rate), repeats: true, block: { _ in
                manager.playHapticTransient(time: 0, intensity: 1, sharpness: 1)
            })
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + emitDuration) {
            self.timer?.invalidate()
            self.timer = nil
            self.removeFromSuperlayer()
        }
    }
    
}
