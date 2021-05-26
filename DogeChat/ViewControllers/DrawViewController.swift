//
//  DrawViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/5/23.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit
import YPTransition

@available(iOS 14.0, *)
class DrawViewController: UIViewController {
    
    var pkView = PKCanvasView()
    let pkViewDelegate = PKViewDelegate()
    var message: Message!
    let toolPicker = PKToolPicker()
    var toolBar = UIToolbar()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.addSubview(toolBar)
        ChatRoomViewController.needRotate = true
        toolBar.mas_makeConstraints { [weak self] make in
            guard let self = self else { return }
            make?.top.equalTo()(self.view)
            make?.leading.equalTo()(self.view)
            make?.trailing.equalTo()(self.view)
        }
        
        let confirmButton = UIBarButtonItem(title: "确认", style: .done, target: self, action: #selector(confirmTapAction(_:)))
        self.navigationItem.rightBarButtonItem = confirmButton
        toolBar.setItems([UIBarButtonItem(systemItem: .flexibleSpace), confirmButton], animated: true)
        view.addSubview(pkView)
        pkView.contentInsetAdjustmentBehavior = .never
        pkView.backgroundColor = .gray
        pkView.delegate = pkViewDelegate
        pkView.contentSize = CGSize(width: 2000, height: 1000)
        toolPicker.setVisible(true, forFirstResponder: pkView)
        toolPicker.addObserver(pkView)
        pkView.becomeFirstResponder()
        pkViewDelegate.pkView = pkView
        pkViewDelegate.message = message as Any
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
//        let y = UIApplication.shared.statusBarFrame.height + self.navigationController!.navigationBar.bounds.height
        let y = toolBar.bounds.height
        pkView.frame = CGRect(x: 0, y: y, width: view.bounds.width, height: view.bounds.height - y)
    }
        
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
    }
    
    
    @objc func confirmTapAction(_ sender: UIBarButtonItem) {
        if !pkView.drawing.strokes.isEmpty {
            pkViewDelegate.dataChangedDelegate?.pkViewDidFinishDrawing(pkView, message: message as Any)
        }
        ChatRoomViewController.needRotate = false
        self.dismiss(animated: true, completion: nil)
    }
    

}
