//
//  SelectColorLowVersion.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/13.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

class SelectColorLowVersion: DogeChatViewController {
    
    var didSelectColor: ((UIColor) -> Void)?
    
    var r: CGFloat = 0
    var g: CGFloat = 0
    var b: CGFloat = 0
    var a: CGFloat = 0
    
    var color = UIColor.blue
    
    deinit {
        print(1)
    }
    
    @IBOutlet weak var rSlider: UISlider!
    @IBOutlet weak var gSlider: UISlider!
    @IBOutlet weak var bSlider: UISlider!
    @IBOutlet weak var aSlider: UISlider!
    
    var sliders = [UISlider]()

    @IBOutlet weak var label: UILabel!
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sliders = [rSlider, gSlider, bSlider, aSlider]

        label.layer.masksToBounds = true
        label.layer.cornerRadius = 10
        self.color.getRed(&r, green: &g, blue: &b, alpha: &a)
        
        for slider in sliders {
            slider.minimumValue = 0
            slider.maximumValue = 1
        }
        
        rSlider.value = Float(r)
        gSlider.value = Float(g)
        bSlider.value = Float(b)
        aSlider.value = Float(a)
        
        updateColor()
    }

    @IBAction func rSlider(_ sender: UISlider) {
        r = CGFloat(sender.value)
        updateColor()
    }
    
    @IBAction func gSlider(_ sender: UISlider) {
        g = CGFloat(sender.value)
        updateColor()
    }
    
    @IBAction func bSlider(_ sender: UISlider) {
        b = CGFloat(sender.value)
        updateColor()
    }
    
    @IBAction func aSlider(_ sender: UISlider) {
        a = CGFloat(sender.value)
        updateColor()
    }
    
    private func updateColor() {
        color = UIColor(red: r, green: g, blue: b, alpha: a)
        label.tintColor = color
        label.backgroundColor = color
    }
    
    @IBAction func onCancle(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onConfirm(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
        didSelectColor?(color)
    }
}
