//
//  DogeChatNavigationController.swift
//  DogeChat
//
//  Created by 赵锡光 on 2021/6/27.
//  Copyright © 2021 赵锡光. All rights reserved.
//

import UIKit

class DogeChatNavigationController: UINavigationController {
    
    var username = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func pushViewController(_ viewController: UIViewController, animated: Bool) {
        super.pushViewController(viewController, animated: true)
    }
    
    override func popViewController(animated: Bool) -> UIViewController? {
        let popped = super.popViewController(animated: animated)
        return popped
    }
    
    
}
