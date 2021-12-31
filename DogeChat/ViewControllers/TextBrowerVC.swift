//
//  TextBrowerVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/12/9.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class TextBrowerVC: DogeChatViewController, UITextViewDelegate {
    
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.dataDetectorTypes = .all
        textView.isEditable = false
        textView.delegate = self
        textView.font = .preferredFont(forTextStyle: .body)
        self.textView.backgroundColor = .clear
        textView.contentInsetAdjustmentBehavior = .never
        textView.showsVerticalScrollIndicator = false
        view.addSubview(textView)
        // Do any additional setup after loading the view.
        textView.translatesAutoresizingMaskIntoConstraints = false
        let safeArea = self.view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            textView.leadingAnchor.constraint(equalTo: safeArea.leadingAnchor, constant: 20),
            textView.trailingAnchor.constraint(equalTo: safeArea.trailingAnchor, constant: -20),
            textView.topAnchor.constraint(equalTo: safeArea.topAnchor),
            textView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollView.resignFirstResponder()
    }
    
    func setText(_ text: String) {
        textView.text = text
        textView.scrollRectToVisible(.zero, animated: false)
    }
    
}
