//
//  HistoryFilterVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/1.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatCommonDefines
import DogeChatNetwork

class HistoryFilterVC: DogeChatViewController, UIPickerViewDataSource, UIPickerViewDelegate, UITextFieldDelegate {

    var stackView: UIStackView!
    var keywordTF: UITextField!
    
    var typePicker: UIPickerView!
    
    var datePicker: UIDatePicker!
    
    let types: [MessageType] = {
        var res = MessageType.allCases
        if let index = res.firstIndex(of: .join) {
            res.remove(at: index)
        }
        return res
    }()
    
    var params = [String : Any?]()
    
    var didConfirm: (([String : Any?]) -> Void)?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        let keyWordLabel = UILabel()
        keyWordLabel.text = localizedString("keyword") + "："
        
        keywordTF = UITextField()
        keywordTF.placeholder = localizedString("enterKeyword")
        
        let spacing: CGFloat = 20
        
        let keywordStack = UIStackView(arrangedSubviews: [keyWordLabel, keywordTF])
        keywordStack.spacing = spacing
        
        var typeStack: UIStackView?
        if #available(iOS 15, *) {
            
            let typeLabel = UILabel()
            typeLabel.text = localizedString("messageType") + "："

            let popupButton = UIButton()
            popupButton.showsMenuAsPrimaryAction = true
            popupButton.changesSelectionAsPrimaryAction = true
            let allTypeAction = UIAction(title: localizedString("allType")) { [weak self] _ in
                self?.params.removeValue(forKey: "type")
            }
            let actions = types.map { type in
                return UIAction(title: type.Chinese()) { [weak self] _ in
                    self?.params["type"] = type.rawValue
                }
            }
            popupButton.menu = UIMenu(children: [allTypeAction] + actions)
            typeStack = UIStackView(arrangedSubviews: [typeLabel, popupButton])
            typeStack?.spacing = spacing
        } else {
            if !isMac() {
                let typeLabel = UILabel()
                typeLabel.text = localizedString("messageType") + "："
                
                let typeSwitcher = UISwitch()
                typeSwitcher.isOn = false
                typeSwitcher.addTarget(self, action: #selector(typeSwicher(_:)), for: .valueChanged)
                typeSwitcher.setContentHuggingPriority(.required, for: .vertical)
                            
                typePicker = UIPickerView()
                typePicker.isHidden = true
                
                typeStack = UIStackView(arrangedSubviews: [typeLabel, typeSwitcher, typePicker])
                typeStack?.spacing = spacing
                
                typeSwitcher.mas_makeConstraints { make in
                    make?.centerY.equalTo()(typeLabel)
                }
            }
        }
        
        let dateLabel = UILabel()
        dateLabel.text = localizedString("date") + "："
        
        let dateSwitcher = UISwitch()
        dateSwitcher.isOn = false
        dateSwitcher.addTarget(self, action: #selector(dateSwitcher(_:)), for: .valueChanged)
        
        datePicker = UIDatePicker()
        datePicker.isHidden = true
        
        let dateStack = UIStackView(arrangedSubviews: [dateLabel, dateSwitcher, datePicker])
        dateStack.spacing = spacing
        
        let confirmButton = UIButton()
        confirmButton.setTitle(localizedString("confirm"), for: .normal)
        confirmButton.addTarget(self, action: #selector(confirm(_:)), for: .touchUpInside)
        
        let cancelButton = UIButton()
        cancelButton.setTitle(localizedString("cancel"), for: .normal)
        cancelButton.addTarget(self, action: #selector(cancel(_:)), for: .touchUpInside)
        
        let buttonStack = UIStackView(arrangedSubviews: [cancelButton, confirmButton])
        buttonStack.spacing = spacing
        buttonStack.distribution = .fillEqually

        stackView = UIStackView(arrangedSubviews: [keywordStack, dateStack, buttonStack])
        stackView.axis = .vertical
        stackView.spacing = spacing
        stackView.setCustomSpacing(spacing + 12, after: dateStack)
        
        if let typeStack = typeStack {
            stackView.insertArrangedSubview(typeStack, at: 1)
        }
        
        self.view.addSubview(stackView)
        
        stackView.mas_makeConstraints { make in
            make?.center.equalTo()(self.view)
            make?.leading.greaterThanOrEqualTo()(self.view)?.offset()(10)
            make?.trailing.lessThanOrEqualTo()(self.view)?.offset()(-10)
        }
        
        typePicker?.dataSource = self
        typePicker?.delegate = self

        keywordTF.delegate = self
        keywordTF.returnKeyType = .search
        keywordTF.becomeFirstResponder()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tap)))
    }
    
    @objc func tap() {
        keywordTF.resignFirstResponder()
    }
    
    
    @IBAction func dateSwitcher(_ sender: UISwitch) {
        sender.isHidden = sender.isOn
        datePicker.isHidden = !sender.isOn
    }
    
    @IBAction func typeSwicher(_ sender: UISwitch) {
        sender.isHidden = sender.isOn
        typePicker.isHidden = !sender.isOn
        typePicker.mas_remakeConstraints { make in
            make?.width.mas_lessThanOrEqualTo()(200)
            make?.height.mas_equalTo()(100)
        }

    }
    
    @IBAction func confirm(_ sender: UIButton!) {
        if !datePicker.isHidden {
            self.params["timestamp"] = "\(Int(self.datePicker.date.timeIntervalSince1970 * 1000))"
        }
        if typePicker != nil && !typePicker.isHidden {
            self.params["type"] = types[self.typePicker.selectedRow(inComponent: 0)].rawValue
        }
        if let text = keywordTF.text, !text.isEmpty {
            self.params["keyword"] = text
        }
        guard !self.params.isEmpty else { return }
        if self.isBeingPresented {
            self.dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.didConfirm?(self.params)
            }
        } else {
            self.navigationController?.popViewController(animated: true)
            self.didConfirm?(self.params)
        }
    }
    
    @IBAction func cancel(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
        
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return types.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return types[row].Chinese()
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        confirm(nil)
        return true
    }
}
