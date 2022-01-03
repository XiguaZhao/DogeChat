//
//  HistoryFilterVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2022/1/1.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit
import DogeChatUniversal

class HistoryFilterVC: DogeChatViewController, UIPickerViewDataSource, UIPickerViewDelegate {

    @IBOutlet weak var keywordTF: UITextField!
    
    @IBOutlet weak var typePicker: UIPickerView!
    
    @IBOutlet weak var datePicker: UIDatePicker!
    
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

        typePicker.dataSource = self
        typePicker.delegate = self
        
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
    }
    
    @IBAction func confirm(_ sender: UIButton) {
        if !datePicker.isHidden {
            self.params["timestamp"] = self.datePicker.date.timeIntervalSince1970 * 1000
        }
        if !typePicker.isHidden {
            self.params["type"] = types[self.typePicker.selectedRow(inComponent: 0)].rawValue
        }
        if let text = keywordTF.text, !text.isEmpty {
            self.params["keyword"] = text
        }
        self.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
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
    
    
}
