//
//  DrawViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/23.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit
import DogeChatNetwork
import DogeChatUniversal

@available(iOS 13.0, *)
class DrawViewController: UIViewController, PKViewAutoOffsetDelegate {
    
    var username = ""
    var pkView = PKCanvasView()
    let pkViewDelegate = PKViewDelegate()
    var message: Message!
    lazy var toolPicker: PKToolPicker? = {
        if #available(iOS 14.0, *) {
            return PKToolPicker()
        } else {
            if let window = self.view.window {
                return PKToolPicker.shared(for: window)
            } else {
                return nil
            }
        }
    }()
    var toolBar = UIToolbar()
    var didSendNeedRealTime = false
    var cachedOffset: CGPoint = .zero
    let forwardButton = UIButton()
    weak var chatRoomVC: ChatRoomViewController?

    override func viewDidLoad() {
        super.viewDidLoad()
        if isPhone() && (UIDevice.current.orientation != .landscapeLeft && UIDevice.current.orientation != .landscapeRight) {
            UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.landscapeRight.rawValue), forKey: "orientation")
        }
        self.view.addSubview(toolBar)
        toolBar.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.top.equalTo()(self.view.mas_safeAreaLayoutGuideTop)
            make?.leading.equalTo()(self.view)
            make?.trailing.equalTo()(self.view)
        }
                
        let returnBarItem = UIBarButtonItem(title: "换行", style: .plain, target: self, action: #selector(returnTapAction(_:)))
        
        let previewBarItem = UIBarButtonItem(title: "预览", style: .plain, target: self, action: #selector(previewTapAction(_:)))
        
        let realTimeLabel = UILabel()
        realTimeLabel.text = "实时"
        let realTimeSwitcher = UISwitch()
        let stackView = UIStackView(arrangedSubviews: [realTimeLabel, realTimeSwitcher])
        stackView.spacing = 15
        let switcherBarItem = UIBarButtonItem(customView: stackView)
        realTimeSwitcher.isOn = message.needRealTimeDraw
        realTimeSwitcher.addTarget(self, action: #selector(realTimerSwitchAction(_:)), for: .valueChanged)
        let cancleButton = UIBarButtonItem(title: "取消", style: .done, target: self, action: #selector(cancelTapAction(_:)))
        let confirmButton = UIBarButtonItem(title: "确认", style: .done, target: self, action: #selector(confirmTapAction(_:)))
        self.navigationItem.rightBarButtonItem = confirmButton
        
        var items = [cancleButton, previewBarItem, switcherBarItem, returnBarItem, confirmButton]
        if #available(iOS 14.0, *) {
            let flex = UIBarButtonItem(systemItem: .flexibleSpace)
            items = [cancleButton, flex, previewBarItem, flex, switcherBarItem, flex, returnBarItem, flex, confirmButton]
        }
        
        toolBar.setItems(items, animated: true)
        view.addSubview(pkView)
        pkView.contentInsetAdjustmentBehavior = .never
        pkView.backgroundColor = .gray
        pkView.delegate = pkViewDelegate
        pkView.contentSize = CGSize(width: 2000, height: 2000)
        pkView.becomeFirstResponder()
        pkViewDelegate.pkView = pkView
        pkViewDelegate.autoOffsetDelegate = self
        pkViewDelegate.message = message as Any
        pkView.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.top.equalTo()(self.toolBar.mas_bottom)
            make?.leading.equalTo()(self.toolBar)
            make?.trailing.equalTo()(self.toolBar)
            make?.bottom.equalTo()(self.view)
        }
        
        forwardButton.isHidden = true
        view.addSubview(forwardButton)
        view.bringSubviewToFront(forwardButton)
        let largeConfig = UIImage.SymbolConfiguration(pointSize: 40, weight: .thin, scale: .small)
        let forwardImage = UIImage(systemName: "forward", withConfiguration: largeConfig)
        forwardButton.setImage(forwardImage, for: .normal)
        forwardButton.addTarget(self, action: #selector(forwardTapAction(_:)), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        forwardButton.sizeToFit()
        forwardButton.center = CGPoint(x: view.bounds.width - forwardButton.bounds.width - view.safeAreaInsets.right, y: view.center.y)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        toolPicker?.setVisible(true, forFirstResponder: pkView)
        toolPicker?.addObserver(pkViewDelegate)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if isPhone() {
            UIDevice.current.setValue(NSNumber(integerLiteral: UIInterfaceOrientation.portrait.rawValue), forKey: "orientation")
        }
    }
        
    @objc func realTimerSwitchAction(_ switcher: UISwitch) {
        message.needRealTimeDraw = switcher.isOn
        if switcher.isOn && !didSendNeedRealTime {
            if let message = self.message {
                socketForUsername(username).sendDrawMessage(message)
            }
            didSendNeedRealTime = true
        }
    }
    
    @objc func pickerSwitchAction(_ pickerSwitcher: UISwitch) {
        toolPicker?.setVisible(pickerSwitcher.isOn, forFirstResponder: pkView)
    }
    
    
    @objc func confirmTapAction(_ sender: UIBarButtonItem) {
        self.dismiss(animated: true) { [self] in
            if #available(iOS 14.0, *) {
                if !pkView.drawing.strokes.isEmpty {
                    pkViewDelegate.dataChangedDelegate?.pkViewDidFinishDrawing(pkView, message: message as Any)
                }
            } else {
                pkViewDelegate.dataChangedDelegate?.pkViewDidFinishDrawing(pkView, message: message as Any)
            }
        }
    }
    
    @objc func returnTapAction(_ sender: UIBarButtonItem) {
        let bounds = pkView.drawing.bounds
        let offset = CGPoint(x: 0, y: bounds.maxY)
        pkView.setContentOffset(offset, animated: true)
    }
    
    @objc func cancelTapAction(_ sender: UIBarButtonItem) {
        pkViewDelegate.dataChangedDelegate?.pkViewDidCancelDrawing(pkView, message: message)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func previewTapAction(_ sender: UIBarButtonItem) {
        let isPreview = sender.title == "预览"
        if isPreview { cachedOffset = pkView.contentOffset }
        pkView.minimumZoomScale = isPreview ? 0.3 : 1
        let bounds = pkView.drawing.bounds
        let scaleX = pkView.bounds.width / bounds.maxX
        let scaleY = pkView.bounds.height / bounds.maxY
        let scale = max(min(scaleX, scaleY) - 0.01, pkView.minimumZoomScale)
        pkView.setZoomScale(isPreview ? scale : 1, animated: true)
        if isPreview {
            pkView.setContentOffset(.zero, animated: true)
        } else {
            pkView.setContentOffset(cachedOffset, animated: true)
        }
        toolPicker?.setVisible(!isPreview, forFirstResponder: pkView)
        sender.title = isPreview ? "继续" : "预览"
    }
    
    func shoudAutoOffset(_ shouldAutoOffset: Bool) {
        forwardButton.isHidden = !shouldAutoOffset
    }
    
    @objc func forwardTapAction(_ sender: UIButton) {
        pkViewDelegate.autoOffset()
        sender.isHidden = true
    }

}
