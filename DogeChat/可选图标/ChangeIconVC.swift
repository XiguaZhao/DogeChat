//
//  ChangeIconVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/14.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class ChangeIconVC: DogeChatViewController {
    
    let icons = ["cat", "dog", "bear"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        let recover = UIBarButtonItem(title: NSLocalizedString("recoverDefault", comment: ""), style: .plain, target: self, action: #selector(recover))
        navigationItem.rightBarButtonItem = recover
    }

    @IBAction func tapAction(_ sender: UITapGestureRecognizer) {
        
        let index = sender.view!.tag
        UIApplication.shared.setAlternateIconName(icons[index], completionHandler: { error in
            if let error = error {
                print(error)
            }
        })
    }
        
    @objc func recover() {
        UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
    }

}
