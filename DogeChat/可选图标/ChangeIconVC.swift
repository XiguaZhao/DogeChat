//
//  ChangeIconVC.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/11/14.
//  Copyright © 2021 Luke Parham. All rights reserved.
//

import UIKit

class ChangeIconVC: DogeChatViewController {
    
    let icons = ["__海贼王",
                 "_哆啦A梦",
                 "_小黄人",
                 "_小黄人2",
                 "_海贼王2",
                 "_蜡笔小新",
                 "猫咪2"]

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func tapAction(_ sender: UITapGestureRecognizer) {
        
        let index = sender.view!.tag
        UIApplication.shared.setAlternateIconName(icons[index], completionHandler: { error in
            if let error = error {
                print(error)
            }
        })
    }
    
    @IBAction func recoverAction(_ sender: Any) {
        UIApplication.shared.setAlternateIconName(nil, completionHandler: nil)
    }
    

}
