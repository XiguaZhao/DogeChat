//
//  SelectColorVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/7.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatCommonDefines

class SelectColorVC: DogeChatViewController, UIColorPickerViewControllerDelegate {
    
    
    @IBOutlet weak var atButton: UIButton!
    @IBOutlet weak var receiveText: UIButton!
    @IBOutlet weak var sendBubble: UIButton!
    @IBOutlet weak var sendText: UIButton!
    @IBOutlet weak var receiveBubble: UIButton!
    
    var didSelectColors: ((CustomizedColor) -> Void)?
    
    var type: CustomizedColorType = .atColor
    
    var dict = [CustomizedColorType : (button: UIButton, color: UIColor)]()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        dict[.atColor] = (atButton, MessageTextCell.atColor)
        dict[.sendTextColor] = (sendText, MessageTextCell.sendTextColor)
        dict[.receiveTextColor] = (receiveText, MessageTextCell.receiveTextColor)
        dict[.sendBubbleColor] = (sendBubble, MessageTextCell.sendBubbleColor)
        dict[.receiveBubbleColor] = (receiveBubble, MessageTextCell.receiveBubbleColor)

        for (_, value) in dict {
            let button = value.button
            button.layer.masksToBounds = true
            button.layer.cornerRadius = 8
            button.setTitle("", for: .normal)
            button.addTarget(self, action: #selector(onTap(_:)), for: .touchUpInside)
            button.backgroundColor = value.color
        }
        
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "恢复默认", style: .plain, target: self, action: #selector(recoverColors))
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

    }
    
    @objc func onTap(_ button: UIButton) {
        switch button {
        case atButton:
            self.type = .atColor
        case sendText:
            self.type = .sendTextColor
        case receiveText:
            self.type = .receiveTextColor
        case sendBubble:
            self.type = .sendBubbleColor
        case receiveBubble:
            self.type = .receiveBubbleColor
        default:
            break
        }
        if #available(iOS 14.0, *), !isMac() {
            let picker = UIColorPickerViewController()
            picker.delegate = self
            picker.selectedColor = button.backgroundColor ?? .black
            self.present(picker, animated: true, completion: nil)
        } else {
            let vc = SelectColorLowVersion()
            vc.color = dict[type]!.color
            vc.didSelectColor = { color in
                self.didSelectColor(color)
            }
            self.present(vc, animated: true, completion: nil)
        }
    }
    
    @objc func recoverColors() {
        let customizedColor = CustomizedColor(at: ColorUtil.getColorRGBFrom(color: MessageTextCell.atDefaultColor),
                                              sendText: ColorUtil.getColorRGBFrom(color: MessageTextCell.sendTextDefaultColor),
                                              receiveText: ColorUtil.getColorRGBFrom(color: MessageTextCell.receiveTextDefaultColor),
                                              sendBubble: ColorUtil.getColorRGBFrom(color: MessageTextCell.sendBubbleDefaultColor),
                                              receiveBubble: ColorUtil.getColorRGBFrom(color: MessageTextCell.receiveBubbleDefaultColor))
        didSelectColors?(customizedColor)
        self.navigationController?.popViewController(animated: true)
    }
    
    @available(iOS 14.0, *)
    func colorPickerViewControllerDidFinish(_ viewController: UIColorPickerViewController) {
        self.didSelectColor(viewController.selectedColor)
    }
    
    func didSelectColor(_ color: UIColor) {
        var button: UIButton?
        switch self.type {
        case .atColor:
            button = atButton
        case .sendTextColor:
            button = sendText
        case .receiveTextColor:
            button = receiveText
        case .sendBubbleColor:
            button = sendBubble
        case .receiveBubbleColor:
            button = receiveBubble
        }
        button?.backgroundColor = color
        dict[self.type]?.color = color
    }
    @IBAction func onCancle(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func onConfirm(_ sender: Any) {
        let customizedColor = CustomizedColor(at: ColorUtil.getColorRGBFrom(color: dict[.atColor]!.color),
                                              sendText: ColorUtil.getColorRGBFrom(color: dict[.sendTextColor]!.color),
                                              receiveText: ColorUtil.getColorRGBFrom(color: dict[.receiveTextColor]!.color),
                                              sendBubble: ColorUtil.getColorRGBFrom(color: dict[.sendBubbleColor]!.color),
                                              receiveBubble: ColorUtil.getColorRGBFrom(color: dict[.receiveBubbleColor]!.color))
        didSelectColors?(customizedColor)
        self.navigationController?.popViewController(animated: true)
    }
    
}
