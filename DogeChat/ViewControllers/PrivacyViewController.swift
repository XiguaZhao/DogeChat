//
//  PrivacyViewController.swift
//  DogeChat
//
//  Created by ByteDance on 2022/7/30.
//  Copyright © 2022 Luke Parham. All rights reserved.
//

import UIKit

class PrivacyViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func agree(_ sender: Any) {
        UserDefaults.standard.set(true, forKey: "agreePrivacy")
        self.dismiss(animated: true)
    }
    
    @IBAction func refuse(_ sender: Any) {
        exit(0)
    }
    
}
