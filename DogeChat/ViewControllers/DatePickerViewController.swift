//
//  DatePickerViewController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/1.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

protocol DatePickerChangeDelegate: AnyObject {
    func datePickerConfirmed(_ picker: UIDatePicker)
}

class DatePickerViewController: UIViewController {

    let picker = UIDatePicker()
    var stackView: UIStackView!
    weak var delegate: DatePickerChangeDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        let confirmButton = UIButton()
        let cancelButton = UIButton()
        if #available(iOS 13.0, *) {
            view.backgroundColor = .systemBackground
        } 
        confirmButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        picker.datePickerMode = .countDownTimer
        picker.countDownDuration = 60 * 60
        
        confirmButton.setTitle(NSLocalizedString("confirm", comment: ""), for: .normal)
        confirmButton.addTarget(self, action: #selector(confirmed(_:)), for: .touchUpInside)
        cancelButton.setTitle(NSLocalizedString("cancel", comment: ""), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)
        let buttonStack = UIStackView(arrangedSubviews: [confirmButton, cancelButton])
        buttonStack.spacing = 30
        stackView = UIStackView(arrangedSubviews: [picker, buttonStack])
        stackView.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 20
        
        view.addSubview(stackView)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let stackView = stackView {
            stackView.center = view.center
        }
    }

    @objc func confirmed(_ sender: UIButton) {
        delegate?.datePickerConfirmed(picker)
        self.dismiss(animated: true, completion: nil)
    }
    
    @objc func cancel() {
        self.dismiss(animated: true, completion: nil)
    }

}
